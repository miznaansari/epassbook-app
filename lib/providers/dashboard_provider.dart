import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/financial_entry.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

class DashboardProvider extends ChangeNotifier {
  bool _loading = false;
  Map<String, dynamic> _kpis = {
    'currentBalance': 0.0,
    'spending': 0.0,
    'lending': 0.0,
    'loan': 0.0,
    'advance': 0.0,
    'savings': 0.0,
    'salaryTotal': 0.0,
    'salaryBalance': 0.0,
  };
  List<FinancialEntry> _recentTransactions = [];
  DateTime? _startDate;
  DateTime? _endDate;
  int _cycleDate = 1;
  String _filter = 'current';
  DateTime? _customStart;
  DateTime? _customEnd;
  Map<String, dynamic> _streaks = {
    'level1': 0,
    'level2': 0,
    'level2Limit': 0.0,
  };

  bool get loading => _loading;
  Map<String, dynamic> get kpis => _kpis;
  List<FinancialEntry> get recentTransactions => _recentTransactions;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  int get cycleDate => _cycleDate;
  String get filter => _filter;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  Map<String, dynamic> get streaks => _streaks;

  void setFilter(String val) {
    _filter = val;
    notifyListeners();
  }

  void setCustomRange(DateTime? start, DateTime? end) {
    _customStart = start;
    _customEnd = end;
    notifyListeners();
  }

  Future<void> fetchDashboard(AuthProvider auth) async {
    _loading = true;
    notifyListeners();

    try {
      String url = '${AppConfig.baseUrl}/api/dashboard?filter=$_filter';
      if (_filter == 'custom') {
        if (_customStart != null) {
          url += '&startDate=${_customStart!.toIso8601String().split('T')[0]}';
        }
        if (_customEnd != null) {
          url += '&endDate=${_customEnd!.toIso8601String().split('T')[0]}';
        }
      }

      final response = await http.get(
        Uri.parse(url),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        
        _startDate = body['startDate'] != null ? DateTime.parse(body['startDate']) : null;
        _endDate = body['endDate'] != null ? DateTime.parse(body['endDate']) : null;
        _cycleDate = body['cycleDate'] ?? 1;

        if (body['kpis'] != null) {
          final rawKpi = body['kpis'];
          _kpis = {
            'currentBalance': double.parse(rawKpi['currentBalance'].toString()),
            'spending': double.parse(rawKpi['spending'].toString()),
            'lending': double.parse(rawKpi['lending'].toString()),
            'loan': double.parse(rawKpi['loan'].toString()),
            'advance': double.parse(rawKpi['advance'].toString()),
            'savings': double.parse(rawKpi['savings'].toString()),
            'salaryTotal': double.parse(rawKpi['salaryTotal'].toString()),
            'salaryBalance': double.parse(rawKpi['salaryBalance'].toString()),
          };
        }

        if (body['streaks'] != null) {
          final rawStreaks = body['streaks'];
          _streaks = {
            'level1': rawStreaks['level1'] ?? 0,
            'level2': rawStreaks['level2'] ?? 0,
            'level2Limit': double.parse((rawStreaks['level2Limit'] ?? 0.0).toString()),
          };
        }

        if (body['recentTransactions'] != null) {
          final List<dynamic> list = body['recentTransactions'];
          _recentTransactions = list.map((e) => FinancialEntry.fromJson(e)).toList();
        } else {
          _recentTransactions = [];
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addSalary(AuthProvider auth, {required double amount, required int month, required int year, required String type}) async {
    try {
      final endpoint = type == 'SALARY' ? 'salary' : 'bonus';
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/$endpoint'),
        headers: auth.headers,
        body: jsonEncode({
          'amount': amount,
          'month': month,
          'year': year,
        }),
      );
      if (response.statusCode == 200) {
        await fetchDashboard(auth);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding salary/bonus: $e");
      return false;
    }
  }
}

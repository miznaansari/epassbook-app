import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/financial_entry.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

class EntriesProvider extends ChangeNotifier {
  List<FinancialEntry> _entries = [];
  bool _loading = false;
  
  // Split Deduction State (populated if a transaction fails due to insufficient balance)
  Map<String, dynamic>? _insufficientBalanceDetails;

  List<FinancialEntry> get entries => _entries;
  bool get loading => _loading;
  Map<String, dynamic>? get insufficientBalanceDetails => _insufficientBalanceDetails;

  void clearInsufficientBalance() {
    _insufficientBalanceDetails = null;
    notifyListeners();
  }

  Future<void> fetchEntries(AuthProvider auth, {String? type, String? startDate, String? endDate}) async {
    _loading = true;
    notifyListeners();

    try {
      String url = '${AppConfig.baseUrl}/api/entries?';
      if (type != null && type != 'ALL') url += 'type=$type&';
      if (startDate != null) url += 'startDate=$startDate&';
      if (endDate != null) url += 'endDate=$endDate&';

      final response = await http.get(
        Uri.parse(url),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        _entries = list.map((e) => FinancialEntry.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching financial entries: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveEntry(
    AuthProvider auth, {
    int? id,
    required double amount,
    required String title,
    required String description,
    required String type,
    required bool useSalaryBalance,
    int? salaryMonth,
    int? salaryYear,
    DateTime? date,
    int? parentEntryId,
    List<Map<String, dynamic>>? deductions,
  }) async {
    _loading = true;
    notifyListeners();
    _insufficientBalanceDetails = null;

    try {
      final Map<String, dynamic> payload = {
        'amount': amount,
        'title': title,
        'description': description,
        'type': type,
        'useSalaryBalance': useSalaryBalance,
        'date': (date ?? DateTime.now()).toIso8601String(),
      };

      if (id != null) payload['id'] = id;
      if (parentEntryId != null) payload['parentEntryId'] = parentEntryId;

      if (useSalaryBalance) {
        if (deductions != null && deductions.isNotEmpty) {
          payload['deductions'] = deductions;
        } else {
          payload['salaryMonth'] = salaryMonth;
          payload['salaryYear'] = salaryYear;
        }
      }

      final method = id != null ? 'PUT' : 'POST';
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/entries'),
        headers: auth.headers,
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _loading = false;
        notifyListeners();
        return {'success': true, 'entry': FinancialEntry.fromJson(responseBody)};
      } else {
        _loading = false;
        if (responseBody['error'] == 'INSUFFICIENT_BALANCE') {
          _insufficientBalanceDetails = responseBody;
          notifyListeners();
          return {
            'success': false,
            'insufficient': true,
            'message': responseBody['message'] ?? 'Insufficient Balance'
          };
        }
        notifyListeners();
        return {'success': false, 'message': responseBody['error'] ?? 'Failed to save entry'};
      }
    } catch (e) {
      _loading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteEntry(AuthProvider auth, int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/entries?id=$id'),
        headers: auth.headers,
      );
      if (response.statusCode == 200) {
        _entries.removeWhere((e) => e.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting financial entry: $e");
      return false;
    }
  }
}

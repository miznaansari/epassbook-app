import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/sip.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

class SipsProvider extends ChangeNotifier {
  List<Sip> _sips = [];
  bool _loading = false;

  List<Sip> get sips => _sips;
  bool get loading => _loading;

  Future<void> fetchSips(AuthProvider auth) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/sips'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        _sips = list.map((e) => Sip.fromJson(e)).toList();
      } else {
        debugPrint("Failed to fetch sips: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching sips: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createSip(
    AuthProvider auth, {
    required String title,
    required double amount,
    required String frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    required String reminderTime,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> payload = {
        'title': title,
        'amount': amount,
        'frequency': frequency,
        'reminderTime': reminderTime,
      };

      if (frequency == 'MONTHLY' && dayOfMonth != null) {
        payload['dayOfMonth'] = dayOfMonth;
      } else if (frequency == 'WEEKLY' && dayOfWeek != null) {
        payload['dayOfWeek'] = dayOfWeek;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/sips'),
        headers: {
          ...auth.headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        await fetchSips(auth);
        return true;
      } else {
        debugPrint("Failed to create sip: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error creating sip: $e");
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSip(AuthProvider auth, int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/sips?id=$id'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        _sips.removeWhere((s) => s.id == id);
        notifyListeners();
        return true;
      } else {
        debugPrint("Failed to delete sip: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error deleting sip: $e");
      return false;
    }
  }

  Future<bool> confirmSipPayment(
    AuthProvider auth, {
    required int sipId,
    required DateTime date,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/sips/confirm'),
        headers: {
          ...auth.headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sipId': sipId,
          'date': date.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        await fetchSips(auth);
        return true;
      } else {
        debugPrint("Failed to confirm sip payment: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error confirming sip payment: $e");
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

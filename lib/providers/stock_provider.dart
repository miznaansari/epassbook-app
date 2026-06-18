import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/stock_holding.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

class StockProvider extends ChangeNotifier {
  List<StockHolding> _holdings = [];
  PortfolioSummary? _summary;
  List<dynamic> _searchResults = [];
  bool _loading = false;

  List<StockHolding> get holdings => _holdings;
  PortfolioSummary? get summary => _summary;
  List<dynamic> get searchResults => _searchResults;
  bool get loading => _loading;

  Future<void> fetchHoldings(AuthProvider auth) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/stocks/holdings'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        
        if (body['holdings'] != null) {
          final List<dynamic> list = body['holdings'];
          _holdings = list.map((e) => StockHolding.fromJson(e)).toList();
        } else {
          _holdings = [];
        }

        if (body['summary'] != null) {
          _summary = PortfolioSummary.fromJson(body['summary']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching stock holdings: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> searchStocks(AuthProvider auth, String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    
    _loading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/stocks/search?query=${Uri.encodeComponent(query)}'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        _searchResults = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error searching stocks: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addStockHolding(
    AuthProvider auth, {
    required String symbol,
    required String name,
    required int quantity,
    required double buyPrice,
    required bool createExpense,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/stocks/holdings'),
        headers: auth.headers,
        body: jsonEncode({
          'symbol': symbol,
          'name': name,
          'quantity': quantity,
          'buyPrice': buyPrice,
          'createExpense': createExpense,
        }),
      );

      if (response.statusCode == 200) {
        await fetchHoldings(auth);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding stock holding: $e");
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshPrices(AuthProvider auth) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/stocks/refresh'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        await fetchHoldings(auth);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error refreshing stock prices: $e");
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

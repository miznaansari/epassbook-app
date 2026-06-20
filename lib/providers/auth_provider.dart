import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

class AuthProvider extends ChangeNotifier {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  
  UserModel? _user;
  String? _sessionToken;
  bool _loading = true;

  UserModel? get user => _user;
  String? get sessionToken => _sessionToken;
  bool get loading => _loading;
  bool get initializing => _loading && _user == null;
  bool get isAuthenticated => _user != null;

  Map<String, String> get headers {
    final Map<String, String> headersMap = {'Content-Type': 'application/json'};
    if (_sessionToken != null) {
      headersMap['Cookie'] = 'session_token=$_sessionToken';
      headersMap['Authorization'] = 'Bearer $_sessionToken';
    }
    return headersMap;
  }

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString('session_token');
    
    if (_sessionToken != null) {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/auth/verify-user'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': _sessionToken}),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['valid'] == true) {
            _user = UserModel.fromJson(data['user']);
            _loading = false;
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        debugPrint("Error verifying local custom session: $e");
      }
    }

    _auth.authStateChanges().listen((fb.User? firebaseUser) async {
      _loading = true;
      notifyListeners();
      
      if (firebaseUser != null) {
        await syncUserProfile(firebaseUser);
      } else {
        if (_user == null) {
          _sessionToken = null;
          await prefs.remove('session_token');
        }
        _loading = false;
        notifyListeners();
      }
    });
  }

  Future<void> syncUserProfile(fb.User firebaseUser) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': firebaseUser.uid,
          'email': firebaseUser.email,
          'name': firebaseUser.displayName,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _user = UserModel.fromJson(data);

        // Capture session token from JSON body if present (crucial for Flutter Web / cross-origin API clients)
        if (data['sessionToken'] != null) {
          _sessionToken = data['sessionToken'].toString();
        } else {
          // Capture session cookie token
          final rawCookie = response.headers['set-cookie'];
          if (rawCookie != null) {
            final match = RegExp(r'session_token=([^;]+)').firstMatch(rawCookie);
            if (match != null) {
              _sessionToken = match.group(1);
            }
          }
        }

        if (_sessionToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_token', _sessionToken!);
        }
      } else {
        // Fallback profile if backend fails
        _user = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
          salaryCycleDate: 1,
          currency: 'USD',
          dailyReminderTime: '23:00',
          dailySpendReminderTime: '22:00',
          notifSalary: true,
          notifDaily: true,
          notifCycle: true,
          notifDailySpend: true,
          timezone: 'UTC',
        );
      }
    } catch (e) {
      debugPrint("Error syncing user profile: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    _loading = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        final fb.GoogleAuthProvider googleProvider = fb.GoogleAuthProvider();
        await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await _auth.signInWithCredential(credential);
        } else {
          _loading = false;
          notifyListeners();
        }
      }
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginEmailPassword(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['passwordNotSet'] == true) {
          throw Exception(data['error'] ?? 'Password not set. A link was sent to your email.');
        }

        _user = UserModel.fromJson(data['user']);
        _sessionToken = data['sessionToken'].toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_token', _sessionToken!);
        _loading = false;
        notifyListeners();
      } else {
        throw Exception(data['error'] ?? 'Invalid email or password.');
      }
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUpEmailPassword(String email, String password, String name) async {
    _loading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'name': name.trim(),
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['passwordNotSet'] == true) {
          throw Exception(data['error'] ?? 'Account setup initiated. Check email.');
        }

        _user = UserModel.fromJson(data['user']);
        _sessionToken = data['sessionToken'].toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_token', _sessionToken!);
        _loading = false;
        notifyListeners();
      } else {
        throw Exception(data['error'] ?? 'Failed to register account.');
      }
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    try {
      if (_sessionToken != null) {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/auth/logout'),
          headers: headers,
        );
      }
    } catch (e) {
      debugPrint("Error logging out from server session: $e");
    }
    _user = null;
    _sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    await _auth.signOut();
    _loading = false;
    notifyListeners();
  }

  Future<bool> updatePreferences(Map<String, dynamic> updateData) async {
    if (_user == null) return false;
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/user'),
        headers: headers,
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _user = UserModel.fromJson(data);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating preferences: $e");
      return false;
    }
  }
}

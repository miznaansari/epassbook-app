import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AppTheme {
  static const Color background = Color(0xFF030712);
  static const Color surface = Color(0xFF0D1423);
  static const Color border = Color(0x1AFFFFFF);
  
  // Harmonies
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color secondaryGold = Color(0xFFF59E0B);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color roseRed = Color(0xFFEF4444);
  static const Color blueLending = Color(0xFF3B82F6);
  static const Color cyanAdvance = Color(0xFF06B6D4);
  static const Color orangeLoan = Color(0xFFF97316);

  static const LinearGradient purpleGoldGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF131B2E), Color(0xFF0A0F1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      background: background,
      surface: surface,
      primary: primaryPurple,
      secondary: secondaryGold,
      error: roseRed,
    ),
    useMaterial3: true,
  );
}

class AppConfig {
  static const String oneSignalAppId = "722dd7e4-705a-4a0e-a0b8-b4e2a3c93057";

  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
    } catch (e) {
      debugPrint("Firebase init error: $e");
    }
  }

  static Future<void> initializeOneSignal() async {
    if (kIsWeb) return;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.none);
      OneSignal.initialize(oneSignalAppId);
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint("OneSignal init error: $e");
    }
  }

  // Dynamic server url resolution: Android emulator vs iOS simulator vs Web
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    if (Platform.isAndroid) {
      return "http://10.0.2.2:3000";
    }
    return "http://localhost:3000";
  }

  // Programmatic Firebase Initialization options
  static FirebaseOptions get firebaseOptions {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "AIzaSyC1ZgLcrv4vzEnyaDUn_ONzQaQ29kof_xc",
        authDomain: "e-passbook-9745b.firebaseapp.com",
        appId: "1:187068233174:web:8ac0d4b1efb770b5d32077",
        messagingSenderId: "187068233174",
        projectId: "e-passbook-9745b",
        storageBucket: "e-passbook-9745b.firebasestorage.app",
      );
    }
    if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: "AIzaSyC1ZgLcrv4vzEnyaDUn_ONzQaQ29kof_xc",
        authDomain: "e-passbook-9745b.firebaseapp.com",
        appId: "1:187068233174:android:8ac0d4b1efb770b5d32077",
        messagingSenderId: "187068233174",
        projectId: "e-passbook-9745b",
        storageBucket: "e-passbook-9745b.firebasestorage.app",
      );
    } else if (Platform.isIOS) {
      return const FirebaseOptions(
        apiKey: "AIzaSyC1ZgLcrv4vzEnyaDUn_ONzQaQ29kof_xc",
        authDomain: "e-passbook-9745b.firebaseapp.com",
        appId: "1:187068233174:ios:8ac0d4b1efb770b5d32077",
        messagingSenderId: "187068233174",
        projectId: "e-passbook-9745b",
        storageBucket: "e-passbook-9745b.firebasestorage.app",
        iosBundleId: "com.fintrust.passbook.passbookApp",
      );
    }
    // Fallback web / default options
    return const FirebaseOptions(
      apiKey: "AIzaSyC1ZgLcrv4vzEnyaDUn_ONzQaQ29kof_xc",
      authDomain: "e-passbook-9745b.firebaseapp.com",
      appId: "1:187068233174:web:8ac0d4b1efb770b5d32077",
      messagingSenderId: "187068233174",
      projectId: "e-passbook-9745b",
      storageBucket: "e-passbook-9745b.firebasestorage.app",
    );
  }
}

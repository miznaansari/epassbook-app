import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/entries_provider.dart';
import 'providers/stock_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/sips_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services programmatically
  await AppConfig.initializeFirebase();
  await AppConfig.initializeOneSignal();

  runApp(const FintrustApp());
}

class FintrustApp extends StatelessWidget {
  const FintrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => EntriesProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SipsProvider()),
      ],
      child: MaterialApp(
        title: 'Fintrust',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppTheme.background,
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryPurple,
            surface: AppTheme.surface,
            error: AppTheme.roseRed,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
            ),
            labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        home: const AuthenticationGate(),
      ),
    );
  }
}

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.initializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: AppTheme.primaryPurple,
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppTheme.primaryPurple),
            ],
          ),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const MainShell();
    }

    return const LoginScreen();
  }
}

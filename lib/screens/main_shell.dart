import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../widgets/custom_navigation_bar.dart';
import 'dashboard/dashboard_screen.dart';
import 'stocks/stock_search_screen.dart';
import 'entries/history_screen.dart';
import 'entries/entry_form_sheet.dart';
import 'alerts/alerts_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/entries_provider.dart';
import '../providers/stock_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardScreen(),
      const StockSearchScreen(),
      const SizedBox(), // Spacer for center button
      const AlertsScreen(),
      const HistoryScreen(),
    ];
    
    // Initial fetch of data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboard(auth);
      Provider.of<StockProvider>(context, listen: false).fetchHoldings(auth);
      Provider.of<EntriesProvider>(context, listen: false).fetchEntries(auth);
    });
  }

  void _onTabTapped(int index) {
    if (index == 2) return; // Ignore spacer
    setState(() {
      _currentIndex = index;
    });
  }

  void _openEntryFormDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EntryFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 64,
        width: 64,
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.purpleGoldGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openEntryFormDrawer,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add_rounded,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        onFabTap: _openEntryFormDrawer,
      ),
    );
  }
}

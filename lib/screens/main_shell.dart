import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../widgets/custom_navigation_bar.dart';
import 'dashboard/dashboard_screen.dart';
import 'stocks/stock_search_screen.dart';
import 'entries/history_screen.dart';
import 'chat/chat_screen.dart';
import 'settings/settings_screen.dart';
import 'reports/reports_screen.dart';
import 'sips/sip_tracker_screen.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardScreen(),
      const HistoryScreen(),
      const StockSearchScreen(),
      const ChatScreen(),
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
    if (index == 4) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: AppTheme.surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppTheme.purpleGoldGradient,
              ),
              accountName: Text(user?.name ?? 'Guest User', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(user?.email ?? 'guest@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Text(
                  (user?.name ?? 'G').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: AppTheme.primaryPurple),
              title: const Text("Reports & Analytics", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined, color: AppTheme.secondaryGold),
              title: const Text("SIP Tracker", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SipTrackerScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70),
              title: const Text("AI Chat Assistant", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 3; // Switch to AI Chat tab
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: const Text("Preferences & Settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: AppTheme.border),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.roseRed),
              title: const Text("Log Out", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                auth.logout();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: NotificationListener<TabChangeNotification>(
        onNotification: (notification) {
          setState(() {
            _currentIndex = notification.index;
          });
          return true;
        },
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class TabChangeNotification extends Notification {
  final int index;
  const TabChangeNotification(this.index);
}

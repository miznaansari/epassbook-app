import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/stock_provider.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import '../entries/entry_form_sheet.dart';
import '../reports/reports_screen.dart';
import 'widgets/spending_chart_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatCurrency(double amount, String currencyCode) {
    final format = NumberFormat.currency(
      symbol: currencyCode == 'INR' ? '₹' : '\$',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  void _quickLogBill(BuildContext context, String billTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EntryFormSheet(
        prefilledTitle: billTitle,
        prefilledType: 'SPENDING',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final dashboard = Provider.of<DashboardProvider>(context);
    final stockProvider = Provider.of<StockProvider>(context);
    final user = auth.user;
    final kpis = dashboard.kpis;
    final currency = user?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${user?.name ?? 'Guest'}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  "Welcome to your Finance Hub",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => dashboard.fetchDashboard(auth),
          ),
        ],
      ),
      drawer: null,
      body: RefreshIndicator(
        onRefresh: () => dashboard.fetchDashboard(auth),
        color: AppTheme.primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // FINTRUST Premium Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.darkCardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.secondaryGold.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryGold.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "FINTRUST PREMIER",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: AppTheme.secondaryGold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
                          ),
                          child: const Text(
                            "Elite Banking",
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Premier Banking Services",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Optimize assets, wealth logs, and automated month-split deductions.",
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "CURRENT BALANCE",
                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(kpis['currentBalance'] ?? 0.0, currency),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1.5,
                          height: 40,
                          color: AppTheme.border,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "SALARY BALANCE",
                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(kpis['salaryBalance'] ?? 0.0, currency),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.emeraldGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // STOCKS PORTFOLIO PERFORMANCE CARD
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.show_chart_rounded, color: AppTheme.cyanAdvance, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "STOCKS PORTFOLIO",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (stockProvider.summary != null && stockProvider.summary!.totalInvested > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (stockProvider.summary!.totalReturns >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (stockProvider.summary!.totalReturns >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed).withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              "${stockProvider.summary!.totalReturns >= 0 ? '+' : ''}${stockProvider.summary!.totalReturnsPercentage.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: stockProvider.summary!.totalReturns >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (stockProvider.summary == null || stockProvider.summary!.totalInvested == 0)
                      Column(
                        children: [
                          Text(
                            "No stocks logged in your Groww portfolio ledger yet.",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("PORTFOLIO VALUE", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(stockProvider.summary!.totalCurrentValue, currency),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("INVESTED CAPITAL", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(stockProvider.summary!.totalInvested, currency),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions Cards (Stop SIP / Spending Analysis)
              Row(
                children: [
                  // Stop SIP Card
                  Expanded(
                    child: PremiumDashboardButton(
                      title: "Stop SIP",
                      subtitle: "Freeze automatic transfers",
                      icon: Icons.remove_moderator_outlined,
                      iconColor: AppTheme.orangeLoan,
                      onTap: () {
                        // Fast trigger feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("SIP Management features can be configured in settings."),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Spending Analysis Card
                  Expanded(
                    child: PremiumDashboardButton(
                      title: "Spending Analysis",
                      subtitle: "Detailed reports & metrics",
                      icon: Icons.pie_chart_outline_rounded,
                      iconColor: AppTheme.primaryPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReportsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recharges & Bills Circular Grid
              const Text(
                "RECHARGES & BILLS",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    CircularBillButton(
                      icon: Icons.phone_android_rounded,
                      label: "Mobile",
                      color: Colors.green,
                      onTap: () => _quickLogBill(context, "Mobile Recharge"),
                    ),
                    CircularBillButton(
                      icon: Icons.tv_rounded,
                      label: "DTH",
                      color: Colors.orange,
                      onTap: () => _quickLogBill(context, "DTH Recharge"),
                    ),
                    CircularBillButton(
                      icon: Icons.router_rounded,
                      label: "Broadband",
                      color: Colors.blue,
                      onTap: () => _quickLogBill(context, "Broadband Bill"),
                    ),
                    CircularBillButton(
                      icon: Icons.bolt_rounded,
                      label: "Electricity",
                      color: Colors.yellow,
                      onTap: () => _quickLogBill(context, "Electricity Bill"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Featured Feeds
              const Text(
                "FEATURED LINKS",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              FeedListItem(
                title: "Portfolio Insights",
                description: "Review current stock values, total returns, and assets performance.",
                icon: Icons.trending_up_rounded,
                iconColor: AppTheme.secondaryGold,
                onTap: () {
                  // Triggers main tab switch in shell by custom event or simply popping/setting state
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Use the Search tab in the bottom bar to view portfolio & search tickers.")),
                  );
                },
              ),
              const SizedBox(height: 12),
              FeedListItem(
                title: "My Spending Hub",
                description: "Inspect historical transactions, splits, and lendings lists.",
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.cyan,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Use the History tab in the bottom bar to search, filter & edit transactions.")),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class ListfulDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;

  const ListfulDrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class PremiumDashboardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const PremiumDashboardButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class CircularBillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const CircularBillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.25), width: 1.0),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class FeedListItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const FeedListItem({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

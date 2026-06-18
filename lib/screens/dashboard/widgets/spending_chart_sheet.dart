import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';

class SpendingChartSheet extends StatelessWidget {
  const SpendingChartSheet({super.key});

  String _formatCurrency(double amount, String currencyCode) {
    final format = NumberFormat.currency(
      symbol: currencyCode == 'INR' ? '₹' : '\$',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final dashboard = Provider.of<DashboardProvider>(context);
    final kpis = dashboard.kpis;
    final currency = auth.user?.currency ?? 'USD';

    final double spending = kpis['spending'] ?? 0.0;
    final double lending = kpis['lending'] ?? 0.0;
    final double loan = kpis['loan'] ?? 0.0;
    final double advance = kpis['advance'] ?? 0.0;
    final double savings = kpis['savings'] ?? 0.0;
    
    final double total = spending + lending + loan + advance + savings;

    List<PieChartSectionData> sections = [];
    if (total > 0) {
      sections = [
        if (spending > 0)
          PieChartSectionData(
            color: AppTheme.primaryPurple,
            value: spending,
            title: '${((spending / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        if (lending > 0)
          PieChartSectionData(
            color: AppTheme.blueLending,
            value: lending,
            title: '${((lending / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        if (loan > 0)
          PieChartSectionData(
            color: AppTheme.orangeLoan,
            value: loan,
            title: '${((loan / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        if (advance > 0)
          PieChartSectionData(
            color: AppTheme.cyanAdvance,
            value: advance,
            title: '${((advance / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        if (savings > 0)
          PieChartSectionData(
            color: AppTheme.emeraldGreen,
            value: savings,
            title: '${((savings / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Spending Analysis",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (total == 0) ...[
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "No transaction data found for this cycle.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            const SizedBox(height: 40),
          ] else ...[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Legend
            _buildLegendItem("Spending", spending, AppTheme.primaryPurple, currency),
            _buildLegendItem("Lending", lending, AppTheme.blueLending, currency),
            _buildLegendItem("Loans", loan, AppTheme.orangeLoan, currency),
            _buildLegendItem("Advances", advance, AppTheme.cyanAdvance, currency),
            _buildLegendItem("Savings", savings, AppTheme.emeraldGreen, currency),
            
            const Divider(color: AppTheme.border, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOTAL OUTFLOW",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                ),
                Text(
                  _formatCurrency(total, currency),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, double value, Color color, String currency) {
    if (value <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            _formatCurrency(value, currency),
            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

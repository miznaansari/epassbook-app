import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/stock_provider.dart';
import '../../providers/entries_provider.dart';
import '../../models/financial_entry.dart';
import '../entries/entry_form_sheet.dart';
import '../main_shell.dart'; // To dispatch TabChangeNotification
import 'qr_scanner_screen.dart';
import '../../config/home_widget_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String _typeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  void _showAddInflowSheet(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    double? amount;
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;
    String inflowType = 'SALARY'; // SALARY or BONUS

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.savings_rounded, color: AppTheme.emeraldGreen),
                          SizedBox(width: 8),
                          Text(
                            "Log Month-Wise Inflow",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Inflow sliding toggle
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => inflowType = 'SALARY'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: inflowType == 'SALARY' ? AppTheme.emeraldGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: inflowType == 'SALARY' ? AppTheme.emeraldGreen : AppTheme.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Salary",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: inflowType == 'SALARY' ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => inflowType = 'BONUS'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: inflowType == 'BONUS' ? AppTheme.cyanAdvance : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: inflowType == 'BONUS' ? AppTheme.cyanAdvance : AppTheme.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Bonus",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: inflowType == 'BONUS' ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: inflowType == 'SALARY' ? 'SALARY AMOUNT' : 'BONUS AMOUNT',
                      prefixText: auth.user?.currency == 'INR' ? '₹ ' : '\$ ',
                      filled: true,
                      fillColor: AppTheme.background.withOpacity(0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (val) {
                      amount = double.tryParse(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(labelText: 'MONTH'),
                          items: List.generate(12, (index) => index + 1).map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(labelText: 'YEAR'),
                          items: List.generate(5, (index) => DateTime.now().year - 2 + index).map((y) {
                            return DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedYear = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (amount == null || amount! <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid amount")),
                        );
                        return;
                      }
                      final success = await dashboard.addSalary(
                        auth,
                        amount: amount!,
                        month: selectedMonth,
                        year: selectedYear,
                        type: inflowType,
                      );
                      if (success) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("${inflowType == 'SALARY' ? 'Salary' : 'Bonus'} added successfully!"),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Failed to save inflow")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: inflowType == 'SALARY' ? AppTheme.emeraldGreen : AppTheme.cyanAdvance,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Save Inflow",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getPresetsList(List<FinancialEntry> recentTransactions) {
    final List<Map<String, dynamic>> defaultPresets = [
      {'label': 'Dinner 🍔', 'title': 'Dinner', 'amount': 15.0, 'type': 'SPENDING', 'desc': 'Dining out / food'},
      {'label': 'Uber/Cab 🚗', 'title': 'Uber/Cab', 'amount': 10.0, 'type': 'SPENDING', 'desc': 'Transport ride'},
      {'label': 'Coffee ☕', 'title': 'Coffee', 'amount': 5.0, 'type': 'SPENDING', 'desc': 'Daily caffeine run'},
      {'label': 'SIP 📈', 'title': 'SIP', 'amount': 250.0, 'type': 'SAVINGS', 'desc': 'Invested savings / SIP'},
      {'label': 'Lending 💸', 'title': 'Lending', 'amount': 50.0, 'type': 'LENDING', 'desc': 'Lent money'}
    ];

    if (recentTransactions.isEmpty) return defaultPresets;

    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var t in recentTransactions) {
      final title = t.title;
      final type = t.type;
      final key = "${title.trim().toLowerCase()}_$type";
      if (!uniqueMap.containsKey(key)) {
        String emoji = '💸';
        final titleLower = title.toLowerCase();
        if (type == 'SAVINGS' || titleLower.contains('sip') || titleLower.contains('save') || titleLower.contains('invest') || titleLower.contains('saving')) {
          emoji = '📈';
        } else if (titleLower.contains('food') || titleLower.contains('eat') || titleLower.contains('restaurant') || titleLower.contains('cafe') || titleLower.contains('dinner') || titleLower.contains('lunch') || titleLower.contains('breakfast')) {
          emoji = '🍔';
        } else if (titleLower.contains('uber') || titleLower.contains('cab') || titleLower.contains('taxi') || titleLower.contains('fuel') || titleLower.contains('travel') || titleLower.contains('car')) {
          emoji = '🚗';
        } else if (titleLower.contains('coffee') || titleLower.contains('starbucks') || titleLower.contains('tea')) {
          emoji = '☕';
        } else if (titleLower.contains('rent') || titleLower.contains('room') || titleLower.contains('flat') || titleLower.contains('home')) {
          emoji = '🏠';
        }

        uniqueMap[key] = {
          'label': "$title $emoji",
          'title': title,
          'amount': t.amount,
          'type': type,
          'desc': t.description,
          'count': 1,
          'timestamp': t.date.millisecondsSinceEpoch,
        };
      } else {
        uniqueMap[key]!['count'] = (uniqueMap[key]!['count'] as int) + 1;
      }
    }

    final presets = uniqueMap.values.toList();
    presets.sort((a, b) {
      final countComp = (b['count'] as int).compareTo(a['count'] as int);
      if (countComp != 0) return countComp;
      return (b['timestamp'] as int).compareTo(a['timestamp'] as int);
    });

    final List<Map<String, dynamic>> result = presets.take(6).toList();
    if (result.length < 4) {
      for (var def in defaultPresets) {
        final isDup = result.any((p) => p['type'] == def['type'] && (p['title'] as String).toLowerCase() == (def['title'] as String).toLowerCase());
        if (!isDup && result.length < 6) {
          result.add(def);
        }
      }
    }
    return result;
  }

  void _showAllPresetsSheet(BuildContext context, List<Map<String, dynamic>> presets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bolt_rounded, color: AppTheme.primaryPurple),
                      SizedBox(width: 8),
                      Text("Autofill Presets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...presets.map((preset) {
                Color color = AppTheme.primaryPurple;
                if (preset['type'] == 'SPENDING') color = AppTheme.roseRed;
                else if (preset['type'] == 'LENDING') color = AppTheme.blueLending;
                else if (preset['type'] == 'LOAN') color = AppTheme.orangeLoan;
                else if (preset['type'] == 'ADVANCE') color = AppTheme.cyanAdvance;
                else if (preset['type'] == 'SAVINGS') color = AppTheme.secondaryGold;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _logPresetEntry(context, preset);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        border: Border.all(color: color.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(preset['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 2),
                                Text(preset['desc'] ?? 'Preset', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  preset['type'],
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatCurrency(preset['amount'], Provider.of<AuthProvider>(context, listen: false).user?.currency ?? 'USD'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _logPresetEntry(BuildContext context, Map<String, dynamic> preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EntryFormSheet(
        entryToEdit: FinancialEntry(
          id: -1, // Use -1 to trigger new entry creation inside EntryFormSheet
          userId: '',
          amount: preset['amount'],
          title: preset['title'],
          description: preset['desc'] ?? '',
          type: preset['type'],
          useSalaryBalance: preset['type'] == 'SPENDING',
          date: DateTime.now(),
        ),
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
    final streaks = dashboard.streaks;
    final currency = user?.currency ?? 'USD';

    // Parse date boundary info
    final startDateStr = dashboard.startDate != null
        ? DateFormat('MMM d').format(dashboard.startDate!)
        : '...';
    final endDateStr = dashboard.endDate != null
        ? DateFormat('MMM d').format(dashboard.endDate!)
        : '...';

    // Generate Autofill presets
    final presets = _getPresetsList(dashboard.recentTransactions);

    // Filter recent transactions locally
    final filteredTransactions = dashboard.recentTransactions.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesType = _typeFilter == 'ALL' || t.type == _typeFilter;
      return matchesSearch && matchesType;
    }).toList();

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
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QRScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => dashboard.fetchDashboard(auth),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => dashboard.fetchDashboard(auth),
        color: AppTheme.primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cycle boundary dates & filter dropdown card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CYCLE BOUNDARIES",
                            style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$startDateStr → $endDateStr",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: dashboard.filter,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.surface,
                      items: const [
                        DropdownMenuItem(value: 'current', child: Text("Current Cycle", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'last', child: Text("Last Cycle", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'last3', child: Text("Last 3 Months", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'last6', child: Text("Last 6 Months", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'custom', child: Text("Custom Date", style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        if (val == 'custom') {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.primaryPurple,
                                  onPrimary: Colors.white,
                                  surface: AppTheme.surface,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (range != null) {
                            dashboard.setCustomRange(range.start, range.end);
                            dashboard.setFilter('custom');
                            if (context.mounted) dashboard.fetchDashboard(auth);
                          }
                        } else {
                          dashboard.setFilter(val);
                          dashboard.fetchDashboard(auth);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Unified Portfolio Summary Widget
              _buildUnifiedPortfolioWidget(
                context,
                kpis['currentBalance'] ?? 0.0,
                stockProvider.summary?.totalCurrentValue ?? 0.0,
                kpis['savings'] ?? 0.0,
                currency,
                stockProvider.summary?.totalInvested ?? 0.0,
                kpis['salaryBalance'] ?? 0.0,
              ),

              // Available Capital Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.darkCardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.05),
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
                          "TOTAL AVAILABLE CAPITAL",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.grey,
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
                            "Reserves Synced",
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatCurrency(kpis['currentBalance'] ?? 0.0, currency),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SALARY BALANCE", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(kpis['salaryBalance'] ?? 0.0, currency),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.emeraldGreen),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showAddInflowSheet(context),
                              icon: const Icon(Icons.add, color: AppTheme.emeraldGreen, size: 16),
                              label: const Text("Salary", style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: AppTheme.emeraldGreen.withOpacity(0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const EntryFormSheet(),
                                );
                              },
                              icon: const Icon(Icons.add_box_rounded, color: Colors.white, size: 16),
                              label: const Text("Entry", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Autofill presets horizontal scroll bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.bolt_rounded, color: AppTheme.secondaryGold, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "AUTOFILL PRESETS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showAllPresetsSheet(context, presets),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Text("All Presets", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                          ...presets.map((preset) {
                            return GestureDetector(
                              onTap: () => _logPresetEntry(context, preset),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    Text(preset['label'], style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _formatCurrency(preset['amount'], currency).replaceAll(".00", ""),
                                        style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Zero Spend / Limit Spend Streaks
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "LEDGER STREAKS",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              border: Border.all(color: Colors.orange.withOpacity(0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Zero Spend", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange.shade400),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${streaks['level1'] ?? 0} Days",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                const Text("Zero spending days logged", style: TextStyle(fontSize: 8, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.yellow.withOpacity(0.05),
                              border: Border.all(color: Colors.yellow.withOpacity(0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Limit Spend", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Icon(Icons.bolt_rounded, size: 14, color: Colors.yellow.shade400),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${streaks['level2'] ?? 0} Days",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                Text(
                                  "Under ${_formatCurrency(streaks['level2Limit'] ?? 0.0, currency).replaceAll(".00", "")}/day",
                                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stocks portfolio performance card
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
              const SizedBox(height: 16),

              // KPI Metrics 5-Card Grid (2 columns)
              const Text(
                "FINANCIAL SUMMARY",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKPICard("Spending", kpis['spending'] ?? 0.0, AppTheme.roseRed, currency, "Expenses logged"),
                  _buildKPICard("SIP / Wealth", kpis['savings'] ?? 0.0, AppTheme.secondaryGold, currency, "Savings & SIPs"),
                  _buildKPICard("Lending", kpis['lending'] ?? 0.0, AppTheme.blueLending, currency, "Money lent out"),
                  _buildKPICard("Loan Debts", kpis['loan'] ?? 0.0, AppTheme.orangeLoan, currency, "Active debts"),
                  _buildKPICard("Advances", kpis['advance'] ?? 0.0, AppTheme.cyanAdvance, currency, "Advance logs"),
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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

              // Recent Transactions Feed List with filters & search
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Recent Transactions",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              "Real-time ledger feed",
                              style: TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            TabChangeNotification(1).dispatch(context); // Go to History tab
                          },
                          icon: const Icon(Icons.history_rounded, size: 14, color: AppTheme.primaryPurple),
                          label: const Text("Full List", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Search ledger...",
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.background.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tab filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'SPENDING', 'SAVINGS', 'LENDING', 'LOAN', 'ADVANCE'].map((tab) {
                          final isSelected = _typeFilter == tab;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _typeFilter = tab;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryPurple.withOpacity(0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryPurple.withOpacity(0.4) : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  tab,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primaryPurple : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Transactions List
                    if (filteredTransactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Colors.grey, size: 36),
                            SizedBox(height: 8),
                            Text("No matching transactions", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final entry = filteredTransactions[index];
                          return _buildTransactionItem(context, auth, dashboard, entry, currency);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Insights Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryPurple, size: 18),
                        SizedBox(width: 8),
                        Text("AI Insights Preview", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.08),
                        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (kpis['spending'] ?? 0.0) > 0
                            ? "You spent ${_formatCurrency(kpis['spending'] ?? 0.0, currency)} this cycle. Your salary balance is ${_formatCurrency(kpis['salaryBalance'] ?? 0.0, currency)}. Ask Gemini for suggestions!"
                            : "No spending logged this cycle yet! Keep track of expenses to let Gemini analyze savings trends and give optimization ideas.",
                        style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        TabChangeNotification(3).dispatch(context); // Go to Chat tab
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                      label: const Text("Ask AI Assistant", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                  TabChangeNotification(2).dispatch(context); // Go to Stocks tab
                },
              ),
              const SizedBox(height: 12),
              FeedListItem(
                title: "My Spending Hub",
                description: "Inspect historical transactions, splits, and lendings lists.",
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.cyan,
                onTap: () {
                  TabChangeNotification(1).dispatch(context); // Go to History tab
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedPortfolioWidget(
    BuildContext context,
    double currentBalance,
    double shareValue,
    double sipValue,
    String currency,
    double totalInvested,
    double salaryBalance,
  ) {
    final currencySymbol = currency == 'INR' ? '₹' : '\$';
    
    // Trigger WidgetKit / AppWidget update in background
    HomeWidgetService.updateWidgetData(
      availableBalance: currentBalance,
      shareValue: shareValue,
      sipValue: sipValue,
      currencySymbol: currencySymbol,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TOTAL ASSETS OVERVIEW",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryPurple.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 10,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Widget Synced",
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildPortfolioStatItem(
                      title: "SALARY BALANCE",
                      value: _formatCurrency(salaryBalance, currency),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppTheme.emeraldGreen,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  Expanded(
                    child: _buildPortfolioStatItem(
                      title: "TOTAL ASSETS",
                      value: _formatCurrency(salaryBalance + sipValue, currency),
                      icon: Icons.assured_workload_rounded,
                      color: AppTheme.cyanAdvance,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  Expanded(
                    child: _buildPortfolioStatItem(
                      title: "SAVINGS & SIPS",
                      value: _formatCurrency(sipValue, currency),
                      icon: Icons.savings_rounded,
                      color: AppTheme.secondaryGold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value.replaceAll(".00", ""),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, double amount, Color themeColor, String currency, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
              )
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _formatCurrency(amount, currency),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: themeColor),
            overflow: TextOverflow.ellipsis,
          ),
          Text(desc, style: const TextStyle(fontSize: 7.5, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, AuthProvider auth, DashboardProvider dashboard, FinancialEntry entry, String currency) {
    Color typeColor = AppTheme.roseRed;
    IconData icon = Icons.arrow_outward_rounded;

    if (entry.type == 'SAVINGS') {
      typeColor = AppTheme.secondaryGold;
      icon = Icons.track_changes_rounded;
    } else if (entry.type == 'LENDING') {
      typeColor = AppTheme.blueLending;
      icon = Icons.swap_horiz_rounded;
    } else if (entry.type == 'LOAN') {
      typeColor = AppTheme.orangeLoan;
      icon = Icons.help_outline_rounded;
    } else if (entry.type == 'ADVANCE') {
      typeColor = AppTheme.cyanAdvance;
      icon = Icons.arrow_downward_rounded;
    }

    final isOutflow = entry.type == 'SPENDING' || entry.type == 'LENDING';
    final entriesProvider = Provider.of<EntriesProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: typeColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.08),
                        border: Border.all(color: typeColor.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.type,
                        style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: typeColor),
                      ),
                    ),
                    if (entry.useSalaryBalance) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "DEDUCTED",
                          style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d').format(entry.date),
                      style: const TextStyle(fontSize: 8.5, color: Colors.grey),
                    ),
                  ],
                ),
                if (entry.type == 'LENDING') ...[
                  const SizedBox(height: 2),
                  entry.unpaidAmount <= 0
                      ? const Text("Fully Repaid", style: TextStyle(fontSize: 8, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold))
                      : Text(
                          "Unpaid: ${_formatCurrency(entry.unpaidAmount, currency)}",
                          style: const TextStyle(fontSize: 8, color: AppTheme.blueLending, fontWeight: FontWeight.bold),
                        ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${isOutflow ? '-' : '+'}${_formatCurrency(entry.amount, currency).replaceAll(".00", "")}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOutflow ? AppTheme.roseRed : AppTheme.emeraldGreen,
                ),
              ),
              const SizedBox(width: 4),
              // Repay button
              if (entry.type == 'LENDING' && entry.unpaidAmount > 0)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppTheme.emeraldGreen),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => EntryFormSheet(parentLending: entry),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.grey),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => EntryFormSheet(entryToEdit: entry),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.grey),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text("Delete Transaction"),
                      content: const Text("Are you sure you want to delete this transaction from the ledger?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.roseRed),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final deleted = await entriesProvider.deleteEntry(auth, entry.id);
                    if (deleted) {
                      dashboard.fetchDashboard(auth);
                    }
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          )
        ],
      ),
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stock_provider.dart';
import '../../models/financial_entry.dart';
import '../../models/stock_holding.dart';

class LogicalPeriod {
  final int month; // 1-indexed (1-12)
  final int year;
  LogicalPeriod({required this.month, required this.year});
}

class CycleRange {
  final DateTime startDate;
  final DateTime endDate;
  CycleRange({required this.startDate, required this.endDate});
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  List<dynamic> _salaries = [];
  List<dynamic> _bonuses = [];
  List<FinancialEntry> _entries = [];
  List<StockHolding> _stockHoldings = [];
  PortfolioSummary? _stockSummary;

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  String _activeTab = 'cashflow'; // cashflow, spending, savings, stocks, breakdown

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final headers = auth.headers;

      // 1. Fetch Salaries
      final salResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/salary'),
        headers: headers,
      );
      final List<dynamic> salData = salResponse.statusCode == 200 ? jsonDecode(salResponse.body) : [];

      // 2. Fetch Bonuses
      final bonResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/bonus'),
        headers: headers,
      );
      final List<dynamic> bonData = bonResponse.statusCode == 200 ? jsonDecode(bonResponse.body) : [];

      // 3. Fetch Entries
      final entResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/entries'),
        headers: headers,
      );
      final List<dynamic> entList = entResponse.statusCode == 200 ? jsonDecode(entResponse.body) : [];
      final List<FinancialEntry> parsedEntries = entList.map((e) => FinancialEntry.fromJson(e)).toList();

      // 4. Fetch Stocks
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      await stockProvider.fetchHoldings(auth);

      setState(() {
        _salaries = salData;
        _bonuses = bonData;
        _entries = parsedEntries;
        _stockHoldings = stockProvider.holdings;
        _stockSummary = stockProvider.summary;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching reports data: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  CycleRange _getCycleRange(DateTime dateRef, int cycleDate) {
    final year = dateRef.year;
    final month = dateRef.month;
    final day = dateRef.day;

    int startYear = year;
    int startMonth = month;

    if (day >= cycleDate) {
      startMonth = month;
    } else {
      startMonth = month - 1;
      if (startMonth < 1) {
        startMonth = 12;
        startYear = year - 1;
      }
    }

    final startDate = DateTime(startYear, startMonth, cycleDate);

    int endMonth = startMonth + 1;
    int endYear = startYear;
    if (endMonth > 12) {
      endMonth = 1;
      endYear = startYear + 1;
    }

    final endDate = DateTime(endYear, endMonth, cycleDate).subtract(const Duration(milliseconds: 1));
    return CycleRange(startDate: startDate, endDate: endDate);
  }

  LogicalPeriod _getLogicalCyclePeriod(DateTime dateRef, int cycleDate) {
    final year = dateRef.year;
    final month = dateRef.month;
    final day = dateRef.day;

    if (day >= cycleDate) {
      return LogicalPeriod(month: month, year: year);
    } else {
      int logicalMonth = month - 1;
      int logicalYear = year;
      if (logicalMonth < 1) {
        logicalMonth = 12;
        logicalYear = year - 1;
      }
      return LogicalPeriod(month: logicalMonth, year: logicalYear);
    }
  }

  String _formatCurrency(double amount, String currencyCode) {
    final format = NumberFormat.currency(
      symbol: currencyCode == 'INR' ? '₹' : '\$',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  // --- CALENDAR DATA UTILS ---
  List<DateTime> _getCalendarGridDays() {
    final now = DateTime.now();
    const daysToShow = 365;
    final gridStartDate = now.subtract(const Duration(days: daysToShow - 1));
    final startDayOfWeek = gridStartDate.weekday % 7; // Sunday is 0, Mon is 1, etc. in weekday (Dart has Mon=1, Sun=7)
    // Map weekday: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7 to Sun=0, Mon=1, etc.
    final correctedStartDay = startDayOfWeek == 7 ? 0 : startDayOfWeek;

    final alignedStartDate = gridStartDate.subtract(Duration(days: correctedStartDay));
    final totalDays = daysToShow + correctedStartDay;

    return List.generate(totalDays, (index) => alignedStartDate.add(Duration(days: index)));
  }

  Map<String, dynamic> _getCellMetadata(DateTime day) {
    final String dateStr = DateFormat('yyyy-MM-dd').format(day);

    final dayEntries = _entries.where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateStr).toList();
    
    final daySalaries = _salaries.where((s) {
      final sDate = s['createdAt'] != null ? DateTime.parse(s['createdAt']) : DateTime.now();
      return DateFormat('yyyy-MM-dd').format(sDate) == dateStr;
    }).toList();

    final totalCount = dayEntries.length + daySalaries.length;

    if (totalCount == 0) {
      return {
        'color': const Color(0xFF0D1423).withOpacity(0.4),
        'borderColor': const Color(0x1AFFFFFF),
        'tooltip': '${DateFormat('MMM d, yyyy').format(day)}: No transactions',
        'entries': <FinancialEntry>[],
        'salaries': <dynamic>[],
      };
    }

    final hasSalary = daySalaries.isNotEmpty;
    final hasLoan = dayEntries.any((e) => e.type == 'LOAN');
    final hasAdvance = dayEntries.any((e) => e.type == 'ADVANCE');
    final hasLending = dayEntries.any((e) => e.type == 'LENDING');
    final hasSavings = dayEntries.any((e) => e.type == 'SAVINGS');
    final hasSpending = dayEntries.any((e) => e.type == 'SPENDING');

    Color cellColor = const Color(0xFF1E293B);
    Color borderCellColor = const Color(0x33FFFFFF);
    String labelText = '';

    if (hasSalary) {
      cellColor = AppTheme.emeraldGreen;
      borderCellColor = AppTheme.emeraldGreen.withOpacity(0.5);
      labelText = 'Salary received 💰';
    } else if (hasLoan) {
      cellColor = AppTheme.orangeLoan;
      borderCellColor = AppTheme.orangeLoan.withOpacity(0.5);
      labelText = 'Loan logged ⚠️';
    } else if (hasAdvance) {
      cellColor = AppTheme.cyanAdvance;
      borderCellColor = AppTheme.cyanAdvance.withOpacity(0.5);
      labelText = 'Advance received ⚡';
    } else if (hasLending) {
      cellColor = AppTheme.blueLending;
      borderCellColor = AppTheme.blueLending.withOpacity(0.5);
      labelText = 'Money lent 💸';
    } else if (hasSavings) {
      cellColor = AppTheme.secondaryGold;
      borderCellColor = AppTheme.secondaryGold.withOpacity(0.5);
      labelText = 'Invested savings 📈';
    } else if (hasSpending) {
      final spendAmount = dayEntries
          .where((e) => e.type == 'SPENDING')
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      labelText = 'Spent ${spendAmount.toStringAsFixed(0)}';

      if (spendAmount <= 500) {
        cellColor = AppTheme.primaryPurple.withOpacity(0.2);
        borderCellColor = AppTheme.primaryPurple.withOpacity(0.3);
      } else if (spendAmount <= 2000) {
        cellColor = AppTheme.primaryPurple.withOpacity(0.5);
        borderCellColor = AppTheme.primaryPurple.withOpacity(0.6);
      } else if (spendAmount <= 5000) {
        cellColor = AppTheme.primaryPurple;
        borderCellColor = AppTheme.primaryPurple.withOpacity(0.8);
      } else {
        cellColor = const Color(0xFFA78BFA);
        borderCellColor = Colors.white.withOpacity(0.8);
      }
    }

    final dateLabel = DateFormat('MMM d, yyyy').format(day);
    final tooltip = '$dateLabel: ${labelText.isNotEmpty ? labelText : '$totalCount transaction(s)'}';

    return {
      'color': cellColor,
      'borderColor': borderCellColor,
      'tooltip': tooltip,
      'entries': dayEntries,
      'salaries': daySalaries,
    };
  }

  List<Map<String, dynamic>> _getMonthLabels(List<DateTime> daysList) {
    final List<Map<String, dynamic>> labels = [];
    int prevMonth = -1;
    for (int i = 0; i < daysList.length; i += 7) {
      final day = daysList[i];
      final currentMonthIdx = day.month;
      if (currentMonthIdx != prevMonth) {
        labels.add({
          'text': DateFormat('MMM').format(day),
          'colIndex': i ~/ 7,
        });
        prevMonth = currentMonthIdx;
      }
    }
    return labels;
  }

  List<DateTime?> _getMonthDays(DateTime monthDate) {
    final year = monthDate.year;
    final month = monthDate.month;
    final firstDay = DateTime(year, month, 1);
    final startDayOfWeek = firstDay.weekday % 7; // Sun = 0, Mon = 1 ...
    final totalDays = DateTime(year, month + 1, 0).day;

    final List<DateTime?> days = [];
    for (int i = 0; i < startDayOfWeek; i++) {
      days.add(null);
    }
    for (int i = 1; i <= totalDays; i++) {
      days.add(DateTime(year, month, i));
    }
    return days;
  }

  // --- STATS / CHART PREPARATION ---
  Map<String, double> _getCurrentPeriodStats(int cycleDate) {
    final now = DateTime.now();
    final logicalPeriod = _getLogicalCyclePeriod(now, cycleDate);

    // Filter salary of this month
    final matchingSalaries = _salaries.where((s) => s['month'] == logicalPeriod.month && s['year'] == logicalPeriod.year);
    final salaryAmt = matchingSalaries.fold<double>(0.0, (sum, s) => sum + double.parse(s['amount'].toString()));

    final matchingBonuses = _bonuses.where((b) => b['month'] == logicalPeriod.month && b['year'] == logicalPeriod.year);
    final bonusAmt = matchingBonuses.fold<double>(0.0, (sum, b) => sum + double.parse(b['amount'].toString()));

    final cycleRange = _getCycleRange(now, cycleDate);

    final periodInflows = _entries.where((e) {
      return e.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1))) &&
          (e.type == 'ADVANCE' || e.type == 'LOAN');
    });
    final inflowExtra = periodInflows.fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalInflow = salaryAmt + bonusAmt + inflowExtra;

    final periodOutflows = _entries.where((e) {
      return e.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1))) &&
          (e.type == 'SPENDING' || e.type == 'LENDING' || e.type == 'SAVINGS');
    });
    final totalOutflow = periodOutflows.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Calculate invested savings
    double totalSavings = 0.0;
    for (final entry in _entries) {
      if (entry.type == 'SAVINGS') {
        if (!entry.useSalaryBalance) {
          // If logged outside salary balance in this cycle
          if (entry.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
              entry.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1)))) {
            totalSavings += entry.amount;
          }
        } else {
          // Check linked deductions for this logical period
          // Note: Deductions is optional in our JSON payload
        }
      }
    }

    return {
      'inflow': totalInflow,
      'outflow': totalOutflow,
      'savings': totalSavings,
    };
  }

  List<Map<String, dynamic>> _prepareMonthlyComparisonData(int cycleDate) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    // Past 6 cycles
    for (int i = 5; i >= 0; i--) {
      // Find reference date for that cycle
      final refDate = DateTime(now.year, now.month - i, 15);
      final logicalPeriod = _getLogicalCyclePeriod(refDate, cycleDate);
      final cycleRange = _getCycleRange(refDate, cycleDate);

      final label = '${DateFormat('MMM').format(refDate)} ${logicalPeriod.year.toString().substring(2)}';

      // Salary/Bonus
      final matchingSalaries = _salaries.where((s) => s['month'] == logicalPeriod.month && s['year'] == logicalPeriod.year);
      final salaryAmt = matchingSalaries.fold<double>(0.0, (sum, s) => sum + double.parse(s['amount'].toString()));

      final matchingBonuses = _bonuses.where((b) => b['month'] == logicalPeriod.month && b['year'] == logicalPeriod.year);
      final bonusAmt = matchingBonuses.fold<double>(0.0, (sum, b) => sum + double.parse(b['amount'].toString()));

      // Inflow
      final periodInflows = _entries.where((e) {
        return e.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1))) &&
            (e.type == 'ADVANCE' || e.type == 'LOAN');
      });
      final inflowExtra = periodInflows.fold<double>(0.0, (sum, e) => sum + e.amount);
      final totalInflow = salaryAmt + bonusAmt + inflowExtra;

      // Outflow
      final periodOutflows = _entries.where((e) {
        return e.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1))) &&
            (e.type == 'SPENDING' || e.type == 'LENDING' || e.type == 'SAVINGS');
      });
      final totalOutflow = periodOutflows.fold<double>(0.0, (sum, e) => sum + e.amount);

      final totalSpending = periodOutflows.where((e) => e.type == 'SPENDING').fold<double>(0.0, (sum, e) => sum + e.amount);

      // Remaining Balance & Savings
      final totalSavings = periodOutflows.where((e) => e.type == 'SAVINGS').fold<double>(0.0, (sum, e) => sum + e.amount);
      final remainingBalance = (totalInflow - totalOutflow).clamp(0.0, double.infinity);

      result.add({
        'name': label,
        'inflow': totalInflow,
        'outflow': totalOutflow,
        'spending': totalSpending,
        'remaining': remainingBalance,
        'savings': totalSavings,
      });
    }

    return result;
  }

  List<PieChartSectionData> _prepareCategoriesPieData(int cycleDate) {
    final now = DateTime.now();
    final cycleRange = _getCycleRange(now, cycleDate);

    final currentPeriodSpending = _entries.where((e) {
      return e.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1))) &&
          (e.type == 'SPENDING' || e.type == 'SAVINGS');
    }).toList();

    if (currentPeriodSpending.isEmpty) return [];

    final Map<String, double> groups = {};
    for (final e in currentPeriodSpending) {
      if (e.type == 'SAVINGS') {
        groups['Invested Savings'] = (groups['Invested Savings'] ?? 0.0) + e.amount;
        continue;
      }
      final title = e.title.trim().toLowerCase();
      String cat = 'Others';

      if (title.contains('food') || title.contains('eat') || title.contains('restaurant') || title.contains('cafe')) {
        cat = 'Dining Out';
      } else if (title.contains('rent') || title.contains('flat') || title.contains('room')) {
        cat = 'Rent & Living';
      } else if (title.contains('movie') || title.contains('game') || title.contains('ott') || title.contains('netflix') || title.contains('fun')) {
        cat = 'Entertainment';
      } else if (title.contains('travel') || title.contains('cab') || title.contains('uber') || title.contains('fuel') || title.contains('bike') || title.contains('car')) {
        cat = 'Transport';
      } else if (title.contains('bill') || title.contains('recharge') || title.contains('wifi') || title.contains('power') || title.contains('electricity')) {
        cat = 'Utilities';
      } else if (title.contains('cloth') || title.contains('shop') || title.contains('shoes') || title.contains('amazon') || title.contains('flipkart')) {
        cat = 'Shopping';
      }

      groups[cat] = (groups[cat] ?? 0.0) + e.amount;
    }

    final categories = groups.entries.toList();
    final double total = categories.fold(0.0, (sum, item) => sum + item.value);

    return categories.map((c) {
      final name = c.key;
      final val = c.value;
      final color = _getCategoryColor(name);
      final percentage = total > 0 ? (val / total) * 100 : 0.0;

      return PieChartSectionData(
        color: color,
        value: val,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _getCategoryColor(String name) {
    switch (name) {
      case 'Dining Out':
        return AppTheme.emeraldGreen;
      case 'Rent & Living':
        return AppTheme.primaryPurple;
      case 'Entertainment':
        return AppTheme.orangeLoan;
      case 'Transport':
        return AppTheme.blueLending;
      case 'Utilities':
        return AppTheme.cyanAdvance;
      case 'Shopping':
        return const Color(0xFFEC4899);
      case 'Invested Savings':
        return AppTheme.secondaryGold;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.user?.currency ?? 'USD';
    final int cycleDate = auth.user?.salaryCycleDate ?? 1;

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryPurple),
              SizedBox(height: 16),
              Text("Analyzing Financial Ledger...", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final stats = _getCurrentPeriodStats(cycleDate);
    final netCashflow = stats['inflow']! - stats['outflow']!;
    final calendarDays = _getCalendarGridDays();
    final monthLabels = _getMonthLabels(calendarDays);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reports & Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text("Gen-Z style cashflow & holdings reports", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Net Cashflow, Invested Savings & Stocks Value Widgets
            Row(
              children: [
                Expanded(child: _buildKPICard("NET CASHFLOW", netCashflow, stats['inflow']! >= stats['outflow']! ? AppTheme.emeraldGreen : AppTheme.roseRed, currency)),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard("INVESTED SAVINGS", stats['savings']!, AppTheme.secondaryGold, currency)),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard("STOCKS VALUE", _stockSummary?.totalCurrentValue ?? 0.0, AppTheme.cyanAdvance, currency)),
              ],
            ),
            const SizedBox(height: 20),

            // Row 2: GitHub contribution calendar
            Container(
              padding: const EdgeInsets.all(16.0),
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
                      const Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, color: AppTheme.primaryPurple, size: 18),
                          SizedBox(width: 8),
                          Text("Transaction Calendar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        ],
                      ),
                      Text("12m activities", style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Calendar scrollable grid
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Labels
                        SizedBox(
                          height: 16,
                          child: Stack(
                            children: monthLabels.map((l) {
                              return Positioned(
                                left: l['colIndex'] * 14.0 + 32,
                                child: Text(l['text'], style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day Labels
                            const Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                SizedBox(height: 10, child: Text("M", style: TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold))),
                                SizedBox(height: 14),
                                SizedBox(height: 10, child: Text("W", style: TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold))),
                                SizedBox(height: 14),
                                SizedBox(height: 10, child: Text("F", style: TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(width: 8),

                            // Weeks Grid
                            Row(
                              children: List.generate((calendarDays.length / 7).ceil(), (wIdx) {
                                return Column(
                                  children: List.generate(7, (dIdx) {
                                    final index = wIdx * 7 + dIdx;
                                    if (index >= calendarDays.length) return const SizedBox(width: 10, height: 10);
                                    final day = calendarDays[index];
                                    final metadata = _getCellMetadata(day);
                                    final isSelected = DateFormat('yyyy-MM-dd').format(day) == DateFormat('yyyy-MM-dd').format(_selectedDate);

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDate = day;
                                          _currentMonth = day;
                                        });
                                      },
                                      child: Tooltip(
                                        message: metadata['tooltip'],
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.all(2.0),
                                          decoration: BoxDecoration(
                                            color: metadata['color'],
                                            borderRadius: BorderRadius.circular(2.0),
                                            border: isSelected
                                                ? Border.all(color: Colors.white, width: 1.0)
                                                : Border.all(color: metadata['borderColor'], width: 0.5),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Month date navigator
                  const Divider(color: AppTheme.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                          });
                        },
                      ),
                    ],
                  ),

                  // Day columns selector
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.0,
                    children: [
                      for (final dayName in ["S", "M", "T", "W", "T", "F", "S"])
                        Center(child: Text(dayName, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))),
                      
                      ..._getMonthDays(_currentMonth).map((day) {
                        if (day == null) return const SizedBox.shrink();

                        final metadata = _getCellMetadata(day);
                        final isSelected = DateFormat('yyyy-MM-dd').format(day) == DateFormat('yyyy-MM-dd').format(_selectedDate);

                        final hasSalary = metadata['salaries'].isNotEmpty;
                        final hasLoan = (metadata['entries'] as List<FinancialEntry>).any((e) => e.type == 'LOAN');
                        final hasAdvance = (metadata['entries'] as List<FinancialEntry>).any((e) => e.type == 'ADVANCE');
                        final hasLending = (metadata['entries'] as List<FinancialEntry>).any((e) => e.type == 'LENDING');
                        final hasSavings = (metadata['entries'] as List<FinancialEntry>).any((e) => e.type == 'SAVINGS');
                        final hasSpending = (metadata['entries'] as List<FinancialEntry>).any((e) => e.type == 'SPENDING');

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDate = day;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? AppTheme.primaryPurple : Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasSalary) Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppTheme.emeraldGreen, shape: BoxShape.circle)),
                                    if (hasSpending) Padding(padding: const EdgeInsets.only(left: 1), child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFC084FC), shape: BoxShape.circle))),
                                    if (hasSavings || hasLending || hasLoan || hasAdvance) Padding(padding: const EdgeInsets.only(left: 1), child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppTheme.secondaryGold, shape: BoxShape.circle))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily Detail Logs
            _buildDailyDetails(currency),
            const SizedBox(height: 20),

            // Swipeable Tabbed Analytics Panel
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Visual Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 12),

                  // Horizontal selector tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton("cashflow", "Cash Flow", Icons.swap_horiz_rounded),
                        _buildTabButton("spending", "Spending", Icons.trending_down_rounded),
                        _buildTabButton("savings", "Savings", Icons.savings_outlined),
                        _buildTabButton("stocks", "Stocks", Icons.show_chart_rounded),
                        _buildTabButton("breakdown", "Categories", Icons.pie_chart_outline_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab content
                  SizedBox(
                    height: 220,
                    child: _buildTabChart(cycleDate, currency),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, double value, Color color, String currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(value, currency),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDetails(String currency) {
    final metadata = _getCellMetadata(_selectedDate);
    final List<FinancialEntry> dayEntries = metadata['entries'];
    final List<dynamic> daySalaries = metadata['salaries'];
    final hasTx = dayEntries.isNotEmpty || daySalaries.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppTheme.primaryPurple, size: 18),
              const SizedBox(width: 8),
              Text(
                "Logs on ${DateFormat('MMM d, yyyy').format(_selectedDate)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasTx)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    const Text("No transactions recorded on this date.", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else ...[
            for (final salary in daySalaries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Income Inflow", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text('${salary['type'] ?? 'Salary'} Month', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      ],
                    ),
                    Text("+ ${_formatCurrency(double.parse(salary['amount'].toString()), currency)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emeraldGreen)),
                  ],
                ),
              ),

            for (final entry in dayEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.type == 'SPENDING' || entry.type == 'LENDING' || entry.type == 'SAVINGS' ? 'Outflow' : 'Inflow', style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                        Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      ],
                    ),
                    Text(
                      '${entry.type == 'SPENDING' || entry.type == 'LENDING' || entry.type == 'SAVINGS' ? '-' : '+'} ${_formatCurrency(entry.amount, currency)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: entry.type == 'SPENDING'
                            ? AppTheme.primaryPurple
                            : entry.type == 'SAVINGS'
                                ? AppTheme.secondaryGold
                                : entry.type == 'LENDING'
                                    ? AppTheme.blueLending
                                    : AppTheme.emeraldGreen,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String name, IconData icon) {
    final isSelected = _activeTab == tabId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabId;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primaryPurple : AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Text(name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChart(int cycleDate, String currency) {
    final monthlyData = _prepareMonthlyComparisonData(cycleDate);

    if (monthlyData.isEmpty) {
      return const Center(child: Text("Not enough transaction data to generate charts.", style: TextStyle(color: Colors.grey)));
    }

    if (_activeTab == 'cashflow') {
      return LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withOpacity(0.03), strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < monthlyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(monthlyData[idx]['name'], style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  return Text(_formatCompact(val), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(monthlyData.length, (idx) => FlSpot(idx.toDouble(), monthlyData[idx]['inflow'])),
              isCurved: true,
              color: AppTheme.emeraldGreen,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppTheme.emeraldGreen.withOpacity(0.08)),
            ),
            LineChartBarData(
              spots: List.generate(monthlyData.length, (idx) => FlSpot(idx.toDouble(), monthlyData[idx]['outflow'])),
              isCurved: true,
              color: AppTheme.roseRed,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppTheme.roseRed.withOpacity(0.08)),
            ),
          ],
        ),
      );
    }

    if (_activeTab == 'spending') {
      return BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < monthlyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(monthlyData[idx]['name'], style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  return Text(_formatCompact(val), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(monthlyData.length, (idx) {
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: monthlyData[idx]['spending'],
                  color: AppTheme.primaryPurple,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }),
        ),
      );
    }

    if (_activeTab == 'savings') {
      return BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < monthlyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(monthlyData[idx]['name'], style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  return Text(_formatCompact(val), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(monthlyData.length, (idx) {
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: monthlyData[idx]['remaining'] + monthlyData[idx]['savings'],
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  rodStackItems: [
                    BarChartRodStackItem(0, monthlyData[idx]['remaining'], AppTheme.emeraldGreen),
                    BarChartRodStackItem(monthlyData[idx]['remaining'], monthlyData[idx]['remaining'] + monthlyData[idx]['savings'], AppTheme.secondaryGold),
                  ],
                )
              ],
            );
          }),
        ),
      );
    }

    if (_activeTab == 'stocks') {
      if (_stockHoldings.isEmpty) {
        return const Center(child: Text("No Stock assets held in your portfolio.", style: TextStyle(color: Colors.grey, fontSize: 12)));
      }
      return BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < _stockHoldings.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(_stockHoldings[idx].symbol.split('.').first, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  return Text(_formatCompact(val), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(_stockHoldings.length, (idx) {
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: _stockHoldings[idx].investedValue,
                  color: AppTheme.primaryPurple,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                ),
                BarChartRodData(
                  toY: _stockHoldings[idx].currentValue,
                  color: AppTheme.cyanAdvance,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                )
              ],
            );
          }),
        ),
      );
    }

    // breakdown categories distribution
    final pieSections = _prepareCategoriesPieData(cycleDate);
    if (pieSections.isEmpty) {
      return const Center(child: Text("No expenditures mapped in this cycle.", style: TextStyle(color: Colors.grey, fontSize: 12)));
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sections: pieSections,
              centerSpaceRadius: 28,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pieSections.map((s) {
                final double val = s.value;
                // find name from colors or custom map
                final name = _getCategoryNameByColor(s.color);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                      Text(_formatCurrency(val, currency), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _getCategoryNameByColor(Color color) {
    if (color == AppTheme.emeraldGreen) return 'Dining Out';
    if (color == AppTheme.primaryPurple) return 'Rent & Living';
    if (color == AppTheme.orangeLoan) return 'Entertainment';
    if (color == AppTheme.blueLending) return 'Transport';
    if (color == AppTheme.cyanAdvance) return 'Utilities';
    if (color == const Color(0xFFEC4899)) return 'Shopping';
    if (color == AppTheme.secondaryGold) return 'Invested Savings';
    return 'Others';
  }

  String _formatCompact(double value) {
    return NumberFormat.compact().format(value);
  }
}

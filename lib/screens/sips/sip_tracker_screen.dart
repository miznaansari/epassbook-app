import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/sips_provider.dart';
import '../../models/sip.dart';

class SipTrackerScreen extends StatefulWidget {
  const SipTrackerScreen({super.key});

  @override
  State<SipTrackerScreen> createState() => _SipTrackerScreenState();
}

class _SipTrackerScreenState extends State<SipTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<SipsProvider>(context, listen: false).fetchSips(auth);
    });
  }

  String _formatCurrency(double amount, String currencyCode) {
    final format = NumberFormat.currency(
      symbol: currencyCode == 'INR' ? '₹' : '\$',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  void _showAddSipSheet(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sipsProvider = Provider.of<SipsProvider>(context, listen: false);

    final formKey = GlobalKey<FormState>();
    String title = '';
    double amount = 0.0;
    String frequency = 'MONTHLY'; // MONTHLY or WEEKLY
    int selectedDayOfMonth = 1;
    int selectedDayOfWeek = 1; // 1 = Monday, 7 = Sunday
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    String reminderTimeStr = "10:00";

    final List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

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
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.add_chart_rounded, color: AppTheme.primaryPurple),
                              SizedBox(width: 8),
                              Text(
                                "Create SIP Flow",
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
                      // Title input
                      TextFormField(
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'SIP TITLE',
                          hintText: 'e.g. Navi Nifty 50, HDFC Mutual Fund',
                          fillColor: AppTheme.background.withOpacity(0.4),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                        onChanged: (val) => title = val.trim(),
                      ),
                      const SizedBox(height: 16),
                      // Amount input
                      TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'SIP AMOUNT',
                          prefixText: auth.user?.currency == 'INR' ? '₹ ' : '\$ ',
                          fillColor: AppTheme.background.withOpacity(0.4),
                        ),
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null || double.parse(val) <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                        onChanged: (val) => amount = double.tryParse(val) ?? 0.0,
                      ),
                      const SizedBox(height: 16),
                      // Frequency selection
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => frequency = 'MONTHLY'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: frequency == 'MONTHLY' ? AppTheme.primaryPurple : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: frequency == 'MONTHLY' ? AppTheme.primaryPurple : AppTheme.border,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Monthly",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: frequency == 'MONTHLY' ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => frequency = 'WEEKLY'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: frequency == 'WEEKLY' ? AppTheme.primaryPurple : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: frequency == 'WEEKLY' ? AppTheme.primaryPurple : AppTheme.border,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Weekly",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: frequency == 'WEEKLY' ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date Selector based on Frequency
                      if (frequency == 'MONTHLY')
                        DropdownButtonFormField<int>(
                          value: selectedDayOfMonth,
                          decoration: InputDecoration(
                            labelText: 'DAY OF MONTH',
                            fillColor: AppTheme.background.withOpacity(0.4),
                          ),
                          items: List.generate(31, (index) => index + 1).map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text("Day $day"),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedDayOfMonth = val);
                          },
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: selectedDayOfWeek,
                          decoration: InputDecoration(
                            labelText: 'DAY OF WEEK',
                            fillColor: AppTheme.background.withOpacity(0.4),
                          ),
                          items: List.generate(7, (index) => index + 1).map((dayNum) {
                            return DropdownMenuItem(
                              value: dayNum,
                              child: Text(weekdays[dayNum - 1]),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedDayOfWeek = val);
                          },
                        ),
                      const SizedBox(height: 16),
                      // Custom Notification Time Picker
                      InkWell(
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
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
                          if (picked != null) {
                            setModalState(() {
                              selectedTime = picked;
                              reminderTimeStr = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.background.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "NOTIFICATION REMINDER TIME",
                                    style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedTime.format(context),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              const Icon(Icons.access_time_rounded, color: AppTheme.primaryPurple),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action button
                      ElevatedButton(
                        onPressed: sipsProvider.loading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final success = await sipsProvider.createSip(
                                  auth,
                                  title: title,
                                  amount: amount,
                                  frequency: frequency,
                                  dayOfMonth: frequency == 'MONTHLY' ? selectedDayOfMonth : null,
                                  dayOfWeek: frequency == 'WEEKLY' ? selectedDayOfWeek : null,
                                  reminderTime: reminderTimeStr,
                                );

                                if (success) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("SIP '$title' created successfully"),
                                        backgroundColor: AppTheme.emeraldGreen,
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Failed to create SIP")),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: sipsProvider.loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Create SIP",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Sip sip) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sipsProvider = Provider.of<SipsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Delete SIP Flow?"),
        content: Text("Are you sure you want to stop tracking '${sip.title}'? This will not delete previously logged transactions."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await sipsProvider.deleteSip(auth, sip.id);
              if (success) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Stopped SIP '${sip.title}'"),
                      backgroundColor: AppTheme.roseRed,
                    ),
                  );
                }
              }
            },
            child: const Text("Stop Tracking", style: TextStyle(color: AppTheme.roseRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmTransactionDialog(BuildContext context, Sip sip, SipPeriod period) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sipsProvider = Provider.of<SipsProvider>(context, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final currency = auth.user?.currency ?? 'USD';
    final dateFormatted = DateFormat('dd MMM yyyy').format(period.targetDate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline_rounded, color: AppTheme.emeraldGreen),
            SizedBox(width: 8),
            Text("Confirm Transaction"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Log a new savings entry in your passbook for this SIP:", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            Text("SIP Plan: ${sip.title}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text("Amount: ${_formatCurrency(sip.amount, currency)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text("Cycle Date: $dateFormatted", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await sipsProvider.confirmSipPayment(
                auth,
                sipId: sip.id,
                date: period.targetDate,
              );

              if (success) {
                // Refresh dashboard to reflect new balance & savings KPI
                dashboardProvider.fetchDashboard(auth);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Logged savings transaction for '${sip.title}'"),
                      backgroundColor: AppTheme.emeraldGreen,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to log transaction. Insufficient balance?")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirm & Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final sipsProvider = Provider.of<SipsProvider>(context);
    final currency = auth.user?.currency ?? 'USD';

    // Compute stats
    final activeSips = sipsProvider.sips.where((s) => s.isActive).toList();
    final double totalActiveAmount = activeSips.fold(0.0, (sum, item) => sum + item.amount);
    final int weeklyCount = activeSips.where((s) => s.frequency == 'WEEKLY').length;
    final int monthlyCount = activeSips.where((s) => s.frequency == 'MONTHLY').length;

    String weekdayMapping(int dayNum) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      if (dayNum >= 1 && dayNum <= 7) return days[dayNum - 1];
      return '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Systematic Investment (SIP)"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => sipsProvider.fetchSips(auth),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => sipsProvider.fetchSips(auth),
        color: AppTheme.primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Statistics Widget
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.darkCardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      "TOTAL DEDICATED SIP CAPITAL",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(totalActiveAmount, currency),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text("WEEKLY PLANS", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              "$weeklyCount Active",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryGold),
                            )
                          ],
                        ),
                        Container(width: 1, height: 30, color: AppTheme.border),
                        Column(
                          children: [
                            const Text("MONTHLY PLANS", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              "$monthlyCount Active",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                            )
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Active SIP Flows (${sipsProvider.sips.length})",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddSipSheet(context),
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryPurple),
                    label: const Text("Add New", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sipsProvider.loading && sipsProvider.sips.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                  ),
                )
              else if (sipsProvider.sips.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.savings_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        "No systematic investment plans created yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showAddSipSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Initialize First SIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              else
                ...sipsProvider.sips.map((sip) {
                  final String scheduleDesc = sip.frequency == 'MONTHLY'
                      ? "Monthly on Day ${sip.dayOfMonth}"
                      : "Weekly on ${weekdayMapping(sip.dayOfWeek ?? 1)}";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sip.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: sip.frequency == 'MONTHLY'
                                              ? AppTheme.primaryPurple.withOpacity(0.2)
                                              : AppTheme.secondaryGold.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sip.frequency,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: sip.frequency == 'MONTHLY'
                                                ? AppTheme.primaryPurple
                                                : AppTheme.secondaryGold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        scheduleDesc,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatCurrency(sip.amount, currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.roseRed, size: 20),
                                  onPressed: () => _showDeleteConfirmDialog(context, sip),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              "Reminder set for daily checks at ${sip.reminderTime}",
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Scrollable status tracker timeline
                        const Text(
                          "LEDGER STATUS & TIMELINE",
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: sip.periods.map((period) {
                              Color statusColor;
                              IconData statusIcon;
                              String labelText = period.status;

                              if (period.isPaid) {
                                statusColor = AppTheme.emeraldGreen;
                                statusIcon = Icons.check;
                                labelText = 'Paid';
                              } else if (period.status == 'MISSED') {
                                statusColor = AppTheme.roseRed;
                                statusIcon = Icons.close;
                                labelText = 'Missed';
                              } else {
                                statusColor = Colors.grey.withOpacity(0.5);
                                statusIcon = Icons.more_horiz;
                                labelText = 'Pending';
                              }

                              return GestureDetector(
                                onTap: period.isPaid
                                    ? null
                                    : () => _showConfirmTransactionDialog(context, sip, period),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        period.label,
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: statusColor.withOpacity(0.2),
                                        child: Icon(statusIcon, size: 12, color: statusColor),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        labelText,
                                        style: TextStyle(fontSize: 8, color: statusColor, fontWeight: FontWeight.bold),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

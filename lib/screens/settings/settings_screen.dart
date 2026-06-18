import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salaryDateController = TextEditingController();
  final _timezoneController = TextEditingController();
  
  String _currency = 'USD';
  bool _notifSalary = true;
  bool _notifDaily = true;
  bool _notifCycle = true;
  bool _notifDailySpend = true;
  
  bool _isSaving = false;
  String _successMessage = '';

  // Salary dialog inputs
  final _salaryAmountController = TextEditingController();
  String _salaryType = 'SALARY';
  int _salaryMonth = DateTime.now().month;
  int _salaryYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _salaryDateController.text = user.salaryCycleDate.toString();
      _timezoneController.text = user.timezone;
      _currency = user.currency;
      _notifSalary = user.notifSalary;
      _notifDaily = user.notifDaily;
      _notifCycle = user.notifCycle;
      _notifDailySpend = user.notifDailySpend;
    }
  }

  @override
  void dispose() {
    _salaryDateController.dispose();
    _timezoneController.dispose();
    _salaryAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _successMessage = '';
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    final success = await auth.updatePreferences({
      'salaryCycleDate': int.parse(_salaryDateController.text),
      'currency': _currency,
      'timezone': _timezoneController.text.trim(),
      'notifSalary': _notifSalary,
      'notifDaily': _notifDaily,
      'notifCycle': _notifCycle,
      'notifDailySpend': _notifDailySpend,
    });

    if (success && mounted) {
      await dashboard.fetchDashboard(auth);
      setState(() {
        _successMessage = 'Settings saved successfully!';
      });
    }

    setState(() {
      _isSaving = false;
    });
  }

  void _showAddSalaryDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _salaryAmountController.text = "1000";
    _salaryType = 'SALARY';
    _salaryMonth = DateTime.now().month;
    _salaryYear = DateTime.now().year;

    final months = List.generate(12, (index) => index + 1);
    final years = List.generate(5, (index) => DateTime.now().year - 2 + index);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Deposit Salary / Bonus", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _salaryAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'AMOUNT', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _salaryType,
                      decoration: const InputDecoration(labelText: 'TYPE'),
                      items: const [
                        DropdownMenuItem(value: 'SALARY', child: Text('Monthly Salary')),
                        DropdownMenuItem(value: 'BONUS', child: Text('Bonus Deposit')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => _salaryType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _salaryMonth,
                            decoration: const InputDecoration(labelText: 'MONTH'),
                            items: months.map((m) => DropdownMenuItem(value: m, child: Text(m.toString()))).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => _salaryMonth = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _salaryYear,
                            decoration: const InputDecoration(labelText: 'YEAR'),
                            items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => _salaryYear = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final double amt = double.tryParse(_salaryAmountController.text) ?? 0.0;
                    if (amt <= 0) return;

                    final dashboard = Provider.of<DashboardProvider>(context, listen: false);
                    final done = await dashboard.addSalary(
                      auth,
                      amount: amt,
                      month: _salaryMonth,
                      year: _salaryYear,
                      type: _salaryType,
                    );

                    if (done && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Salary recorded successfully!")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  child: const Text("Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Settings & Options", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_successMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppTheme.emeraldGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_successMessage, style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Deposit Action
              ElevatedButton.icon(
                onPressed: _showAddSalaryDialog,
                icon: const Icon(Icons.wallet_rounded, color: Colors.white),
                label: const Text("Deposit Salary / Bonus Funds", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 28),

              // Section 1: Cycle config
              const Text("BUDGETING CYCLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryDateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'SALARY CYCLE CALENDAR DATE (1-31)',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a cycle date';
                  final parsed = int.tryParse(value);
                  if (parsed == null || parsed < 1 || parsed > 31) return 'Must be between 1 and 31';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Section 2: Regional
              const Text("CURRENCY & REGION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(
                  labelText: 'PREFERRED CURRENCY',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('US Dollars (\$)')),
                  DropdownMenuItem(value: 'INR', child: Text('Indian Rupee (₹)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _currency = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timezoneController,
                decoration: const InputDecoration(
                  labelText: 'TIMEZONE',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: Notifications
              const Text("NOTIFICATIONS RULES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Salary deposit logs", style: TextStyle(fontSize: 13, color: Colors.white)),
                      value: _notifSalary,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (val) => setState(() => _notifSalary = val),
                    ),
                    const Divider(color: AppTheme.border, height: 1),
                    SwitchListTile(
                      title: const Text("Daily spending summary", style: TextStyle(fontSize: 13, color: Colors.white)),
                      value: _notifDaily,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (val) => setState(() => _notifDaily = val),
                    ),
                    const Divider(color: AppTheme.border, height: 1),
                    SwitchListTile(
                      title: const Text("Salary cycle changes warning", style: TextStyle(fontSize: 13, color: Colors.white)),
                      value: _notifCycle,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (val) => setState(() => _notifCycle = val),
                    ),
                    const Divider(color: AppTheme.border, height: 1),
                    SwitchListTile(
                      title: const Text("Daily reminders alert", style: TextStyle(fontSize: 13, color: Colors.white)),
                      value: _notifDailySpend,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (val) => setState(() => _notifDailySpend = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSaveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Preferences", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

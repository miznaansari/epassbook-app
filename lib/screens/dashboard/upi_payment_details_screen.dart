import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/dashboard_provider.dart';

class UPIPaymentDetailsScreen extends StatefulWidget {
  final String upiId;
  final String payeeName;
  final String note;
  final double? initialAmount;

  const UPIPaymentDetailsScreen({
    super.key,
    required this.upiId,
    required this.payeeName,
    required this.note,
    this.initialAmount,
  });

  @override
  State<UPIPaymentDetailsScreen> createState() => _UPIPaymentDetailsScreenState();
}

class _UPIPaymentDetailsScreenState extends State<UPIPaymentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _upiIdController;
  late TextEditingController _payeeNameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  bool _useSalaryBalance = true;
  bool _isLoading = false;
  String _selectedApp = 'upi'; // 'phonepe', 'gpay', 'paytm', 'upi'

  @override
  void initState() {
    super.initState();
    _upiIdController = TextEditingController(text: widget.upiId);
    _payeeNameController = TextEditingController(
      text: widget.payeeName == 'Merchant/Payee' ? '' : widget.payeeName,
    );
    _amountController = TextEditingController(
      text: widget.initialAmount != null ? widget.initialAmount!.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addAmountPreset(double value) {
    final currentText = _amountController.text;
    final currentAmount = double.tryParse(currentText) ?? 0.0;
    setState(() {
      _amountController.text = (currentAmount + value).toStringAsFixed(0);
    });
  }

  Future<void> _processUPIPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final String upiId = _upiIdController.text.trim();
    final String payeeName = _payeeNameController.text.trim();
    final double amount = double.parse(_amountController.text);
    final String note = _noteController.text.trim();

    // 1. Construct UPI deep link URI based on selected app
    String scheme = 'upi';
    String path = 'pay';
    
    if (_selectedApp == 'phonepe') {
      scheme = 'phonepe';
      path = 'upi/pay';
    } else if (_selectedApp == 'gpay') {
      scheme = 'gpay';
      path = 'upi/pay';
    } else if (_selectedApp == 'paytm') {
      scheme = 'paytmmp';
      path = 'upi/pay';
    }

    final Uri upiUri = Uri.parse('$scheme://$path').replace(queryParameters: {
      'pa': upiId,
      'pn': payeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (note.isNotEmpty) 'tn': note,
    });

    setState(() {
      _isLoading = true;
    });

    // 2. Launch external UPI application
    bool launched = false;
    try {
      launched = await launchUrl(
        upiUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint("Error launching UPI intent: $e");
    }

    if (!launched) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppTheme.roseRed),
                SizedBox(width: 8),
                Text("No UPI App Found", style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              "We could not launch ${_selectedApp == 'upi' ? 'a UPI' : _selectedApp.toUpperCase()} app. Please make sure the selected app is installed on this device.",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 3. Prompt user / Log transaction to DB
    if (mounted) {
      _showTrackTransactionDialog(upiId, payeeName, amount, note);
    }
  }

  void _showTrackTransactionDialog(String upiId, String payeeName, double amount, String note) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppTheme.emeraldGreen),
            SizedBox(width: 8),
            Text("Redirected to UPI App", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          "We opened your UPI app to pay ₹${amount.toStringAsFixed(2)} to $payeeName.\n\nWould you like to log this transaction in your ePassbook?",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Pop dialog
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                Navigator.pop(context); // Pop back to dashboard
              }
            },
            child: const Text("Discard", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Pop dialog
              await _logTransactionToBackend(upiId, payeeName, amount, note);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Log Transaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _logTransactionToBackend(String upiId, String payeeName, double amount, String note) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final entriesProvider = Provider.of<EntriesProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

      final result = await entriesProvider.saveEntry(
        auth,
        amount: amount,
        title: 'Paid: $payeeName',
        description: 'UPI ID: $upiId${note.isNotEmpty ? " | Note: $note" : ""}',
        type: 'SPENDING',
        useSalaryBalance: _useSalaryBalance,
        salaryMonth: _useSalaryBalance ? DateTime.now().month : null,
        salaryYear: _useSalaryBalance ? DateTime.now().year : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Success: Refresh data and return
          await dashboardProvider.fetchDashboard(auth);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("UPI Transaction logged successfully!"),
                backgroundColor: AppTheme.emeraldGreen,
              ),
            );
            Navigator.pop(context); // Pop back to dashboard
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Failed to save transaction"),
              backgroundColor: AppTheme.roseRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error logging transaction: $e"),
            backgroundColor: AppTheme.roseRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("UPI Payment Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Payee Info Form Group Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: AppTheme.primaryPurple, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "PAYEE DETAILS",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _payeeNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Payee / Merchant Name',
                              labelStyle: const TextStyle(fontSize: 12),
                              hintText: 'e.g. John Doe, Coffee Shop',
                              filled: true,
                              fillColor: AppTheme.background.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter payee name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _upiIdController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Payee UPI ID',
                              labelStyle: const TextStyle(fontSize: 12),
                              hintText: 'e.g. merchant@upi or name@okaxis',
                              filled: true,
                              fillColor: AppTheme.background.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter UPI ID';
                              }
                              final trimmed = value.trim();
                              if (!trimmed.contains('@')) {
                                return 'Invalid UPI ID format (must contain @)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount Text Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'PAYMENT AMOUNT (INR)',
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a valid amount';
                        }
                        final amt = double.tryParse(value);
                        if (amt == null || amt <= 0) {
                          return 'Amount must be greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Quick presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPresetButton(100, "+ ₹100"),
                        _buildPresetButton(500, "+ ₹500"),
                        _buildPresetButton(1000, "+ ₹1000"),
                        _buildPresetButton(2000, "+ ₹2000"),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // UPI App Chooser Selector
                    const Text(
                      "SELECT PAYMENT APP",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildAppOption('phonepe', 'PhonePe', Icons.account_balance_wallet_rounded, Colors.purple),
                        _buildAppOption('gpay', 'Google Pay', Icons.payment_rounded, Colors.blue),
                        _buildAppOption('paytm', 'Paytm', Icons.credit_card_rounded, Colors.lightBlue),
                        _buildAppOption('upi', 'Any App', Icons.apps_rounded, Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Transaction Note Field
                    TextFormField(
                      controller: _noteController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'TRANSACTION NOTE (OPTIONAL)',
                        hintText: 'e.g. Dinner, Groceries, Rent',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Salary Deduction Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Deduct from Salary Balance",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Locks and subtracts from current month salary limit",
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useSalaryBalance,
                            activeColor: AppTheme.emeraldGreen,
                            activeTrackColor: AppTheme.emeraldGreen.withOpacity(0.3),
                            onChanged: (val) {
                              setState(() {
                                _useSalaryBalance = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Action Button
                    ElevatedButton(
                      onPressed: _processUPIPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            "Confirm & Launch Payment",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPresetButton(double value, String label) {
    return InkWell(
      onTap: () => _addAmountPreset(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildAppOption(String appId, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedApp == appId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedApp = appId;
        });
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.21,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? activeColor : AppTheme.background,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

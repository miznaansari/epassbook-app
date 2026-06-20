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
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  bool _useSalaryBalance = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null ? widget.initialAmount!.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
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

    final double amount = double.parse(_amountController.text);
    final String note = _noteController.text.trim();

    // 1. Construct UPI deep link URI
    final Uri upiUri = Uri.parse('upi://pay').replace(queryParameters: {
      'pa': widget.upiId,
      'pn': widget.payeeName,
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
            content: const Text(
              "No supported UPI applications (PhonePe, Google Pay, Paytm, etc.) were found on this device. Please install a UPI app to proceed.",
              style: TextStyle(color: Colors.white70),
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
      _showTrackTransactionDialog(amount, note);
    }
  }

  void _showTrackTransactionDialog(double amount, String note) {
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
          "We opened your UPI app to pay ₹${amount.toStringAsFixed(2)} to ${widget.payeeName}.\n\nWould you like to log this transaction in your ePassbook?",
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
              await _logTransactionToBackend(amount, note);
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

  Future<void> _logTransactionToBackend(double amount, String note) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final entriesProvider = Provider.of<EntriesProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

      final result = await entriesProvider.saveEntry(
        auth,
        amount: amount,
        title: 'Paid: ${widget.payeeName}',
        description: 'UPI ID: ${widget.upiId}${note.isNotEmpty ? " | Note: $note" : ""}',
        type: 'SPENDING',
        useSalaryBalance: _useSalaryBalance,
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
                    // Payee Info Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryPurple,
                            child: Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.payeeName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.upiId,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                    const SizedBox(height: 24),

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
                    const SizedBox(height: 36),

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
}

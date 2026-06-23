import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/dashboard_provider.dart';
import 'upi_payment_details_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;

  // Pending payment states for logging on return
  bool _waitingForPaymentReturn = false;
  String? _pendingUpiId;
  String? _pendingPayeeName;
  double? _pendingAmount;
  String? _pendingNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForPaymentReturn) {
      _waitingForPaymentReturn = false;
      _showLogTransactionDialog();
    }
  }

  void _showLogTransactionDialog() {
    final TextEditingController amountController = TextEditingController(
      text: _pendingAmount != null ? _pendingAmount!.toStringAsFixed(2) : '',
    );
    final TextEditingController noteController = TextEditingController(text: _pendingNote ?? '');
    bool useSalaryBalance = true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AppTheme.emeraldGreen),
                  SizedBox(width: 8),
                  Text("Log Transaction?", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "You scanned the QR for ${_pendingPayeeName ?? 'Merchant'}.\nWould you like to log this spending in your ePassbook?",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "AMOUNT PAID (INR)",
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                        prefixText: "₹ ",
                        prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: AppTheme.background.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "NOTE (OPTIONAL)",
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                        filled: true,
                        fillColor: AppTheme.background.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Deduct from Salary",
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: useSalaryBalance,
                          activeColor: AppTheme.emeraldGreen,
                          onChanged: (val) {
                            setDialogState(() {
                              useSalaryBalance = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secondaryGold.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.secondaryGold, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Payment Failed or Limit Error?",
                                style: TextStyle(
                                  color: AppTheme.secondaryGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "UPI apps block direct intents > ₹2,000. Copy the UPI ID and pay manually to bypass it.",
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _pendingUpiId ?? ''));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("UPI ID copied! Opening UPI app..."),
                                    backgroundColor: AppTheme.emeraldGreen,
                                  ),
                                );
                              }
                              try {
                                await launchUrl(
                                  Uri.parse("upi://"),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (e) {
                                debugPrint("Error launching base upi: $e");
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                            label: const Text(
                              "Copy UPI & Open App",
                              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryGold,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(context); // Close dialog
                          if (mounted) Navigator.pop(context); // Close scan screen
                        },
                  child: const Text("Discard", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amtStr = amountController.text.trim();
                          final amt = double.tryParse(amtStr) ?? 0.0;
                          if (amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a valid amount"),
                                backgroundColor: AppTheme.roseRed,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          await _logTransactionToBackend(
                            _pendingUpiId ?? '',
                            _pendingPayeeName ?? 'Merchant',
                            amt,
                            noteController.text.trim(),
                            useSalaryBalance,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            Navigator.pop(context); // Close scan screen
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Log Spending", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logTransactionToBackend(
    String upiId,
    String payeeName,
    double amount,
    String note,
    bool useSalaryBalance,
  ) async {
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
        useSalaryBalance: useSalaryBalance,
        salaryMonth: useSalaryBalance ? DateTime.now().month : null,
        salaryYear: useSalaryBalance ? DateTime.now().year : null,
      );

      if (result['success'] == true) {
        await dashboardProvider.fetchDashboard(auth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("UPI Transaction logged successfully!"),
              backgroundColor: AppTheme.emeraldGreen,
            ),
          );
        }
      } else {
        if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error logging transaction: $e"),
            backgroundColor: AppTheme.roseRed,
          ),
        );
      }
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue ?? barcodes.first.displayValue;
    debugPrint("QR Scanner detected raw/display value: '$rawValue'");

    if (rawValue == null || rawValue.trim().isEmpty) return;

    final String trimmed = rawValue.trim();
    final String normalized = trimmed.toLowerCase();

    // Check if it's a valid UPI URI
    if (!normalized.startsWith('upi://pay')) {
      debugPrint("Scanner error: Detected non-UPI QR code.");
      setState(() {
        _isProcessing = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid QR: '$trimmed'. Please scan a valid UPI QR code."),
          backgroundColor: AppTheme.roseRed,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
      return;
    }

    // Process valid UPI QR
    setState(() {
      _isProcessing = true;
    });

    // Parse parameters
    try {
      final Uri uri = Uri.parse(trimmed);
      final String? pa = uri.queryParameters['pa'] ?? uri.queryParameters['PA'];
      final String? pn = uri.queryParameters['pn'] ?? uri.queryParameters['PN'];
      final String? tn = uri.queryParameters['tn'] ?? uri.queryParameters['TN'];
      final String? amStr = uri.queryParameters['am'] ?? uri.queryParameters['AM'];

      debugPrint("Parsed UPI details - pa: '$pa', pn: '$pn', tn: '$tn', am: '$amStr'");

      if (pa == null || pa.isEmpty) {
        throw Exception("Missing UPI ID (pa)");
      }

      double? initialAmount;
      if (amStr != null && amStr.isNotEmpty) {
        initialAmount = double.tryParse(amStr);
      }

      // Stop scanner
      _controller.stop();

      // Save details for returning to app
      _pendingUpiId = pa;
      _pendingPayeeName = pn ?? 'Merchant/Payee';
      _pendingAmount = initialAmount;
      _pendingNote = tn ?? '';
      _waitingForPaymentReturn = true;

      // Launch URL directly using standard system chooser
      final Uri upiUri = Uri.parse(trimmed);
      bool launched = false;
      try {
        launched = await launchUrl(
          upiUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint("Error launching UPI directly: $e");
      }

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Direct launch failed. Redirecting to manual screen..."),
              backgroundColor: AppTheme.roseRed,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UPIPaymentDetailsScreen(
                upiId: pa,
                payeeName: pn ?? 'Merchant/Payee',
                note: tn ?? '',
                initialAmount: initialAmount,
                originalQueryParams: uri.queryParameters,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing UPI details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error parsing UPI details: ${e.toString()}"),
          backgroundColor: AppTheme.roseRed,
        ),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Scan UPI QR",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off_rounded, color: Colors.white70);
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: AppTheme.secondaryGold);
                  default:
                    return const Icon(Icons.flash_off_rounded, color: Colors.white70);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front_rounded, color: Colors.white70);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear_rounded, color: Colors.white70);
                  default:
                    return const Icon(Icons.camera_rear_rounded, color: Colors.white70);
                }
              },
            ),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Stylish Scanning Overlay
          _buildScannerOverlay(context),
          
          // Instruction text at bottom
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Align UPI QR inside the frame",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Supports GPay, PhonePe, Paytm, BHIM QR codes",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () {
                      _controller.stop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UPIPaymentDetailsScreen(
                            upiId: '',
                            payeeName: '',
                            note: '',
                            initialAmount: null,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      "Enter Details Manually",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final double scanWindowSize = MediaQuery.of(context).size.width * 0.7;
    
    return Stack(
      children: [
        // Semi-transparent background with cut-out hole
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: scanWindowSize,
                  height: scanWindowSize,
                  decoration: BoxDecoration(
                    color: Colors.red, // Arbitrary color for cutout
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Premium corner-borders for scanner frame
        Center(
          child: SizedBox(
            width: scanWindowSize,
            height: scanWindowSize,
            child: Stack(
              children: [
                // Top-Left corner
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.primaryPurple, width: 4),
                        left: BorderSide(color: AppTheme.primaryPurple, width: 4),
                      ),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
                    ),
                  ),
                ),
                // Top-Right corner
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.primaryPurple, width: 4),
                        right: BorderSide(color: AppTheme.primaryPurple, width: 4),
                      ),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
                    ),
                  ),
                ),
                // Bottom-Left corner
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.primaryPurple, width: 4),
                        left: BorderSide(color: AppTheme.primaryPurple, width: 4),
                      ),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
                    ),
                  ),
                ),
                // Bottom-Right corner
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.primaryPurple, width: 4),
                        right: BorderSide(color: AppTheme.primaryPurple, width: 4),
                      ),
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
                    ),
                  ),
                ),
                
                // Pulsing red scanning laser line
                const LaserLineIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LaserLineIndicator extends StatefulWidget {
  const LaserLineIndicator({super.key});

  @override
  State<LaserLineIndicator> createState() => _LaserLineIndicatorState();
}

class _LaserLineIndicatorState extends State<LaserLineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.width * 0.7 * _animation.value,
          left: 16,
          right: 16,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withOpacity(0.1),
                  AppTheme.primaryPurple,
                  AppTheme.primaryPurple.withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withOpacity(0.8),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/constants.dart';
import 'upi_payment_details_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
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
      // Show error snackbar but limit toast flooding
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
      // Support both lowercase and uppercase parameters
      final String? pa = uri.queryParameters['pa'] ?? uri.queryParameters['PA']; // UPI ID
      final String? pn = uri.queryParameters['pn'] ?? uri.queryParameters['PN']; // Payee Name
      final String? tn = uri.queryParameters['tn'] ?? uri.queryParameters['TN']; // Transaction Note
      final String? amStr = uri.queryParameters['am'] ?? uri.queryParameters['AM']; // Amount

      debugPrint("Parsed UPI details - pa: '$pa', pn: '$pn', tn: '$tn', am: '$amStr'");

      if (pa == null || pa.isEmpty) {
        throw Exception("Missing UPI ID (pa)");
      }

      double? initialAmount;
      if (amStr != null && amStr.isNotEmpty) {
        initialAmount = double.tryParse(amStr);
      }

      // Stop scanner and navigate
      _controller.stop();
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

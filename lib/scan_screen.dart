import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'common.dart';
import 'invitee_details_screen.dart';

class ScanScreen extends StatefulWidget {
  final int eventId;

  const ScanScreen({super.key, required this.eventId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController scannerController = MobileScannerController();
  bool _isScanning = false;
  bool _flashOn = false;
  bool _showSuccess = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Start the scanner when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scannerController.start();
    });
  }

  @override
  void dispose() {
    scannerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetection(BarcodeCapture capture) async {
    // Check if we're already processing a scan
    if (_isScanning) return;

    try {
      final List<Barcode> barcodes = capture.barcodes;
      if (barcodes.isEmpty) return;

      final code = barcodes.first.rawValue;
      if (code == null || code.isEmpty) return;

      debugPrint("QR Code detected: $code");

      setState(() => _isScanning = true);

      // Optional haptic feedback


      // Show success animation
      setState(() => _showSuccess = true);
      _animationController.forward();

      scannerController.stop(); // Pause camera

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InviteeDetailsScreen(
            eventId: widget.eventId,
            slug: code,
          ),
        ),
      ).then((_) {
        // Reset state after returning
        _animationController.reverse();
        setState(() {
          _showSuccess = false;
          _isScanning = false;
        });
        scannerController.start();
      });
    } catch (e) {
      debugPrint("Error in QR code scanning: $e");
      setState(() => _isScanning = false);
      scannerController.start(); // Restart scanner on error
    }
  }

  void _toggleFlash() async {
    await scannerController.toggleTorch();
    setState(() => _flashOn = !_flashOn);
  }

  @override
  Widget build(BuildContext context) {
    final scanBoxSize = MediaQuery.of(context).size.width * 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: _toggleFlash,
            tooltip: _flashOn ? 'Turn off Flash' : 'Turn on Flash',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Scanner
          MobileScanner(
            controller: scannerController,
            onDetect: _handleBarcodeDetection,
          ),

          // Black overlay with transparent hole
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
            painter: ScannerOverlayPainter(
              scannerBoxSize: scanBoxSize,
              borderColor: Colors.white,
              borderWidth: 2.0,
              overlayColor: Colors.black.withValues(alpha: 1.0),
            ),
          ),

          // Instruction label
          Positioned(
            top: 80,
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'Align QR Code within the box',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Success animation
          if (_showSuccess)
            ScaleTransition(
              scale: _animationController.drive(CurveTween(curve: Curves.elasticOut)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.85),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter to create a black overlay with a transparent hole for the scan box
class ScannerOverlayPainter extends CustomPainter {
  final double scannerBoxSize;
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;

  ScannerOverlayPainter({
    required this.scannerBoxSize,
    required this.borderColor,
    required this.borderWidth,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scannerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scannerBoxSize,
      height: scannerBoxSize,
    );

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scannerPath = Path()..addRect(scannerRect);

    final finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scannerPath,
    );

    canvas.drawPath(finalPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRect(scannerRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

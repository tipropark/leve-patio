import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_patio_colors.dart';

/// Full-screen QR scanner. Pops with the scanned raw value (String).
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _ctrl = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _hasScanned = true;
      Navigator.of(context).pop(raw);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Ler QR Code do Ticket'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.flash_on_rounded),
          tooltip: 'Lanterna',
          onPressed: () => _ctrl.toggleTorch(),
        ),
      ],
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
        ),
        // ── Overlay com janela de escaneamento ──────────────────────────
        CustomPaint(
          painter: _ScanOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Aponte para o QR Code do ticket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Draws a semi-transparent overlay with a clear scan window.
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side   = size.width * 0.65;
    final left   = (size.width  - side) / 2;
    final top    = (size.height - side) / 2 - 40;
    final window = Rect.fromLTWH(left, top, side, side);

    final paint = Paint()..color = Colors.black54;

    // Draw four rectangles around the window
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, window.top), paint)
      ..drawRect(
        Rect.fromLTWH(0, window.bottom, size.width, size.height - window.bottom),
        paint,
      )
      ..drawRect(Rect.fromLTWH(0, window.top, window.left, side), paint)
      ..drawRect(
        Rect.fromLTWH(window.right, window.top, size.width - window.right, side),
        paint,
      );

    // Corner accent
    final corner = Paint()
      ..color = AppPatioColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    final r = window;

    // Top-left
    canvas
      ..drawLine(r.topLeft, r.topLeft.translate(len, 0),  corner)
      ..drawLine(r.topLeft, r.topLeft.translate(0, len),  corner)
    // Top-right
      ..drawLine(r.topRight, r.topRight.translate(-len, 0), corner)
      ..drawLine(r.topRight, r.topRight.translate(0, len),  corner)
    // Bottom-left
      ..drawLine(r.bottomLeft, r.bottomLeft.translate(len, 0),  corner)
      ..drawLine(r.bottomLeft, r.bottomLeft.translate(0, -len), corner)
    // Bottom-right
      ..drawLine(r.bottomRight, r.bottomRight.translate(-len, 0), corner)
      ..drawLine(r.bottomRight, r.bottomRight.translate(0, -len), corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

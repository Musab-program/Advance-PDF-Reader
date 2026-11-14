import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Displays the user's picked image with a continuous vertical scanning
/// laser beam animation while the background AI inference runs.
class ImageScannerView extends StatefulWidget {
  final Uint8List imageBytes;
  final VoidCallback? onCancel;

  const ImageScannerView({
    super.key,
    required this.imageBytes,
    this.onCancel,
  });

  @override
  State<ImageScannerView> createState() => _ImageScannerViewState();
}

class _ImageScannerViewState extends State<ImageScannerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background subtle backdrop
        Container(
          color: theme.scaffoldBackgroundColor,
        ),

        // Centered Image with scanner beam overlay
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _ScannerLaserPainter(
                            progress: _animation.value,
                            laserColor: const Color(0xFF00E5FF),
                            glowColor: primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom status badge
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xEB161822),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'جاري تحليل وعزل الصورة بالذكاء الاصطناعي...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onCancel != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                    label: const Text(
                      'إلغاء العملية',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerLaserPainter extends CustomPainter {
  final double progress;
  final Color laserColor;
  final Color glowColor;

  _ScannerLaserPainter({
    required this.progress,
    required this.laserColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double y = size.height * progress;
    const double beamHeight = 40.0;

    // 1. Trailing gradient glow above the laser line
    final glowRect = Rect.fromLTRB(0, (y - beamHeight).clamp(0, size.height), size.width, y);
    if (glowRect.height > 0) {
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            laserColor.withValues(alpha: 0.0),
            laserColor.withValues(alpha: 0.22),
          ],
        ).createShader(glowRect);
      canvas.drawRect(glowRect, glowPaint);
    }

    // 2. The sharp laser line
    final linePaint = Paint()
      ..color = laserColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);

    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // 3. Center highlight beam
    final centerGlow = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), centerGlow);
  }

  @override
  bool shouldRepaint(covariant _ScannerLaserPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

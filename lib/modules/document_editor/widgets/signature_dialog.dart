import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

class SignatureData {
  final Uint8List pngBytes;
  final List<List<Offset>> normalizedLines;
  final Color color;
  final double aspectRatio;

  const SignatureData({
    required this.pngBytes,
    required this.normalizedLines,
    required this.color,
    required this.aspectRatio,
  });
}

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});

  static Future<SignatureData?> show(BuildContext context) {
    return LuxuryDialog.showCustom<SignatureData>(
      context,
      barrierDismissible: false,
      builder: (_) => const SignatureDialog(),
    );
  }

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final List<List<Offset>> _lines = [];
  Color _selectedColor = const Color(0xFF0F172A);
  final double _strokeWidth = 3.5;

  Future<SignatureData?> _processSignature() async {
    if (_lines.isEmpty) return null;

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    int totalPoints = 0;

    for (final line in _lines) {
      for (final p in line) {
        totalPoints++;
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    if (totalPoints < 2) return null;

    // Add padding around content
    const padding = 12.0;
    minX = (minX - padding).clamp(0.0, double.infinity);
    minY = (minY - padding).clamp(0.0, double.infinity);
    maxX += padding;
    maxY += padding;

    final width = (maxX - minX).clamp(40.0, 1000.0);
    final height = (maxY - minY).clamp(30.0, 600.0);

    // Normalize lines into [0, 1] relative to bounding box
    final normalized = <List<Offset>>[];
    for (final line in _lines) {
      final normLine = <Offset>[];
      for (final p in line) {
        normLine.add(Offset(
          ((p.dx - minX) / width).clamp(0.0, 1.0),
          ((p.dy - minY) / height).clamp(0.0, 1.0),
        ));
      }
      if (normLine.isNotEmpty) {
        normalized.add(normLine);
      }
    }

    // Render tight PNG
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderWidth = (width * 2.0).toInt().clamp(100, 1200);
    final renderHeight = (height * 2.0).toInt().clamp(60, 800);

    final paint = Paint()
      ..color = _selectedColor
      ..strokeWidth = _strokeWidth * 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final line in normalized) {
      if (line.isEmpty) continue;
      final path = Path()..moveTo(line.first.dx * renderWidth, line.first.dy * renderHeight);
      for (int i = 1; i < line.length; i++) {
        path.lineTo(line[i].dx * renderWidth, line[i].dy * renderHeight);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(renderWidth, renderHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();

    if (bytes == null) return null;

    return SignatureData(
      pngBytes: bytes,
      normalizedLines: normalized,
      color: _selectedColor,
      aspectRatio: width / height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: LuxuryDialog.cardDecoration(context, borderRadius: 24),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.draw_rounded, color: theme.primaryColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'wps_draw_signature'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _lines.add([details.localPosition]);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (_lines.isNotEmpty) {
                        _lines.last.add(details.localPosition);
                      }
                    });
                  },
                  child: CustomPaint(
                    painter: _SignaturePadPainter(_lines, _selectedColor, _strokeWidth),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _colorOption(const Color(0xFF0F172A)),
                    const SizedBox(width: 8),
                    _colorOption(const Color(0xFF1D4ED8)),
                    const SizedBox(width: 8),
                    _colorOption(const Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    _colorOption(const Color(0xFF16A34A)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _lines.clear();
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  label: Text('wps_clear'.tr, style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('cancel'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: LuxuryDialog.gradientButton(
                    context: context,
                    label: 'wps_approve_signature'.tr,
                    icon: Icons.check_rounded,
                    height: 44,
                    borderRadius: 13,
                    onTap: () async {
                      final data = await _processSignature();
                      if (context.mounted) {
                        Navigator.of(context).pop(data);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedColor == color;
    final outlineColor = isSelected
        ? theme.primaryColor
        : (isDark && color.computeLuminance() < 0.25)
            ? Colors.white.withValues(alpha: 0.55)
            : (isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.16));

    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 28,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: outlineColor,
            width: isSelected ? 2.5 : 1.3,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.35), blurRadius: 4, spreadRadius: 1)]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SignaturePadPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final Color color;
  final double strokeWidth;

  _SignaturePadPainter(this.lines, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final line in lines) {
      if (line.isEmpty) continue;
      final path = Path()..moveTo(line.first.dx, line.first.dy);
      for (int i = 1; i < line.length; i++) {
        path.lineTo(line[i].dx, line[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePadPainter oldDelegate) => true;
}

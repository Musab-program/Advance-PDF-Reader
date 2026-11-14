import 'package:flutter/material.dart';

/// Available canvas preview contrast modes for cutout inspection.
enum PreviewBgMode {
  checkerboard,
  dark,
  light,
}

/// Paints the selected preview background (checkerboard, dark charcoal, or pure white).
void paintPreviewBackground(
  Canvas canvas,
  Size size,
  PreviewBgMode mode,
  bool isDark, {
  double cellSize = 14.0,
}) {
  switch (mode) {
    case PreviewBgMode.checkerboard:
      final color1 = isDark ? const Color(0xFF141722) : const Color(0xFFECEEF2);
      final color2 = isDark ? const Color(0xFF1B1F2F) : const Color(0xFFDDDDE5);

      final paint1 = Paint()..color = color1;
      final paint2 = Paint()..color = color2;

      final cols = (size.width / cellSize).ceil();
      final rows = (size.height / cellSize).ceil();

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final paint = (r + c) % 2 == 0 ? paint1 : paint2;
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
      break;
    case PreviewBgMode.dark:
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12131A));
      break;
    case PreviewBgMode.light:
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
      break;
  }
}

/// Reusable background widget that renders the active [PreviewBgMode].
class PreviewBackgroundCanvas extends StatelessWidget {
  final PreviewBgMode mode;
  final double cellSize;

  const PreviewBackgroundCanvas({
    super.key,
    required this.mode,
    this.cellSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _PreviewBgPainter(mode: mode, isDark: isDark, cellSize: cellSize),
      size: Size.infinite,
    );
  }
}

class _PreviewBgPainter extends CustomPainter {
  final PreviewBgMode mode;
  final bool isDark;
  final double cellSize;

  const _PreviewBgPainter({
    required this.mode,
    required this.isDark,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintPreviewBackground(canvas, size, mode, isDark, cellSize: cellSize);
  }

  @override
  bool shouldRepaint(covariant _PreviewBgPainter oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.isDark != isDark || oldDelegate.cellSize != cellSize;
}

/// Direct-selection dropdown menu button for choosing [PreviewBgMode] without cycling.
class PreviewBgMenuButton extends StatelessWidget {
  final PreviewBgMode currentMode;
  final ValueChanged<PreviewBgMode> onSelected;

  const PreviewBgMenuButton({
    super.key,
    required this.currentMode,
    required this.onSelected,
  });

  String _label(PreviewBgMode mode) {
    switch (mode) {
      case PreviewBgMode.checkerboard:
        return 'مربعات شفافة (شطرنج)';
      case PreviewBgMode.dark:
        return 'خلفية داكنة (أسود)';
      case PreviewBgMode.light:
        return 'خلفية فاتحة (أبيض)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return PopupMenuButton<PreviewBgMode>(
      tooltip: 'اختيار لون خلفية المعاينة',
      initialValue: currentMode,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 42),
      icon: _BgSwatchBadge(mode: currentMode, isDarkTheme: isDark, size: 22),
      itemBuilder: (ctx) => PreviewBgMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return PopupMenuItem<PreviewBgMode>(
          value: mode,
          child: Row(
            children: [
              _BgSwatchBadge(mode: mode, isDarkTheme: isDark, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _label(mode),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? primaryColor : null,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 18, color: primaryColor),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BgSwatchBadge extends StatelessWidget {
  final PreviewBgMode mode;
  final bool isDarkTheme;
  final double size;

  const _BgSwatchBadge({
    required this.mode,
    required this.isDarkTheme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDarkTheme ? Colors.white54 : Colors.black45,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.5),
        child: CustomPaint(
          painter: _PreviewBgPainter(
            mode: mode,
            isDark: isDarkTheme,
            cellSize: size / 3,
          ),
        ),
      ),
    );
  }
}

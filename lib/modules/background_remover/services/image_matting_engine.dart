import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class MattingResult {
  final img.Image resultImage;
  final int totalPixels;
  final int transparentPixels;

  MattingResult({
    required this.resultImage,
    required this.totalPixels,
    required this.transparentPixels,
  });

  double get transparencyRatio =>
      totalPixels > 0 ? (transparentPixels / totalPixels) : 0.0;
}

class ImageMattingEngine {
  /// Removes background based on corner/border sampling or a specified background color.
  /// Tolerance controls how aggressively similar colors are treated as background.
  /// SmoothEdge applies anti-aliasing to edge pixels to prevent harsh jagged lines.
  static MattingResult removeBackground({
    required img.Image original,
    double tolerance = 35.0,
    bool removeHoles = true,
    int? customBgR,
    int? customBgG,
    int? customBgB,
  }) {
    final w = original.width;
    final h = original.height;
    final result = img.Image(width: w, height: h, numChannels: 4);

    // Determine target background color
    int bgR, bgG, bgB;
    if (customBgR != null && customBgG != null && customBgB != null) {
      bgR = customBgR;
      bgG = customBgG;
      bgB = customBgB;
    } else {
      // Auto-sample four corners to find dominant background
      final p0 = original.getPixel(0, 0);
      final p1 = original.getPixel(w - 1, 0);
      final p2 = original.getPixel(0, h - 1);
      final p3 = original.getPixel(w - 1, h - 1);
      bgR = ((p0.r + p1.r + p2.r + p3.r) / 4).round();
      bgG = ((p0.g + p1.g + p2.g + p3.g) / 4).round();
      bgB = ((p0.b + p1.b + p2.b + p3.b) / 4).round();
    }

    final lower = max(5.0, tolerance - 15.0);
    final upper = tolerance + 15.0;

    int transparentCount = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = original.getPixel(x, y);

        // Euclidean color distance in RGB space
        final dr = (p.r - bgR).toDouble();
        final dg = (p.g - bgG).toDouble();
        final db = (p.b - bgB).toDouble();
        final dist = sqrt(dr * dr + dg * dg + db * db);

        int alpha;
        if (dist <= lower) {
          alpha = 0;
          transparentCount++;
        } else if (dist >= upper) {
          alpha = (p.a).round().clamp(0, 255);
        } else {
          // Smooth gradient interpolation for anti-aliased edge
          final ratio = (dist - lower) / (upper - lower);
          alpha = (ratio * 255).round().clamp(0, 255);
        }

        // Color defringing: de-contaminate background color from semi-transparent edge pixels
        int r = p.r.toInt();
        int g = p.g.toInt();
        int b = p.b.toInt();

        if (alpha > 0 && alpha < 255) {
          final aNorm = alpha / 255.0;
          r = (((r - bgR * (1 - aNorm)) / aNorm)).round().clamp(0, 255);
          g = (((g - bgG * (1 - aNorm)) / aNorm)).round().clamp(0, 255);
          b = (((b - bgB * (1 - aNorm)) / aNorm)).round().clamp(0, 255);
        }

        result.setPixelRgba(x, y, r, g, b, alpha);
      }
    }

    return MattingResult(
      resultImage: result,
      totalPixels: w * h,
      transparentPixels: transparentCount,
    );
  }

  /// Magic wand tap: removes contiguous or similar colors around a selected point (tapX, tapY)
  static void applyMagicWandTap({
    required img.Image targetImage,
    required img.Image originalImage,
    required int tapX,
    required int tapY,
    double tolerance = 35.0,
  }) {
    if (tapX < 0 || tapX >= targetImage.width || tapY < 0 || tapY >= targetImage.height) {
      return;
    }

    final pTarget = originalImage.getPixel(tapX, tapY);
    final targetR = pTarget.r.toInt();
    final targetG = pTarget.g.toInt();
    final targetB = pTarget.b.toInt();

    final w = targetImage.width;
    final h = targetImage.height;

    // Breadth-first flood fill to only remove the clicked region
    final visited = Uint8List(w * h);
    final queueX = <int>[tapX];
    final queueY = <int>[tapY];
    visited[tapY * w + tapX] = 1;

    while (queueX.isNotEmpty) {
      final cx = queueX.removeLast();
      final cy = queueY.removeLast();

      // Make transparent
      final pOrig = originalImage.getPixel(cx, cy);
      targetImage.setPixelRgba(cx, cy, pOrig.r, pOrig.g, pOrig.b, 0);

      // Check 4 neighbors
      final neighbors = [
        [cx + 1, cy],
        [cx - 1, cy],
        [cx, cy + 1],
        [cx, cy - 1],
      ];

      for (final n in neighbors) {
        final nx = n[0];
        final ny = n[1];
        if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
          final idx = ny * w + nx;
          if (visited[idx] == 0) {
            visited[idx] = 1;
            final np = originalImage.getPixel(nx, ny);
            final dist = sqrt(
              pow(np.r - targetR, 2) +
              pow(np.g - targetG, 2) +
              pow(np.b - targetB, 2),
            );
            if (dist <= tolerance) {
              queueX.add(nx);
              queueY.add(ny);
            }
          }
        }
      }
    }
  }

  /// Manual Brush / Eraser tool:
  /// isErase = true: clears pixels to transparent
  /// isErase = false: restores original pixels
  static void applyBrush({
    required img.Image targetImage,
    required img.Image originalImage,
    required int centerX,
    required int centerY,
    required int radius,
    required bool isErase,
  }) {
    final w = targetImage.width;
    final h = targetImage.height;
    final r2 = radius * radius;

    final minX = max(0, centerX - radius);
    final maxX = min(w - 1, centerX + radius);
    final minY = max(0, centerY - radius);
    final maxY = min(h - 1, centerY + radius);

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dx = x - centerX;
        final dy = y - centerY;
        if (dx * dx + dy * dy <= r2) {
          final pOrig = originalImage.getPixel(x, y);
          if (isErase) {
            targetImage.setPixelRgba(x, y, pOrig.r, pOrig.g, pOrig.b, 0);
          } else {
            targetImage.setPixelRgba(x, y, pOrig.r, pOrig.g, pOrig.b, 255);
          }
        }
      }
    }
  }
}

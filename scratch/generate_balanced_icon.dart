import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final jpg = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;

  // 1. Crop the symbol tightly
  // Exact bounds found: minX=148, maxX=591, minY=84, maxY=694
  // Let's add 15px padding for any subtle outer anti-aliasing / glow:
  final cropX = max(0, 148 - 15);
  final cropY = max(0, 84 - 15);
  final cropW = min(jpg.width - cropX, (591 - 148 + 1) + 30);
  final cropH = min(jpg.height - cropY, (694 - 84 + 1) + 30);

  final croppedRaw = img.copyCrop(jpg, x: cropX, y: cropY, width: cropW, height: cropH);
  print('Cropped symbol with glow: ${croppedRaw.width}x${croppedRaw.height}');

  // 2. Extract symbol to transparent RGBA
  // The background around the symbol in jpg has low green and low red.
  // Let's do a smooth alpha extraction for the foreground symbol
  final symbolFg = img.Image(width: croppedRaw.width, height: croppedRaw.height, numChannels: 4);
  for (int y = 0; y < croppedRaw.height; y++) {
    for (int x = 0; x < croppedRaw.width; x++) {
      final p = croppedRaw.getPixel(x, y);
      // Background has r<40, g<10, b<140. Symbol has bright/saturated colors.
      // Calculate symbolness
      double score = 0;
      if (p.g >= 14 || p.r >= 45 || (p.r + p.g + p.b > 220)) {
        score = 1.0;
      } else {
        // Soft transition around edges
        final diff = max(p.g - 7, max(p.r - 28, (p.r + p.g + p.b - 140) / 3));
        if (diff > 0) {
          score = (diff / 25.0).clamp(0.0, 1.0);
        }
      }

      int a = (score * 255).round().clamp(0, 255);
      symbolFg.setPixelRgba(x, y, p.r, p.g, p.b, a);
    }
  }

  // 3. Create high-resolution 1024x1024 canvas
  const canvasSize = 1024;
  final fullIcon = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  final fgIcon = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  final bgIcon = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);

  // Background gradient:
  // From deep black-navy at top-left/bottom (0,0,0 to 8,2,47) to rich royal purple at top-right (50, 12, 175)
  for (int y = 0; y < canvasSize; y++) {
    for (int x = 0; x < canvasSize; x++) {
      // Diagonal gradient matching original
      double tX = x / canvasSize;
      double tY = y / canvasSize;
      double t = (tX * 0.7 + (1.0 - tY) * 0.3).clamp(0.0, 1.0);

      // Interpolate between (4, 0, 25) and (45, 10, 150)
      int r = (4 + t * 41).round();
      int g = (0 + t * 10).round();
      int b = (25 + t * 125).round();

      bgIcon.setPixelRgba(x, y, r, g, b, 255);
      fullIcon.setPixelRgba(x, y, r, g, b, 255);
      fgIcon.setPixelRgba(x, y, 0, 0, 0, 0); // transparent fg
    }
  }

  // 4. Scale symbol so it fits comfortably:
  // Target height: ~55% of canvas (approx 560px out of 1024), leaving ~232px margin top & bottom!
  final targetH = 560;
  final scale = targetH / symbolFg.height;
  final targetW = (symbolFg.width * scale).round();

  final scaledSymbol = img.copyResize(symbolFg, width: targetW, height: targetH, interpolation: img.Interpolation.linear);
  print('Scaled symbol: ${scaledSymbol.width}x${scaledSymbol.height}');

  // 5. Center perfectly in 1024x1024
  final startX = (canvasSize - scaledSymbol.width) ~/ 2;
  final startY = (canvasSize - scaledSymbol.height) ~/ 2;
  print('Placing symbol at ($startX, $startY) with top/bottom margin=$startY px, left/right margin=$startX px');

  // Composite onto fullIcon and fgIcon
  img.compositeImage(fullIcon, scaledSymbol, dstX: startX, dstY: startY);
  img.compositeImage(fgIcon, scaledSymbol, dstX: startX, dstY: startY);

  // Save outputs
  final outDir = Directory('scratch/test_results/new_icon');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  File('${outDir.path}/new_flutter_launcher_icon.png').writeAsBytesSync(img.encodePng(fullIcon));
  File('${outDir.path}/new_flutter_launcher_icon_fg.png').writeAsBytesSync(img.encodePng(fgIcon));
  File('${outDir.path}/new_flutter_launcher_icon_bg.png').writeAsBytesSync(img.encodePng(bgIcon));

  print('Successfully generated new icon in ${outDir.path}');
}

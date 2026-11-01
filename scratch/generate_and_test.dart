import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final outDir = Directory('scratch/test_results');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  print('=== Generating Test Cases for Icons & Logos ===');

  // 1. Test Case 1: Thin Lines (1px-2px) & fine details
  final imgThin = img.Image(width: 400, height: 400);
  img.fill(imgThin, color: img.ColorRgb8(255, 255, 255)); // White background
  // Draw thin circles and lines
  final navy = img.ColorRgb8(20, 50, 140);
  img.drawCircle(imgThin, x: 200, y: 200, radius: 150, color: navy); // 1px border
  img.drawLine(imgThin, x1: 50, y1: 200, x2: 350, y2: 200, color: navy); // 1px horizontal
  img.drawLine(imgThin, x1: 200, y1: 50, x2: 200, y2: 350, color: navy); // 1px vertical
  // Diagonal fine lines
  img.drawLine(imgThin, x1: 94, y1: 94, x2: 306, y2: 306, color: navy);
  img.drawString(imgThin, 'LOGO TEXT', font: img.arial14, x: 160, y: 180, color: navy);
  File('${outDir.path}/case1_thin_lines_input.png').writeAsBytesSync(img.encodePng(imgThin));

  // 2. Test Case 2: Internal Voids & Sharp Corners (Padlock / Shield icon)
  final imgHoles = img.Image(width: 400, height: 400);
  img.fill(imgHoles, color: img.ColorRgb8(255, 255, 255));
  final purple = img.ColorRgb8(120, 30, 160);
  // Outer shield / lock body
  img.fillRect(imgHoles, x1: 120, y1: 180, x2: 280, y2: 320, color: purple);
  // Inner keyhole void (white)
  img.fillCircle(imgHoles, x: 200, y: 230, radius: 20, color: img.ColorRgb8(255, 255, 255));
  img.fillRect(imgHoles, x1: 195, y1: 230, x2: 205, y2: 275, color: img.ColorRgb8(255, 255, 255));
  // Lock shackle (curved arch with inner void)
  for (int r = 50; r <= 65; r++) {
    for (double a = pi; a <= 2 * pi; a += 0.01) {
      int x = (200 + r * cos(a)).round();
      int y = (180 + r * sin(a)).round();
      imgHoles.setPixel(x, y, purple);
    }
  }
  File('${outDir.path}/case2_internal_voids_input.png').writeAsBytesSync(img.encodePng(imgHoles));

  // 3. Test Case 3: Low Contrast (Pale silver icon on pure white background)
  final imgLowContrast = img.Image(width: 400, height: 400);
  img.fill(imgLowContrast, color: img.ColorRgb8(255, 255, 255)); // #FFFFFF
  final paleSilver = img.ColorRgb8(220, 225, 230); // Very close to white! (Diff ~25-30)
  img.fillCircle(imgLowContrast, x: 200, y: 200, radius: 100, color: paleSilver);
  final darkAccent = img.ColorRgb8(30, 30, 40);
  img.drawString(imgLowContrast, 'SILVER', font: img.arial14, x: 175, y: 193, color: darkAccent);
  File('${outDir.path}/case3_low_contrast_input.png').writeAsBytesSync(img.encodePng(imgLowContrast));

  print('Test inputs generated in ${outDir.path}');

  // Now run tests on each image:
  // Method A: Simulating 320x320 Downsampled AI segmentation
  // Method B: High-Precision Native-Resolution Edge & Color Matting
  for (int c = 1; c <= 3; c++) {
    final inputPath = '${outDir.path}/case${c}_' + (c == 1 ? 'thin_lines' : c == 2 ? 'internal_voids' : 'low_contrast') + '_input.png';
    final bytes = File(inputPath).readAsBytesSync();
    final original = img.decodePng(bytes)!;

    // Simulation A: Downsample to 320x320, apply thresholding, upsample back
    final aiResult = simulateAiSegmentation(original);
    File('${outDir.path}/case${c}_result_ai_downscaled.png').writeAsBytesSync(img.encodePng(aiResult));

    // Simulation B: Native Resolution Smart Matting with Inner Hole Detection & Defringing
    final nativeResult = nativePrecisionCutout(original);
    File('${outDir.path}/case${c}_result_native_precision.png').writeAsBytesSync(img.encodePng(nativeResult));

    // Measure quality metrics
    evaluateQuality(c, original, aiResult, nativeResult);
  }
}

img.Image simulateAiSegmentation(img.Image src) {
  // 1. Downscale to 320x320 (typical for U2-Net / MobileNet)
  final down = img.copyResize(src, width: 320, height: 320, interpolation: img.Interpolation.linear);
  
  // 2. Generate mask in downscaled space
  final maskDown = img.Image(width: 320, height: 320, numChannels: 1);
  for (int y = 0; y < 320; y++) {
    for (int x = 0; x < 320; x++) {
      final p = down.getPixel(x, y);
      // Diff from white (255, 255, 255)
      final diff = (255 - p.r) + (255 - p.g) + (255 - p.b);
      // AI sigmoid probability simulation
      final alpha = diff > 40 ? 255 : 0;
      maskDown.setPixelR(x, y, alpha);
    }
  }

  // 3. Upscale mask back to original resolution (400x400)
  final maskUp = img.copyResize(maskDown, width: src.width, height: src.height, interpolation: img.Interpolation.linear);

  // 4. Composite with original
  final result = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final a = maskUp.getPixel(x, y).r;
      result.setPixelRgba(x, y, p.r, p.g, p.b, a);
    }
  }
  return result;
}

img.Image nativePrecisionCutout(img.Image src) {
  final w = src.width;
  final h = src.height;
  final result = img.Image(width: w, height: h, numChannels: 4);

  // Assume background color sampled from corners:
  final bg = src.getPixel(0, 0);
  final bgR = bg.r;
  final bgG = bg.g;
  final bgB = bg.b;

  // 1. Color distance map at native resolution
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      // Euclidean distance in RGB
      final dr = (p.r - bgR).abs();
      final dg = (p.g - bgG).abs();
      final db = (p.b - bgB).abs();
      final dist = sqrt(dr * dr + dg * dg + db * db);

      // Smooth alpha transition to prevent jagged edges and eliminate halos
      int alpha;
      const lower = 15.0; // below this: 100% background (transparent)
      const upper = 45.0; // above this: 100% foreground (solid)

      if (dist <= lower) {
        alpha = 0;
      } else if (dist >= upper) {
        alpha = 255;
      } else {
        // Linear interpolation for smooth antialiased edges
        alpha = ((dist - lower) / (upper - lower) * 255).round().clamp(0, 255);
      }

      // Color defringing: adjust RGB to avoid white halo on semi-transparent pixels
      int r = p.r.toInt();
      int g = p.g.toInt();
      int b = p.b.toInt();
      if (alpha > 0 && alpha < 255) {
        final aNorm = alpha / 255.0;
        // Un-mix the background color
        r = (((r - bgR * (1 - aNorm)) / aNorm)).round().clamp(0, 255);
        g = (((g - bgG * (1 - aNorm)) / aNorm)).round().clamp(0, 255);
        b = (((b - bgB * (1 - aNorm)) / aNorm)).round().clamp(0, 255);
      }

      result.setPixelRgba(x, y, r, g, b, alpha);
    }
  }

  return result;
}

void evaluateQuality(int caseNum, img.Image original, img.Image ai, img.Image native) {
  print('--- Case $caseNum Evaluation ---');
  // Count intact thin lines / alpha statistics
  int aiTransparentCount = 0;
  int nativeTransparentCount = 0;
  int aiSemiCount = 0;
  int nativeSemiCount = 0;

  for (int y = 0; y < original.height; y++) {
    for (int x = 0; x < original.width; x++) {
      final aAi = ai.getPixel(x, y).a;
      final aNat = native.getPixel(x, y).a;
      if (aAi == 0) aiTransparentCount++;
      if (aNat == 0) nativeTransparentCount++;
      if (aAi > 0 && aAi < 255) aiSemiCount++;
      if (aNat > 0 && aNat < 255) nativeSemiCount++;
    }
  }

  print('AI Cutout: $aiTransparentCount transparent pixels, $aiSemiCount blurry/semi-transparent pixels');
  print('Native Cutout: $nativeTransparentCount transparent pixels, $nativeSemiCount anti-aliased edge pixels');
}

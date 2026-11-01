import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final outDir = Directory('scratch/test_results/real_icon');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final bytes = File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync();
  final original = img.decodeJpg(bytes)!;

  print('Original size: ${original.width}x${original.height}');
  File('${outDir.path}/real_icon_input.png').writeAsBytesSync(img.encodePng(original));

  // Run native color distance with single corner sampling (0,0)
  final singleCornerResult = removeBgSingleCorner(original, tolerance: 40);
  File('${outDir.path}/real_icon_single_corner_tol40.png').writeAsBytesSync(img.encodePng(singleCornerResult));

  // Run native with high tolerance (to try to catch gradient)
  final highTolResult = removeBgSingleCorner(original, tolerance: 120);
  File('${outDir.path}/real_icon_single_corner_tol120.png').writeAsBytesSync(img.encodePng(highTolResult));

  // Measure what happened
  int remTol40 = countTransparent(singleCornerResult);
  int remTol120 = countTransparent(highTolResult);
  int total = original.width * original.height;

  print('Total pixels: $total');
  print('Tolerance 40 transparent: $remTol40 (${(remTol40/total*100).toStringAsFixed(1)}%) -> Left half removed, right half gradient remained!');
  print('Tolerance 120 transparent: $remTol120 (${(remTol120/total*100).toStringAsFixed(1)}%) -> Background partially gone, but icon colors eroded!');
}

img.Image removeBgSingleCorner(img.Image src, {required double tolerance}) {
  final res = img.Image(width: src.width, height: src.height, numChannels: 4);
  final bg = src.getPixel(0, 0);
  final bgR = bg.r;
  final bgG = bg.g;
  final bgB = bg.b;

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final dist = sqrt(pow(p.r - bgR, 2) + pow(p.g - bgG, 2) + pow(p.b - bgB, 2));
      if (dist <= tolerance) {
        res.setPixelRgba(x, y, p.r, p.g, p.b, 0);
      } else {
        res.setPixelRgba(x, y, p.r, p.g, p.b, 255);
      }
    }
  }
  return res;
}

int countTransparent(img.Image img) {
  int count = 0;
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      if (img.getPixel(x, y).a == 0) count++;
    }
  }
  return count;
}

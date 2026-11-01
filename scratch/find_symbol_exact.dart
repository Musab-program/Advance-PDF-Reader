import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final jpg = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;
  print('Decoded jpg: ${jpg.width}x${jpg.height}');

  // Detect the boundary of the vibrant infinity symbol
  // Foreground is where brightness/saturation or color distance from background is high
  int minX = jpg.width, maxX = 0, minY = jpg.height, maxY = 0;
  for (int y = 0; y < jpg.height; y++) {
    for (int x = 0; x < jpg.width; x++) {
      final p = jpg.getPixel(x, y);
      // Brightness / vibrant color check:
      // Background has r < 30, g < 15, and b < 100 or r+g+b < 120
      final isVibrant = (p.r > 25 || p.g > 20 || p.b > 115) && (p.r + p.g + p.b > 130);
      if (isVibrant) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Detected Symbol Bounding Box: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');
  print('Width: ${maxX - minX + 1}, Height: ${maxY - minY + 1}');
}

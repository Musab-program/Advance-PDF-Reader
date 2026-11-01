import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final jpg = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;

  int minX = jpg.width, maxX = 0, minY = jpg.height, maxY = 0;
  for (int y = 0; y < jpg.height; y++) {
    for (int x = 0; x < jpg.width; x++) {
      final p = jpg.getPixel(x, y);
      // The infinity symbol is bright/saturated:
      // Background has g <= 9 throughout all corners and edges!
      // And background has r <= 41 everywhere!
      final isSymbol = (p.g >= 15 || p.r >= 48 || (p.r + p.g + p.b > 210));
      if (isSymbol) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('True Infinity Symbol Bounding Box in 759x759 image:');
  print('minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');
  print('Width: ${maxX - minX + 1}, Height: ${maxY - minY + 1}');
}

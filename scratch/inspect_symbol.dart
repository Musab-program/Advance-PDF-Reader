import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.decodePng(File('assets/images/flutter_launcher_icon.png').readAsBytesSync())!;
  // Check corner color
  final c00 = image.getPixel(0, 0);
  final cCenter = image.getPixel(512, 512);
  print('Corner (0,0): r=${c00.r}, g=${c00.g}, b=${c00.b}, a=${c00.a}');
  print('Center (512,512): r=${cCenter.r}, g=${cCenter.g}, b=${cCenter.b}, a=${cCenter.a}');

  // Find where the color differs significantly from the background
  // Sample background colors along edges
  int bgR = c00.r.toInt(), bgG = c00.g.toInt(), bgB = c00.b.toInt();
  int minX = 1024, maxX = 0, minY = 1024, maxY = 0;
  for (int y = 0; y < 1024; y++) {
    for (int x = 0; x < 1024; x++) {
      final p = image.getPixel(x, y);
      // Check if it's the symbol (usually colorful, red/cyan/purple or bright)
      // Background in pubspec is "#08022F" or similar dark
      final isBg = (p.r < 40 && p.g < 25 && p.b < 75);
      if (!isBg) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  print('Infinity symbol / foreground bounding box: X=[$minX, $maxX], Y=[$minY, $maxY] (width=${maxX-minX+1}, height=${maxY-minY+1})');
}

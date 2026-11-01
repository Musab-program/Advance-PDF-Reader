import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final splash = img.decodePng(File('assets/images/Splash Screen.png').readAsBytesSync())!;
  print('Splash: ${splash.width}x${splash.height}, hasAlpha=${splash.hasAlpha}');
  // Check bounds of non-transparent pixels
  int minX = splash.width, maxX = 0, minY = splash.height, maxY = 0;
  for (int y = 0; y < splash.height; y++) {
    for (int x = 0; x < splash.width; x++) {
      final a = splash.getPixel(x, y).a;
      if (a > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  print('Splash non-transparent: X=[$minX, $maxX], Y=[$minY, $maxY] (width=${maxX-minX+1}, height=${maxY-minY+1})');
}

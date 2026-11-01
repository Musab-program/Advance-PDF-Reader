import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;
  print('JPG: ${image.width}x${image.height}');
  int minX = 759, maxX = 0, minY = 759, maxY = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final isBg = (p.r < 40 && p.g < 25 && p.b < 75);
      if (!isBg) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  print('JPG foreground bounding box: X=[$minX, $maxX], Y=[$minY, $maxY] (width=${maxX-minX+1}, height=${maxY-minY+1})');
}

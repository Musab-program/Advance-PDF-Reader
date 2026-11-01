import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final name in [
    'assets/images/flutter_launcher_icon.png',
    'assets/images/flutter_launcher_icon_fg.png',
  ]) {
    final file = File(name);
    final image = img.decodePng(file.readAsBytesSync())!;
    int minX = image.width, maxX = 0, minY = image.height, maxY = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final a = image.getPixel(x, y).a;
        if (a > 10) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    print('$name non-transparent bounds: X=[$minX, $maxX], Y=[$minY, $maxY] (width=${maxX-minX+1}, height=${maxY-minY+1} out of ${image.width}x${image.height})');
  }
}

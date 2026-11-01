import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final jpg = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;
  // Let's sample along a horizontal line through the center (y = 379)
  for (int x = 0; x < 759; x += 25) {
    final p = jpg.getPixel(x, 379);
    print('x=$x, y=379: rgb=(${p.r}, ${p.g}, ${p.b})');
  }
}

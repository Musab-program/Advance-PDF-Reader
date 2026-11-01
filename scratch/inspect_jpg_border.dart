import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final jpg = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;
  print('Top edge (y=0):');
  for (int x = 0; x < jpg.width; x += 50) {
    print('x=$x, y=0: ${jpg.getPixel(x, 0)}');
  }
  print('Right edge (x=${jpg.width-1}):');
  for (int y = 0; y < jpg.height; y += 50) {
    print('x=${jpg.width-1}, y=$y: ${jpg.getPixel(jpg.width-1, y)}');
  }
}

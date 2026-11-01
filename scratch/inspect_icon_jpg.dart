import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync();
  final image = img.decodeJpg(bytes)!;
  print('Top-left (0,0): ${image.getPixel(0,0)}');
  print('Top-right (${image.width-1}, 0): ${image.getPixel(image.width-1, 0)}');
  print('Center (${image.width~/2}, ${image.height~/2}): ${image.getPixel(image.width~/2, image.height~/2)}');
}

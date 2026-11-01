import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final splash = img.decodePng(File('assets/images/Splash Screen.png').readAsBytesSync())!;
  print('Splash (0,0): ${splash.getPixel(0,0)}');
  print('Splash (365, 344): ${splash.getPixel(365, 344)}');
  print('Splash (100, 100): ${splash.getPixel(100, 100)}');
}

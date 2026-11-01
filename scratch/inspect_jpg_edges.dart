import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final jpg = img.decodeJpg(File('assets/images/flutter_launcher_icon.jpg').readAsBytesSync())!;
  // Check the corners and edges
  print('(0,0): ${jpg.getPixel(0,0)}');
  print('(758,0): ${jpg.getPixel(758,0)}');
  print('(0,758): ${jpg.getPixel(0,758)}');
  print('(758,758): ${jpg.getPixel(758,758)}');
  print('(379, 0) top edge: ${jpg.getPixel(379, 0)}');
  print('(379, 758) bottom edge: ${jpg.getPixel(379, 758)}');
  print('(0, 379) left edge: ${jpg.getPixel(0, 379)}');
  print('(758, 379) right edge: ${jpg.getPixel(758, 379)}');
}

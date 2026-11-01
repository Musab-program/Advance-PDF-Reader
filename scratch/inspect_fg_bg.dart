import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final fg = img.decodePng(File('assets/images/flutter_launcher_icon_fg.png').readAsBytesSync())!;
  final bg = img.decodePng(File('assets/images/flutter_launcher_icon_bg.png').readAsBytesSync())!;
  print('fg: ${fg.width}x${fg.height}, numChannels=${fg.numChannels}');
  print('bg: ${bg.width}x${bg.height}, numChannels=${bg.numChannels}');
  // Check center pixel of fg
  print('fg center: ${fg.getPixel(512, 512)}');
  print('bg center: ${bg.getPixel(512, 512)}');
}

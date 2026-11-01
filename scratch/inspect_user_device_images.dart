import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final path in ['scratch/logo_under_50kb.png', 'scratch/images.jpeg']) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes)!;
    print('$path: ${decoded.width}x${decoded.height}, channels=${decoded.numChannels}, hasAlpha=${decoded.hasAlpha}');
    print('  (0,0): ${decoded.getPixel(0,0)}');
    print('  center: ${decoded.getPixel(decoded.width~/2, decoded.height~/2)}');
  }
}

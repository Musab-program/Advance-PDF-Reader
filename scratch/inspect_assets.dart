import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final files = Directory('assets/images').listSync().whereType<File>().toList();
  for (final f in files) {
    try {
      final bytes = f.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        print('${f.path}: ${decoded.width}x${decoded.height}, channels=${decoded.numChannels}, hasAlpha=${decoded.hasAlpha}');
      }
    } catch (e) {
      print('${f.path}: error $e');
    }
  }
}

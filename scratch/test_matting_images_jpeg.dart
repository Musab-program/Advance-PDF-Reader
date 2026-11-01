import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:pdf_reader/modules/background_remover/services/image_matting_engine.dart';

void main() {
  final bytes = File('scratch/images.jpeg').readAsBytesSync();
  final decoded = img.decodeImage(bytes)!;
  final res = ImageMattingEngine.removeBackground(original: decoded, tolerance: 35);
  print('Result: total=${res.totalPixels}, transparent=${res.transparentPixels} (${(res.transparencyRatio*100).toStringAsFixed(1)}%)');
  File('scratch/images_jpeg_result.png').writeAsBytesSync(img.encodePng(res.resultImage));
}

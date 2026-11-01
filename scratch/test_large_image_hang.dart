import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:pdf_reader/modules/background_remover/services/image_matting_engine.dart';

void main() {
  print('Creating simulated 4000x3000 camera image...');
  final sw = Stopwatch()..start();
  // 4000x3000 = 12 million pixels!
  final image = img.Image(width: 4000, height: 3000);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  print('Created in ${sw.elapsedMilliseconds}ms');

  sw.reset();
  print('Running ImageMattingEngine.removeBackground on 12 million pixels...');
  final result = ImageMattingEngine.removeBackground(original: image, tolerance: 35);
  print('Finished in ${sw.elapsedMilliseconds}ms');

  sw.reset();
  print('Encoding 12 million pixels to PNG...');
  img.encodePng(result.resultImage);
  print('Encoded in ${sw.elapsedMilliseconds}ms');
}

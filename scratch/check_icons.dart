import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final name in [
    'assets/images/flutter_launcher_icon.png',
    'assets/images/flutter_launcher_icon.jpg',
    'assets/images/flutter_launcher_icon_fg.png',
    'assets/images/flutter_launcher_icon_bg.png',
  ]) {
    final file = File(name);
    if (!file.existsSync()) continue;
    final image = img.decodeImage(file.readAsBytesSync())!;
    print('$name: ${image.width}x${image.height}, channels=${image.numChannels}, hasAlpha=${image.hasAlpha}');
  }
}

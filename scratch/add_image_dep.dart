import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  var content = file.readAsStringSync();
  if (!content.contains('image:')) {
    content = content.replaceFirst(
      'url_launcher: ^6.3.1',
      'url_launcher: ^6.3.1\n  image: ^4.8.0',
    );
    file.writeAsStringSync(content);
    print('Added image: ^4.8.0 to pubspec.yaml');
  } else {
    print('image already in pubspec.yaml');
  }
}

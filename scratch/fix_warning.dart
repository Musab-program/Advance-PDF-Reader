import 'dart:io';

void main() {
  final file = File('lib/modules/home/views/home_view.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    '    final isDark = theme.brightness == Brightness.dark;\n',
    '',
  );
  file.writeAsStringSync(content);
  print('Fixed isDark warning');
}

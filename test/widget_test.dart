// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/main.dart';

void main() {
  testWidgets('App starts test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PdfReaderApp());
    
    // Simply check if the app starts without crashing
    expect(tester.takeException(), isNull);
  });
}

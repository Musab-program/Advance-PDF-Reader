// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/main.dart';

void main() {
  testWidgets('App starts test', (WidgetTester tester) async {
    // Initialize storage channel
    await GetStorage.init();
    
    // Inject required global services
    Get.put<StorageService>(StorageService());
    Get.put<ThemeController>(ThemeController());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const PdfReaderApp());
    
    // Simply check if the app starts without crashing
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:xml/xml.dart';
import 'package:pdf_reader/core/services/storage_service.dart';

class XmlReaderController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxString filePath = ''.obs;
  final RxString fileName = ''.obs;
  final RxString rawContent = ''.obs;
  final RxString formattedContent = ''.obs;
  final Rx<XmlDocument?> xmlDocument = Rx<XmlDocument?>(null);
  final RxBool hasParseError = false.obs;
  final RxString parseErrorMessage = ''.obs;
  final RxString viewMode = 'formatted'.obs; // 'formatted', 'tree', 'raw'
  final RxDouble fontSize = 14.0.obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      filePath.value = args['filePath'] ?? '';
      fileName.value = args['fileName'] ?? 'XML Document';
      _loadXml();
    }
  }

  Future<void> _loadXml() async {
    isLoading.value = true;
    hasParseError.value = false;
    parseErrorMessage.value = '';

    try {
      final file = File(filePath.value);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String text;
        try {
          text = utf8.decode(bytes);
        } catch (_) {
          text = latin1.decode(bytes);
        }
        rawContent.value = text;

        try {
          final doc = XmlDocument.parse(text);
          xmlDocument.value = doc;
          formattedContent.value = doc.toXmlString(pretty: true, indent: '  ');
        } catch (xmlError) {
          hasParseError.value = true;
          parseErrorMessage.value = xmlError.toString();
          viewMode.value = 'raw';
        }

        _storageService.addRecentFile(filePath.value, fileName.value);
        _storageService.savePageCount(filePath.value, 1);
        _storageService.saveProgress(filePath.value, 1.0);
      } else {
        rawContent.value = 'File not found.';
        hasParseError.value = true;
        viewMode.value = 'raw';
      }
    } catch (e) {
      rawContent.value = 'Error reading file: $e';
      hasParseError.value = true;
      viewMode.value = 'raw';
    } finally {
      isLoading.value = false;
    }
  }

  void setViewMode(String mode) {
    viewMode.value = mode;
  }

  void increaseFontSize() {
    if (fontSize.value < 28.0) {
      fontSize.value += 1.5;
    }
  }

  void decreaseFontSize() {
    if (fontSize.value > 10.0) {
      fontSize.value -= 1.5;
    }
  }
}

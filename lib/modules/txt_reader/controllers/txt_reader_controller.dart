// lib/modules/txt_reader/controllers/txt_reader_controller.dart
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:pdf_reader/core/services/storage_service.dart';

class TxtReaderController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxString filePath = ''.obs;
  final RxString fileName = ''.obs;
  final RxString textContent = ''.obs;
  final RxBool isLoading = true.obs;
  final RxDouble fontSize = 16.0.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      filePath.value = args['filePath'] ?? '';
      fileName.value = args['fileName'] ?? 'Text Document';
      _loadTextContent();
    }
  }

  Future<void> _loadTextContent() async {
    isLoading.value = true;
    try {
      final file = File(filePath.value);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        // Try UTF-8 first, fallback to Latin-1 if there are decoding errors
        try {
          textContent.value = utf8.decode(bytes);
        } catch (_) {
          textContent.value = latin1.decode(bytes);
        }

        // Add this file to recents list
        _storageService.addRecentFile(filePath.value, fileName.value);
        _storageService.savePageCount(filePath.value, 1); // 1 page for txt files
        _storageService.saveProgress(filePath.value, 1.0); // Marked as read
      } else {
        textContent.value = 'File not found.';
      }
    } catch (e) {
      textContent.value = 'Error reading file: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void increaseFontSize() {
    if (fontSize.value < 32.0) {
      fontSize.value += 2.0;
    }
  }

  void decreaseFontSize() {
    if (fontSize.value > 10.0) {
      fontSize.value -= 2.0;
    }
  }
}

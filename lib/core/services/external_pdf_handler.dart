// lib/core/services/external_pdf_handler.dart
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/routes/app_routes.dart';

/// Coordinates opening files received from external Android intents
/// (File Managers, WhatsApp, Telegram, Share sheet, etc.) in the single main window.
class ExternalPdfHandler {
  static String? _pendingFilePath;

  static bool get hasPendingFile =>
      _pendingFilePath != null && _pendingFilePath!.isNotEmpty;

  static void setPendingFile(String? path) {
    if (path != null && path.isNotEmpty) {
      _pendingFilePath = path;
    }
  }

  static String? peekPendingFile() => _pendingFilePath;

  static String? consumePendingFile() {
    final path = _pendingFilePath;
    _pendingFilePath = null;
    return path;
  }

  /// Opens [filePath] in the appropriate viewer based on extension.
  static void openPdf(String filePath) {
    if (filePath.isEmpty) return;

    final ext = p.extension(filePath).toUpperCase().replaceAll('.', '');
    final fileName = p.basename(filePath);

    if (ext != 'PDF') {
      _pendingFilePath = null;
      if (Get.currentRoute == Routes.SPLASH || Get.currentRoute.isEmpty) {
        Get.offAllNamed(Routes.HOME);
      }
      if (ext == 'DOCX' || ext == 'DOTX') {
        Get.toNamed(Routes.OFFICE_VIEWER, arguments: {
          'filePath': filePath,
          'fileName': fileName,
          'fileType': 'DOCX',
        });
      } else if (ext == 'XLSX' || ext == 'XLTX') {
        Get.toNamed(Routes.OFFICE_VIEWER, arguments: {
          'filePath': filePath,
          'fileName': fileName,
          'fileType': 'XLSX',
        });
      } else if (ext == 'PPTX' || ext == 'POTX') {
        Get.toNamed(Routes.OFFICE_VIEWER, arguments: {
          'filePath': filePath,
          'fileName': fileName,
          'fileType': 'PPTX',
        });
      } else if (ext == 'HTML' || ext == 'HTM') {
        Get.toNamed(Routes.HTML_READER, arguments: {
          'filePath': filePath,
          'fileName': fileName,
        });
      } else if (ext == 'XML') {
        Get.toNamed(Routes.XML_READER, arguments: {
          'filePath': filePath,
          'fileName': fileName,
        });
      } else if (ext == 'TXT') {
        Get.toNamed(Routes.TXT_READER, arguments: {
          'filePath': filePath,
          'fileName': fileName,
        });
      }
      return;
    }

    if (Get.isRegistered<ReaderController>()) {
      final readerCtrl = Get.find<ReaderController>();
      readerCtrl.loadFromFileFromIntent(filePath);
      if (Get.currentRoute != Routes.READER) {
        Get.until((route) => Get.currentRoute == Routes.READER || route.isFirst);
        if (Get.currentRoute != Routes.READER) {
          setPendingFile(filePath);
          Get.toNamed(Routes.READER, arguments: {'singleFile': filePath});
        }
      }
      return;
    }

    setPendingFile(filePath);
    if (Get.currentRoute == Routes.SPLASH || Get.currentRoute.isEmpty) {
      Get.offAllNamed(Routes.HOME);
    }
    Get.toNamed(Routes.READER, arguments: {'singleFile': filePath});
  }
}

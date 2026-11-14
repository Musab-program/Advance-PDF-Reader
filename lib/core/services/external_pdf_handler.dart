// lib/core/services/external_pdf_handler.dart
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/core/services/external_office_handler.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/routes/app_routes.dart';

/// Coordinates opening PDF files received from external Android intents
/// (File Managers, WhatsApp, Telegram, Share sheet, etc.) in the single main window.
class ExternalPdfHandler {
  static String? _pendingFilePath;
  static bool isResolvingExternalFile = false;

  static bool get hasPendingFile =>
      _pendingFilePath != null && _pendingFilePath!.isNotEmpty;

  static void setPendingFile(String? path) {
    if (path == '__RESOLVING__') {
      isResolvingExternalFile = true;
      return;
    }
    if (path != null && path.isNotEmpty) {
      isResolvingExternalFile = false;
      _pendingFilePath = path;
    }
  }

  static String? peekPendingFile() => _pendingFilePath;

  static String? consumePendingFile() {
    final path = _pendingFilePath;
    _pendingFilePath = null;
    return path;
  }

  /// Opens [filePath] in the PDF Reader (or forwards if it is an Office/Text file).
  static void openPdf(String filePath) {
    isResolvingExternalFile = false;
    if (filePath.isEmpty) return;

    // If GetMaterialApp navigator is not mounted yet, store as pending for SplashView
    if (Get.key.currentState == null) {
      setPendingFile(filePath);
      return;
    }

    final ext = p.extension(filePath).toUpperCase().replaceAll('.', '');
    final fileName = p.basename(filePath);

    if (ExternalOfficeHandler.isOfficeExtension(ext)) {
      _pendingFilePath = null;
      ExternalOfficeHandler.openOfficeDocument(filePath);
      return;
    }

    if (ext == 'HTML' || ext == 'HTM') {
      _pendingFilePath = null;
      if (Get.currentRoute == Routes.SPLASH || Get.currentRoute.isEmpty) {
        Get.offAllNamed(Routes.HOME);
      }
      Get.toNamed(Routes.HTML_READER, arguments: {
        'filePath': filePath,
        'fileName': fileName,
      });
      return;
    } else if (ext == 'XML') {
      _pendingFilePath = null;
      if (Get.currentRoute == Routes.SPLASH || Get.currentRoute.isEmpty) {
        Get.offAllNamed(Routes.HOME);
      }
      Get.toNamed(Routes.XML_READER, arguments: {
        'filePath': filePath,
        'fileName': fileName,
      });
      return;
    } else if (ext == 'TXT') {
      _pendingFilePath = null;
      if (Get.currentRoute == Routes.SPLASH || Get.currentRoute.isEmpty) {
        Get.offAllNamed(Routes.HOME);
      }
      Get.toNamed(Routes.TXT_READER, arguments: {
        'filePath': filePath,
        'fileName': fileName,
      });
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

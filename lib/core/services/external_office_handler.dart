// lib/core/services/external_office_handler.dart
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/modules/office_viewer/controllers/office_viewer_controller.dart';
import 'package:pdf_reader/routes/app_routes.dart';

/// Dedicated handler for opening Office documents (Word, Excel, PowerPoint, CSV, WPS)
/// received from File Managers, WhatsApp, Telegram, and Share sheets.
/// Completely separated from the PDF opening pipeline (`ExternalPdfHandler`).
class ExternalOfficeHandler {
  static const MethodChannel _officeChannel =
      MethodChannel('com.example.pdf_reader/office_intent');

  static String? _pendingOfficePath;

  static bool get hasPendingOfficeFile =>
      _pendingOfficePath != null && _pendingOfficePath!.isNotEmpty;

  static void setPendingOfficeFile(String? path) {
    if (path != null && path.isNotEmpty) {
      _pendingOfficePath = path;
    }
  }

  static String? peekPendingOfficeFile() => _pendingOfficePath;

  static String? consumePendingOfficeFile() {
    final path = _pendingOfficePath;
    _pendingOfficePath = null;
    return path;
  }

  /// Queries Android MainActivity for any initial Office document on cold start.
  static Future<void> checkInitialOfficeIntent() async {
    try {
      final initialPath =
          await _officeChannel.invokeMethod<String>('getInitialOfficePath');
      if (initialPath != null && initialPath.isNotEmpty) {
        setPendingOfficeFile(initialPath);
      }
    } catch (_) {}
  }

  /// Listens for live `onOpenOfficeFile` intents when the app is already running.
  static void registerLiveOfficeIntentListener() {
    _officeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenOfficeFile') {
        final String? newPath = call.arguments as String?;
        if (newPath != null && newPath.isNotEmpty) {
          openOfficeDocument(newPath);
        }
      }
    });
  }

  /// Resolves the Office format category ('DOCX', 'DOC', 'XLSX', 'XLS', 'CSV', 'PPTX', 'PPT')
  static String resolveOfficeFormatType(String extensionStr) {
    final ext = extensionStr.toUpperCase().replaceAll('.', '');
    switch (ext) {
      case 'DOCX':
      case 'DOTX':
      case 'DOCM':
        return 'DOCX';
      case 'DOC':
      case 'DOT':
      case 'WPS':
      case 'WPT':
      case 'RTF':
        return 'DOC';
      case 'XLSX':
      case 'XLTX':
      case 'XLSM':
        return 'XLSX';
      case 'XLS':
      case 'XLT':
      case 'ET':
      case 'ETT':
        return 'XLS';
      case 'CSV':
        return 'CSV';
      case 'PPTX':
      case 'POTX':
      case 'PPSX':
      case 'PPTM':
        return 'PPTX';
      case 'PPT':
      case 'POT':
      case 'PPS':
      case 'DPS':
      case 'DPT':
        return 'PPT';
      default:
        return 'DOCX';
    }
  }

  static bool isOfficeExtension(String extensionStr) {
    final ext = extensionStr.toUpperCase().replaceAll('.', '');
    const officeExts = {
      'DOCX', 'DOTX', 'DOCM', 'DOC', 'DOT', 'WPS', 'WPT', 'RTF',
      'XLSX', 'XLTX', 'XLSM', 'XLS', 'XLT', 'ET', 'ETT', 'CSV',
      'PPTX', 'POTX', 'PPSX', 'PPTM', 'PPT', 'POT', 'PPS', 'DPS', 'DPT',
    };
    return officeExts.contains(ext);
  }

  /// Opens [filePath] in the dedicated Office Viewer module.
  static void openOfficeDocument(String filePath) {
    if (filePath.isEmpty) return;

    _pendingOfficePath = null;
    final ext = p.extension(filePath).toUpperCase().replaceAll('.', '');
    final fileName = p.basenameWithoutExtension(filePath);
    final officeType = resolveOfficeFormatType(ext);

    // If OfficeViewerController is already active on screen, switch the file immediately
    if (Get.isRegistered<OfficeViewerController>() &&
        Get.currentRoute == Routes.OFFICE_VIEWER) {
      final ctrl = Get.find<OfficeViewerController>();
      ctrl.loadExternalOfficeFile(
        newPath: filePath,
        newName: fileName.isNotEmpty ? fileName : p.basename(filePath),
        newType: officeType,
      );
      return;
    }

    if (Get.currentRoute == Routes.SPLASH || Get.currentRoute.isEmpty) {
      Get.offAllNamed(Routes.HOME);
    }

    Get.toNamed(Routes.OFFICE_VIEWER, arguments: {
      'filePath': filePath,
      'fileName': fileName.isNotEmpty ? fileName : p.basename(filePath),
      'fileType': officeType,
    });
  }
}

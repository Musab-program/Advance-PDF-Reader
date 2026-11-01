import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf_reader/core/services/storage_service.dart';

class HtmlReaderController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxString filePath = ''.obs;
  final RxString fileName = ''.obs;
  final RxString htmlContent = ''.obs;
  final RxBool isLoading = true.obs;
  final RxBool isPreview = false.obs; // False by default: user must choose to run/preview
  final RxBool isLoadingPreview = false.obs;
  final RxBool hasPreviewError = false.obs;
  final RxString previewErrorMessage = ''.obs;
  final RxDouble fontSize = 15.0.obs;

  WebViewController? webViewController;
  Timer? _previewTimeoutTimer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      filePath.value = args['filePath'] ?? '';
      fileName.value = args['fileName'] ?? 'HTML Document';
      _loadContent();
    }
  }

  @override
  void onClose() {
    _previewTimeoutTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadContent() async {
    isLoading.value = true;
    try {
      final file = File(filePath.value);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        try {
          htmlContent.value = utf8.decode(bytes);
        } catch (_) {
          htmlContent.value = latin1.decode(bytes);
        }

        _storageService.addRecentFile(filePath.value, fileName.value);
        _storageService.savePageCount(filePath.value, 1);
        _storageService.saveProgress(filePath.value, 1.0);
      } else {
        htmlContent.value = 'File not found.';
      }
    } catch (e) {
      htmlContent.value = 'Error reading file: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void togglePreview() {
    if (!isPreview.value) {
      isPreview.value = true;
      loadPreview();
    } else {
      _previewTimeoutTimer?.cancel();
      isPreview.value = false;
    }
  }

  void loadPreview() {
    isLoadingPreview.value = true;
    hasPreviewError.value = false;
    previewErrorMessage.value = '';

    try {
      final file = File(filePath.value);
      if (!file.existsSync()) {
        hasPreviewError.value = true;
        previewErrorMessage.value = 'الملف غير موجود';
        isLoadingPreview.value = false;
        return;
      }

      final fileDir = p.dirname(file.absolute.path);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              isLoadingPreview.value = true;
            },
            onPageFinished: (String url) {
              _previewTimeoutTimer?.cancel();
              isLoadingPreview.value = false;
            },
            onWebResourceError: (WebResourceError error) {
              // Non-fatal resource loading issue
            },
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url;
              // 1. Strictly block any external web/cloud URLs
              if (url.startsWith('http://') || url.startsWith('https://')) {
                return NavigationDecision.prevent;
              }
              // 2. Allow local files ONLY if they reside within the HTML file's directory
              if (url.startsWith('file://')) {
                try {
                  final reqPath = Uri.parse(url).toFilePath();
                  if (reqPath == file.absolute.path || p.isWithin(fileDir, reqPath)) {
                    return NavigationDecision.navigate;
                  }
                } catch (_) {}
                return NavigationDecision.prevent;
              }
              // 3. Allow about:blank or data: URIs
              if (url.startsWith('about:') || url.startsWith('data:')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        );

      // 8-second safety timeout so the UI never hangs indefinitely
      _previewTimeoutTimer?.cancel();
      _previewTimeoutTimer = Timer(const Duration(seconds: 8), () {
        if (isLoadingPreview.value) {
          isLoadingPreview.value = false;
        }
      });

      // Load file directly to support local relative CSS, JS, and image assets in the same directory
      controller.loadFile(file.absolute.path);
      webViewController = controller;
    } catch (e) {
      hasPreviewError.value = true;
      previewErrorMessage.value = 'تعذر تشغيل المعاينة: $e';
      isLoadingPreview.value = false;
    }
  }

  void increaseFontSize() {
    if (fontSize.value < 30.0) {
      fontSize.value += 2.0;
    }
  }

  void decreaseFontSize() {
    if (fontSize.value > 10.0) {
      fontSize.value -= 2.0;
    }
  }
}

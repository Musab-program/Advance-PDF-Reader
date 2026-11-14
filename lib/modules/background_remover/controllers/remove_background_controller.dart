import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_toast.dart';
import '../services/hugging_face_bg_remover_service.dart';
import '../widgets/preview_background_selector.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

class RemoveBackgroundController extends GetxController with WidgetsBindingObserver {
  final StorageService _storageService = Get.find<StorageService>();

  final RxBool isLoading = false.obs;
  final RxBool isProcessing = false.obs;
  final RxBool isOffline = false.obs;
  final RxString selectedImagePath = ''.obs;

  final Rx<Uint8List?> originalBytes = Rx<Uint8List?>(null);
  final Rx<Uint8List?> processedBytes = Rx<Uint8List?>(null);

  final RxBool showOriginal = false.obs;
  final Rx<PreviewBgMode> previewBgMode = PreviewBgMode.checkerboard.obs;
  final RxString statusMessage = ''.obs;
  final RxString errorMessage = ''.obs;
  final RxDouble processingProgress = 0.0.obs;

  static const MethodChannel _platformChannel =
      MethodChannel('com.example.pdf_reader/content_resolver');

  int _runId = 0;
  bool _isCancelled = false;
  bool _isAppPaused = false;
  bool _needsRestartOnResume = false;
  Timer? _watchdogTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    checkConnectivity(showSnackbarIfOffline: false);
  }

  @override
  void onClose() {
    _watchdogTimer?.cancel();
    HuggingFaceBgRemoverService.abortActiveRequest();
    _setNativeKeepAlive(false);
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> _setNativeKeepAlive(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      await _platformChannel.invokeMethod('setProcessingKeepAlive', {'enable': enable});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _isAppPaused = true;
    } else if (state == AppLifecycleState.resumed) {
      _isAppPaused = false;
      if (_needsRestartOnResume &&
          !_isCancelled &&
          originalBytes.value != null &&
          processedBytes.value == null) {
        _needsRestartOnResume = false;
        applyAiMatting();
      } else if (_needsRestartOnResume) {
        _needsRestartOnResume = false;
        isProcessing.value = false;
        isLoading.value = false;
      } else if (isOffline.value) {
        checkConnectivity(showSnackbarIfOffline: false);
      }
    }
  }

  Future<bool> checkConnectivity({bool showSnackbarIfOffline = false}) async {
    final connected = await HuggingFaceBgRemoverService.hasInternetConnection();
    isOffline.value = !connected;
    if (!connected && showSnackbarIfOffline) {
      AppToast.showWarning('يرجى الاتصال بالإنترنت للمتابعة');
    }
    return connected;
  }

  void cancelOperation() {
    _runId++;
    _isCancelled = true;
    _needsRestartOnResume = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    HuggingFaceBgRemoverService.abortActiveRequest();
    _setNativeKeepAlive(false);
    isProcessing.value = false;
    isLoading.value = false;
    statusMessage.value = 'cancel'.tr;
  }

  Future<void> pickImage() async {
    final connected = await checkConnectivity(showSnackbarIfOffline: false);
    if (!connected) return;

    try {
      _isCancelled = false;
      _needsRestartOnResume = false;
      errorMessage.value = '';
      statusMessage.value = 'opening_gallery'.tr;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (_isCancelled) return;

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;
      Uint8List? bytes = pickedFile.bytes;

      if (bytes == null && pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        final f = File(pickedFile.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        errorMessage.value = 'failed_to_load_image'.tr;
        return;
      }

      selectedImagePath.value = pickedFile.path ?? pickedFile.name;
      originalBytes.value = bytes;
      processedBytes.value = null;
      showOriginal.value = false;

      // Start processing immediately with scanner animation
      await applyAiMatting();
    } catch (e) {
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> applyAiMatting() async {
    if (originalBytes.value == null) {
      isProcessing.value = false;
      isLoading.value = false;
      return;
    }

    _needsRestartOnResume = false;
    final connected = await checkConnectivity(showSnackbarIfOffline: false);
    if (!connected) {
      isProcessing.value = false;
      isLoading.value = false;
      return;
    }

    final int myRunId = ++_runId;
    _isCancelled = false;
    isLoading.value = true;
    isProcessing.value = true;
    errorMessage.value = '';
    processingProgress.value = 0.15;
    statusMessage.value = 'جاري المعالجة...';

    _watchdogTimer?.cancel();
    await _setNativeKeepAlive(true);
    _watchdogTimer = Timer(const Duration(seconds: 38), () {
      if (myRunId == _runId && isLoading.value) {
        _runId++;
        _needsRestartOnResume = false;
        HuggingFaceBgRemoverService.abortActiveRequest();
        _setNativeKeepAlive(false);
        isProcessing.value = false;
        isLoading.value = false;
        errorMessage.value = 'استغرقت المعالجة وقتاً طويلاً، يرجى المحاولة مرة أخرى';
        AppToast.showError(errorMessage.value);
      }
    });

    try {
      final token = _storageService.getHuggingFaceToken();
      final pngBytes = await HuggingFaceBgRemoverService.removeBackground(
        originalBytes.value!,
        token: token,
        onProgress: (progress, status) {
          if (!_isCancelled && myRunId == _runId) {
            processingProgress.value = progress;
            statusMessage.value = status;
          }
        },
      );

      if (_isCancelled || myRunId != _runId) return;

      processedBytes.value = pngBytes;
      showOriginal.value = false;
      processingProgress.value = 1.0;
      statusMessage.value = 'تم بنجاح';
    } on OperationCancelledException {
      return;
    } on NoInternetException catch (e) {
      if (myRunId != _runId) return;
      isOffline.value = true;
      errorMessage.value = e.message;
    } catch (e) {
      if (_isCancelled || myRunId != _runId) return;
      if (_isAppPaused) {
        // OS throttled/dropped the connection while in background: pause timer & keep-alive
        // and cleanly restart the job the instant the user returns to foreground.
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        _setNativeKeepAlive(false);
        _needsRestartOnResume = true;
        return;
      }
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
      AppToast.showError(errorMessage.value);
    } finally {
      if (myRunId == _runId && !_needsRestartOnResume) {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        _setNativeKeepAlive(false);
        isProcessing.value = false;
        isLoading.value = false;
      }
    }
  }

  Future<void> savePng() async {
    final bytes = processedBytes.value;
    if (bytes == null || bytes.isEmpty) return;

    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        final picturesDir = Directory('/storage/emulated/0/Pictures/PdfReader');
        try {
          if (!picturesDir.existsSync()) {
            picturesDir.createSync(recursive: true);
          }
          targetDir = picturesDir;
        } catch (_) {
          final fallbackPictures = Directory('/storage/emulated/0/Pictures');
          if (fallbackPictures.existsSync()) {
            targetDir = fallbackPictures;
          }
        }
      }

      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final origBase = selectedImagePath.value.isNotEmpty
          ? p.basenameWithoutExtension(selectedImagePath.value)
          : 'cutout';
      final suggestedName = '${origBase}_nobg';
      String? chosenBaseName = suggestedName;

      final ctx = Get.context;
      if (ctx != null && ctx.mounted) {
        final nameCtrl = TextEditingController(text: suggestedName);
        String? errorText;
        chosenBaseName = await LuxuryDialog.showCustom<String>(
          ctx,
          builder: (dCtx) => StatefulBuilder(
            builder: (dCtx, setDialogState) => LuxuryDialog(
              compact: true,
              icon: Icons.save_alt_rounded,
              title: 'اسم الصورة المحفوظة',
              body: TextField(
                controller: nameCtrl,
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
                decoration: InputDecoration(
                  labelText: 'file_name'.tr,
                  suffixText: '.png',
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              secondaryButtonText: 'إلغاء',
              onSecondaryPressed: () {},
              primaryButtonText: 'حفظ',
              primaryButtonIcon: Icons.check_rounded,
              closeOnPrimary: false,
              onPrimaryPressed: () {
                final v = nameCtrl.text.trim();
                if (v.isEmpty) {
                  setDialogState(() => errorText = 'يرجى إدخال اسم الصورة أولاً');
                  return;
                }
                Navigator.of(dCtx).pop(v);
              },
            ),
          ),
        );
        if (chosenBaseName == null || chosenBaseName.trim().isEmpty) {
          return;
        }
      }

      final sanitized = chosenBaseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      var savePath = p.join(targetDir.path, '$sanitized.png');
      int counter = 1;
      while (File(savePath).existsSync()) {
        savePath = p.join(targetDir.path, '${sanitized}_$counter.png');
        counter++;
      }

      final file = File(savePath);
      await file.writeAsBytes(bytes, flush: true);

      // Instantly notify Android MediaStore so it appears in Gallery immediately
      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.example.pdf_reader/content_resolver');
          await platform.invokeMethod('scanMediaFile', {'filePath': savePath});
        } catch (e) {
          debugPrint('MediaScanner scan error: $e');
        }
      }

      // Elegant top-centered compact toast
      AppToast.showSuccess('تم الحفظ في المعرض');
    } catch (e) {
      AppToast.showError('فشل حفظ الصورة: $e');
    }
  }

  Future<void> shareResult() async {
    if (processedBytes.value == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cutout_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(processedBytes.value!);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Image with background removed',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
    } catch (e) {
      AppToast.showError('فشلت المشاركة: $e');
    }
  }
}

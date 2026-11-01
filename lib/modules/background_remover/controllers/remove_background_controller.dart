import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/image_matting_engine.dart';

enum TouchTool { none, wand, eraser, restore }

class RemoveBackgroundController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString selectedImagePath = ''.obs;

  img.Image? _rawOriginal;
  img.Image? _rawProcessed;

  final Rx<Uint8List?> originalBytes = Rx<Uint8List?>(null);
  final Rx<Uint8List?> processedBytes = Rx<Uint8List?>(null);

  final RxDouble tolerance = 35.0.obs;
  final Rx<TouchTool> currentTool = TouchTool.none.obs;
  final RxDouble brushRadius = 25.0.obs;
  final RxBool showOriginal = false.obs;
  final RxString statusMessage = ''.obs;
  final RxString errorMessage = ''.obs;
  final RxDouble processingProgress = 0.0.obs;

  bool _isCancelled = false;

  @override
  void onInit() {
    super.onInit();
    debounce(tolerance, (_) {
      if (_rawOriginal != null && !isProcessing.value) {
        applyMatting();
      }
    }, time: const Duration(milliseconds: 300));
  }

  void cancelOperation() {
    _isCancelled = true;
    isProcessing.value = false;
    isLoading.value = false;
    statusMessage.value = 'cancel'.tr;
  }

  Future<void> pickImage() async {
    try {
      _isCancelled = false;
      errorMessage.value = '';
      isLoading.value = true;
      statusMessage.value = 'opening_gallery'.tr;

      // Pick image using withData: true to directly read bytes from stream (works in offline/airplane mode)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (_isCancelled) return;

      if (result == null || result.files.isEmpty) {
        isLoading.value = false;
        return;
      }

      final pickedFile = result.files.single;
      Uint8List? bytes = pickedFile.bytes;

      // Fallback: If bytes were not directly loaded by the picker, read from path
      if (bytes == null && pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        final f = File(pickedFile.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        errorMessage.value = 'failed_to_load_image'.tr;
        isLoading.value = false;
        return;
      }

      selectedImagePath.value = pickedFile.path ?? pickedFile.name;
      originalBytes.value = bytes;

      statusMessage.value = 'processing_image'.tr;
      processingProgress.value = 0.2;

      // Decode and optimize resolution in isolate
      final decoded = await compute(_decodeAndOptimizeIsolate, bytes);
      if (_isCancelled) return;

      if (decoded != null) {
        _rawOriginal = decoded;
        processingProgress.value = 0.5;
        await applyMatting();
      } else {
        errorMessage.value = 'failed_to_load_image'.tr;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> applyMatting() async {
    if (_rawOriginal == null) return;
    try {
      _isCancelled = false;
      isProcessing.value = true;
      errorMessage.value = '';
      processingProgress.value = 0.6;
      statusMessage.value = 'processing_image'.tr;

      final tol = tolerance.value;
      final orig = _rawOriginal!;

      final result = await compute(_runMattingIsolate, {
        'image': orig,
        'tolerance': tol,
      });

      if (_isCancelled) return;

      _rawProcessed = result.resultImage;
      processingProgress.value = 0.85;

      final encodedBytes = await compute(_encodePngIsolate, _rawProcessed!);
      if (_isCancelled) return;

      processedBytes.value = encodedBytes;
      processingProgress.value = 1.0;
      statusMessage.value = '${(result.transparencyRatio * 100).toInt()}% background cleared';
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isProcessing.value = false;
    }
  }

  void handleCanvasTap(double relX, double relY) {
    if (_rawProcessed == null || _rawOriginal == null) return;
    final w = _rawProcessed!.width;
    final h = _rawProcessed!.height;
    final px = (relX * w).round().clamp(0, w - 1);
    final py = (relY * h).round().clamp(0, h - 1);

    switch (currentTool.value) {
      case TouchTool.wand:
        ImageMattingEngine.applyMagicWandTap(
          targetImage: _rawProcessed!,
          originalImage: _rawOriginal!,
          tapX: px,
          tapY: py,
          tolerance: tolerance.value,
        );
        _refreshProcessedBytes();
        break;
      case TouchTool.eraser:
        ImageMattingEngine.applyBrush(
          targetImage: _rawProcessed!,
          originalImage: _rawOriginal!,
          centerX: px,
          centerY: py,
          radius: brushRadius.value.round(),
          isErase: true,
        );
        _refreshProcessedBytes();
        break;
      case TouchTool.restore:
        ImageMattingEngine.applyBrush(
          targetImage: _rawProcessed!,
          originalImage: _rawOriginal!,
          centerX: px,
          centerY: py,
          radius: brushRadius.value.round(),
          isErase: false,
        );
        _refreshProcessedBytes();
        break;
      case TouchTool.none:
        break;
    }
  }

  void handleCanvasPan(double relX, double relY) {
    if (currentTool.value == TouchTool.none || currentTool.value == TouchTool.wand) {
      return;
    }
    handleCanvasTap(relX, relY);
  }

  Future<void> _refreshProcessedBytes() async {
    if (_rawProcessed == null) return;
    final encoded = await compute(_encodePngIsolate, _rawProcessed!);
    processedBytes.value = encoded;
  }

  Future<void> savePng() async {
    if (processedBytes.value == null) return;
    try {
      isLoading.value = true;
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      dir ??= await getTemporaryDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final origBase = selectedImagePath.value.isNotEmpty
          ? p.basenameWithoutExtension(selectedImagePath.value)
          : 'image';
      final fileName = '${origBase}_nobg_$timestamp.png';
      final savePath = p.join(dir.path, fileName);

      final file = File(savePath);
      await file.writeAsBytes(processedBytes.value!);

      Get.snackbar(
        'success'.tr,
        'File saved: $fileName',
        mainButton: TextButton(
          onPressed: () {
            OpenFilex.open(savePath);
          },
          child: Text('open'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar('error'.tr, 'Failed to save: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> shareResult() async {
    if (processedBytes.value == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cutout_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(processedBytes.value!);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Image with background removed');
    } catch (e) {
      Get.snackbar('error'.tr, 'Failed to share: $e');
    }
  }
}

// ── Isolates ──
img.Image? _decodeAndOptimizeIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Max dimension 1400px: preserves 100% fine lines for logos, but ensures fast 100-200ms processing
  const maxDim = 1400;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    final double scale = maxDim / max(decoded.width, decoded.height);
    return img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }
  return decoded;
}

MattingResult _runMattingIsolate(Map<String, dynamic> params) {
  final img.Image image = params['image'];
  final double tol = params['tolerance'];
  return ImageMattingEngine.removeBackground(
    original: image,
    tolerance: tol,
  );
}

Uint8List _encodePngIsolate(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;
import '../../../core/utils/pdf_text_layout.dart';
import '../models/tool_task_result.dart';

class PdfToolsService {
  static final PdfToolsService _instance = PdfToolsService._internal();
  factory PdfToolsService() => _instance;
  PdfToolsService._internal();

  /// Resolve a safe user-accessible output directory
  Future<Directory> getOutputDir({String subFolder = 'Aura_PDF_Tools'}) async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        baseDir = downloadDir;
      } else {
        baseDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux) {
      baseDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    baseDir ??= await getApplicationDocumentsDirectory();

    final targetDir = Directory(p.join(baseDir.path, subFolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Ensure safe non-colliding file path
  String generateSafeFilePath(Directory dir, String baseName, String extension) {
    var sanitized = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) sanitized = 'document';

    final ext = extension.startsWith('.') ? extension : '.$extension';
    var candidate = p.join(dir.path, '$sanitized$ext');
    int counter = 1;

    while (File(candidate).existsSync()) {
      candidate = p.join(dir.path, '${sanitized}_$counter$ext');
      counter++;
    }
    return candidate;
  }

  /// Convert rotation enum into turns (0, 1: 90°, 2: 180°, 3: 270°)
  static int getRotationTurns(PdfPageRotateAngle angle) {
    switch (angle) {
      case PdfPageRotateAngle.rotateAngle90:
        return 1;
      case PdfPageRotateAngle.rotateAngle180:
        return 2;
      case PdfPageRotateAngle.rotateAngle270:
        return 3;
      case PdfPageRotateAngle.rotateAngle0:
        return 0;
    }
  }

  /// Convert rotation turns into Syncfusion rotation enum
  static PdfPageRotateAngle getAngleFromTurns(int turns) {
    switch (turns % 4) {
      case 1:
        return PdfPageRotateAngle.rotateAngle90;
      case 2:
        return PdfPageRotateAngle.rotateAngle180;
      case 3:
        return PdfPageRotateAngle.rotateAngle270;
      case 0:
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  /// Instantly register newly created files into Android MediaStore
  static Future<void> notifyMediaStore(String filePath) async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.example.pdf_reader/content_resolver');
        await platform.invokeMethod('scanMediaFile', {'filePath': filePath});
      } catch (e) {
        debugPrint('MediaScanner scan error: $e');
      }
    }
  }

  /// 1. Merge multiple PDF files into one
  Future<ToolTaskResult> mergePdfs(
    List<String> inputPaths, {
    String? outputFileName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (inputPaths.length < 2) {
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: 'يرجى اختيار ملفين على الأقل للدمج / Please select at least 2 files',
      );
    }

    PdfDocument? targetDoc;
    final List<PdfDocument> openedDocs = [];

    try {
      targetDoc = PdfDocument();
      targetDoc.pageSettings.margins.all = 0;
      final totalFiles = inputPaths.length;

      for (int i = 0; i < totalFiles; i++) {
        final filePath = inputPaths[i];
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('الملف غير موجود / File not found: ${p.basename(filePath)}');
        }

        onProgress?.call((i / totalFiles) * 0.8, 'معالجة ${p.basename(filePath)}...');

        final bytes = await file.readAsBytes();
        PdfDocument srcDoc;
        try {
          srcDoc = PdfDocument(inputBytes: bytes);
          openedDocs.add(srcDoc);
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('password') || errStr.contains('encrypt')) {
            throw Exception('الملف محمي بكلمة مرور وغير مدعوم للدمج المباشر: ${p.basename(filePath)}');
          }
          throw Exception('الملف تالف أو غير مدعوم: ${p.basename(filePath)}');
        }

        for (int pIdx = 0; pIdx < srcDoc.pages.count; pIdx++) {
          final srcPage = srcDoc.pages[pIdx];
          final template = srcPage.createTemplate();
          final section = targetDoc.sections!.add();
          section.pageSettings.margins.all = 0;
          section.pageSettings.size = srcPage.size;
          section.pageSettings.orientation = srcPage.size.width > srcPage.size.height
              ? PdfPageOrientation.landscape
              : PdfPageOrientation.portrait;
          section.pageSettings.rotate = srcPage.rotation;

          final page = section.pages.add();
          page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0), srcPage.size);
        }
      }

      onProgress?.call(0.9, 'حفظ الملف المدمج...');

      final outputDir = await getOutputDir();
      final baseName = outputFileName?.trim().isNotEmpty == true
          ? outputFileName!.trim()
          : 'merged_${DateTime.now().millisecondsSinceEpoch}';
      final outputPath = generateSafeFilePath(outputDir, baseName, '.pdf');

      final outputBytes = await targetDoc.save();
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);
      await notifyMediaStore(outputPath);

      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: true,
        outputFiles: [outputFile],
        outputDirectory: outputDir.path,
        duration: stopwatch.elapsed,
        message: 'تم دمج ${inputPaths.length} ملفات بنجاح في ملف واحد',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    } finally {
      for (final doc in openedDocs) {
        doc.dispose();
      }
      targetDoc?.dispose();
    }
  }

  /// 2. Split PDF by specific page ranges
  Future<ToolTaskResult> splitPdf(
    String inputPath, {
    required List<List<int>> pageRanges, // 0-based page indices per group
    String? baseOutputName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final file = File(inputPath);
    if (!await file.exists()) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'الملف غير موجود / File not found');
    }

    PdfDocument? srcDoc;
    final List<File> createdFiles = [];

    try {
      final bytes = await file.readAsBytes();
      try {
        srcDoc = PdfDocument(inputBytes: bytes);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('password') || errStr.contains('encrypt')) {
          throw Exception('الملف محمي بكلمة مرور / Document is password protected');
        }
        throw Exception('الملف تالف أو غير صالح للتقسيم / Corrupted or invalid PDF');
      }

      final totalPages = srcDoc.pages.count;
      if (totalPages == 0) {
        throw Exception('المستند لا يحتوي على أي صفحات / Document has no pages');
      }

      final outputDir = await getOutputDir();
      final origBase = baseOutputName?.trim().isNotEmpty == true
          ? baseOutputName!.trim()
          : p.basenameWithoutExtension(inputPath);

      final totalGroups = pageRanges.length;

      for (int g = 0; g < totalGroups; g++) {
        final groupPages = pageRanges[g];
        if (groupPages.isEmpty) continue;

        onProgress?.call((g / totalGroups), 'تصدير الجزء ${g + 1} من $totalGroups...');

        final splitDoc = PdfDocument();
        splitDoc.pageSettings.margins.all = 0;
        for (final pageIdx in groupPages) {
          if (pageIdx >= 0 && pageIdx < totalPages) {
            final srcPage = srcDoc.pages[pageIdx];
            final template = srcPage.createTemplate();
            final section = splitDoc.sections!.add();
            section.pageSettings.margins.all = 0;
            section.pageSettings.size = srcPage.size;
            section.pageSettings.orientation = srcPage.size.width > srcPage.size.height
                ? PdfPageOrientation.landscape
                : PdfPageOrientation.portrait;
            section.pageSettings.rotate = srcPage.rotation;

            final page = section.pages.add();
            page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0), srcPage.size);
          }
        }

        final startPage = groupPages.first + 1;
        final endPage = groupPages.last + 1;
        final partSuffix = groupPages.length == 1
            ? 'page_$startPage'
            : 'pages_${startPage}_to_$endPage';

        final partBaseName = (totalGroups == 1 && baseOutputName?.trim().isNotEmpty == true)
            ? baseOutputName!.trim()
            : '${origBase}_$partSuffix';
        final outPath = generateSafeFilePath(outputDir, partBaseName, '.pdf');

        final splitBytes = await splitDoc.save();
        final splitFile = File(outPath);
        await splitFile.writeAsBytes(splitBytes);
        await notifyMediaStore(outPath);
        createdFiles.add(splitFile);
        splitDoc.dispose();
      }

      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: true,
        outputFiles: createdFiles,
        outputDirectory: outputDir.path,
        duration: stopwatch.elapsed,
        message: 'تم تقسيم المستند بنجاح إلى ${createdFiles.length} ملف',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    } finally {
      srcDoc?.dispose();
    }
  }

  /// 3. Organize pages: reorder, delete, rotate, and save as new document
  Future<ToolTaskResult> organizePdf(
    String inputPath, {
    required List<int> orderedPageIndices, // 0-based page indices to keep and their order
    Map<int, int>? pageRotations, // index in ordered list -> rotation turns (0: 0°, 1: 90°, 2: 180°, 3: 270°)
    String? outputFileName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final file = File(inputPath);
    if (!await file.exists()) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'الملف غير موجود / File not found');
    }

    if (orderedPageIndices.isEmpty) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'يجب اختيار صفحة واحدة على الأقل / Select at least 1 page');
    }

    PdfDocument? srcDoc;
    PdfDocument? newDoc;

    try {
      final bytes = await file.readAsBytes();
      try {
        srcDoc = PdfDocument(inputBytes: bytes);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('password') || errStr.contains('encrypt')) {
          throw Exception('الملف محمي بكلمة مرور / Document is password protected');
        }
        throw Exception('الملف تالف أو غير صالح / Corrupted or invalid PDF');
      }

      newDoc = PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      final total = orderedPageIndices.length;

      for (int i = 0; i < total; i++) {
        final pageIdx = orderedPageIndices[i];
        if (pageIdx >= 0 && pageIdx < srcDoc.pages.count) {
          onProgress?.call((i / total) * 0.85, 'تنظيم الصفحة ${i + 1} من $total...');
          final srcPage = srcDoc.pages[pageIdx];
          final template = srcPage.createTemplate();
          final section = newDoc.sections!.add();
          section.pageSettings.margins.all = 0;
          section.pageSettings.size = srcPage.size;
          section.pageSettings.orientation = srcPage.size.width > srcPage.size.height
              ? PdfPageOrientation.landscape
              : PdfPageOrientation.portrait;

          final origTurns = getRotationTurns(srcPage.rotation);
          final userTurns = (pageRotations?[i] ?? 0);
          final totalTurns = (origTurns + userTurns) % 4;
          section.pageSettings.rotate = getAngleFromTurns(totalTurns);

          final page = section.pages.add();
          page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0), srcPage.size);
        }
      }

      onProgress?.call(0.9, 'حفظ النسخة الجديدة...');

      final outputDir = await getOutputDir();
      final origBase = p.basenameWithoutExtension(inputPath);
      final baseName = outputFileName?.trim().isNotEmpty == true
          ? outputFileName!.trim()
          : '${origBase}_organized';
      final outputPath = generateSafeFilePath(outputDir, baseName, '.pdf');

      final outputBytes = await newDoc.save();
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);
      await notifyMediaStore(outputPath);

      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: true,
        outputFiles: [outputFile],
        outputDirectory: outputDir.path,
        duration: stopwatch.elapsed,
        message: 'تم حفظ المستند المنظم بنجاح (${orderedPageIndices.length} صفحة)',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    } finally {
      srcDoc?.dispose();
      newDoc?.dispose();
    }
  }

  /// 4. Convert images into a single PDF document
  Future<ToolTaskResult> imagesToPdf(
    List<String> imagePaths, {
    String? outputFileName,
    double margin = 20.0,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (imagePaths.isEmpty) {
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: 'يرجى اختيار صورة واحدة على الأقل / Select at least 1 image',
      );
    }

    PdfDocument? pdfDoc;
    int processedCount = 0;

    try {
      pdfDoc = PdfDocument();
      pdfDoc.pageSettings.margins.all = 0;
      final totalImages = imagePaths.length;

      for (int i = 0; i < totalImages; i++) {
        final imgPath = imagePaths[i];
        final imgFile = File(imgPath);
        if (!await imgFile.exists()) continue;

        onProgress?.call((i / totalImages) * 0.85, 'معالجة الصورة ${i + 1} من $totalImages...');

        Uint8List imageBytes = await imgFile.readAsBytes();

        bool isJpegOrPng = false;
        if (imageBytes.length >= 8) {
          if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8 && imageBytes[2] == 0xFF) {
            isJpegOrPng = true;
          } else if (imageBytes[0] == 0x89 &&
              imageBytes[1] == 0x50 &&
              imageBytes[2] == 0x4E &&
              imageBytes[3] == 0x47) {
            isJpegOrPng = true;
          }
        }

        // If not JPEG or PNG (e.g. WebP, BMP, GIF) or oversized (>3500px), decode and re-encode to JPEG
        try {
          final decoded = img.decodeImage(imageBytes);
          if (decoded != null) {
            if (!isJpegOrPng || decoded.width > 3500 || decoded.height > 3500) {
              img.Image targetImg = decoded;
              if (decoded.width > 3500 || decoded.height > 3500) {
                targetImg = img.copyResize(
                  decoded,
                  width: decoded.width > decoded.height ? 2500 : null,
                  height: decoded.height >= decoded.width ? 2500 : null,
                  interpolation: img.Interpolation.linear,
                );
              }
              imageBytes = Uint8List.fromList(img.encodeJpg(targetImg, quality: 90));
            }
          }
        } catch (e) {
          debugPrint('Image decoding/resizing note: $e');
        }

        PdfBitmap bitmap;
        try {
          bitmap = PdfBitmap(imageBytes);
        } catch (e) {
          throw Exception('صيغة صورة غير مدعومة أو ملف تالف: ${p.basename(imgPath)}');
        }

        final section = pdfDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        final imgW = bitmap.width.toDouble();
        final imgH = bitmap.height.toDouble();

        if (margin == 0.0) {
          // Zero margins: match page size exactly to image dimensions
          section.pageSettings.size = ui.Size(imgW, imgH);
          section.pageSettings.orientation = imgW > imgH
              ? PdfPageOrientation.landscape
              : PdfPageOrientation.portrait;
          final page = section.pages.add();
          page.graphics.drawImage(bitmap, ui.Rect.fromLTWH(0, 0, imgW, imgH));
        } else {
          // Standard page with margin padding
          final page = section.pages.add();
          final pageWidth = page.size.width;
          final pageHeight = page.size.height;

          final availW = pageWidth - (margin * 2);
          final availH = pageHeight - (margin * 2);

          double renderW = availW;
          double renderH = (availW / imgW) * imgH;

          if (renderH > availH) {
            renderH = availH;
            renderW = (availH / imgH) * imgW;
          }

          final posX = margin + ((availW - renderW) / 2);
          final posY = margin + ((availH - renderH) / 2);

          page.graphics.drawImage(bitmap, ui.Rect.fromLTWH(posX, posY, renderW, renderH));
        }
        processedCount++;
      }

      if (processedCount == 0) {
        throw Exception('لم يتم العثور على أي صور صالحة للتحويل / No valid images found');
      }

      onProgress?.call(0.9, 'إنشاء ملف PDF النهائي...');

      final outputDir = await getOutputDir();
      final baseName = outputFileName?.trim().isNotEmpty == true
          ? outputFileName!.trim()
          : 'images_to_pdf_${DateTime.now().millisecondsSinceEpoch}';
      final outputPath = generateSafeFilePath(outputDir, baseName, '.pdf');

      final outputBytes = await pdfDoc.save();
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);
      await notifyMediaStore(outputPath);

      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: true,
        outputFiles: [outputFile],
        outputDirectory: outputDir.path,
        duration: stopwatch.elapsed,
        message: 'تم تحويل ${imagePaths.length} صور إلى ملف PDF بنجاح',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    } finally {
      pdfDoc?.dispose();
    }
  }

  /// 5. Export PDF pages into individual image files (PNG or JPG) or a continuous Long Picture
  Future<ToolTaskResult> pdfToImages(
    String inputPath, {
    required List<int> pageNumbers, // 1-based page numbers
    String format = 'png', // 'png' or 'jpg'
    int jpgQuality = 85,
    double scale = 2.0,
    bool asLongPicture = false,
    String? outputName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final file = File(inputPath);
    if (!await file.exists()) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'الملف غير موجود / File not found');
    }

    if (pageNumbers.isEmpty) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'يرجى اختيار صفحة واحدة على الأقل للتصدير');
    }

    pdfrx.PdfDocument? rxDoc;
    final List<File> exportedFiles = [];

    try {
      rxDoc = await pdfrx.PdfDocument.openFile(inputPath);
      final totalDocPages = rxDoc.pages.length;

      final outputBaseDir = await getOutputDir();
      final origBase = p.basenameWithoutExtension(inputPath);
      final sanitizedCustom = (outputName != null && outputName.trim().isNotEmpty)
          ? outputName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          : origBase;
      final prefix = sanitizedCustom.isEmpty ? origBase : sanitizedCustom;
      final targetSubDirName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
      final exportFolder = Directory(p.join(outputBaseDir.path, targetSubDirName));
      if (!await exportFolder.exists()) {
        await exportFolder.create(recursive: true);
      }

      final totalToExport = pageNumbers.length;

      if (asLongPicture && totalToExport > 1) {
        onProgress?.call(0.05, 'حساب أبعاد الصورة الطولية...');
        int maxWidth = 0;
        int totalHeight = 0;
        for (final pNum in pageNumbers) {
          if (pNum >= 1 && pNum <= totalDocPages) {
            final p = rxDoc.pages[pNum - 1];
            final w = (p.width * scale).round();
            final h = (p.height * scale).round();
            if (w > maxWidth) maxWidth = w;
            totalHeight += h;
          }
        }

        if (maxWidth > 0 && totalHeight > 0) {
          final stitched = img.Image(width: maxWidth, height: totalHeight);
          img.fill(stitched, color: img.ColorRgb8(255, 255, 255));
          int currentY = 0;

          for (int i = 0; i < totalToExport; i++) {
            final pNum = pageNumbers[i];
            if (pNum < 1 || pNum > totalDocPages) continue;

            onProgress?.call(0.1 + (i / totalToExport) * 0.7, 'معالجة الصفحة $pNum ($i من $totalToExport)...');
            final page = rxDoc.pages[pNum - 1];
            final renderWidth = (page.width * scale).round();
            final renderHeight = (page.height * scale).round();

            final pageImage = await page.render(
              width: renderWidth,
              height: renderHeight,
            );

            if (pageImage != null) {
              final uiImage = await pageImage.createImage();
              final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
              pageImage.dispose();

              if (byteData != null) {
                final dImg = img.decodePng(byteData.buffer.asUint8List());
                if (dImg != null) {
                  final xOffset = (maxWidth - dImg.width) ~/ 2;
                  img.compositeImage(stitched, dImg, dstX: xOffset, dstY: currentY);
                  currentY += dImg.height;
                }
              }
            }
          }

          onProgress?.call(0.85, 'ترميز وحفظ الصورة الطولية...');
          final isPng = format.toLowerCase() == 'png';
          final ext = isPng ? 'png' : 'jpg';
          final outFilePath = generateSafeFilePath(exportFolder, '${prefix}_long_picture', ext);

          final outBytes = await compute(
            _encodeImageTask,
            _EncodeImageParams(
              image: stitched,
              isPng: isPng,
              jpgQuality: jpgQuality,
            ),
          );

          final longPicFile = File(outFilePath);
          await longPicFile.writeAsBytes(outBytes);
          await notifyMediaStore(longPicFile.path);
          exportedFiles.add(longPicFile);
        }
      } else {
        for (int i = 0; i < totalToExport; i++) {
          final pNum = pageNumbers[i];
          if (pNum < 1 || pNum > totalDocPages) continue;

          onProgress?.call((i / totalToExport), 'تصدير الصفحة $pNum ($i من $totalToExport)...');

          final page = rxDoc.pages[pNum - 1];
          final renderWidth = (page.width * scale).round();
          final renderHeight = (page.height * scale).round();

          final pageImage = await page.render(
            width: renderWidth,
            height: renderHeight,
          );

          if (pageImage != null) {
            final uiImage = await pageImage.createImage();
            final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
            pageImage.dispose();

            if (byteData != null) {
              final pngBytes = byteData.buffer.asUint8List();
              final isJpg = format.toLowerCase() == 'jpg' || format.toLowerCase() == 'jpeg';
              final ext = isJpg ? 'jpg' : 'png';
              final outFilePath = generateSafeFilePath(
                exportFolder,
                '${prefix}_page_${pNum.toString().padLeft(3, '0')}',
                ext,
              );

              Uint8List finalBytes;
              if (isJpg) {
                finalBytes = await compute(
                  _convertPngToJpgTask,
                  _PngToJpgParams(pngBytes: pngBytes, jpgQuality: jpgQuality),
                );
              } else {
                finalBytes = pngBytes;
              }

              final outFile = File(outFilePath);
              await outFile.writeAsBytes(finalBytes);
              await notifyMediaStore(outFile.path);
              exportedFiles.add(outFile);
            }
          }
        }
      }

      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: true,
        outputFiles: exportedFiles,
        outputDirectory: exportFolder.path,
        duration: stopwatch.elapsed,
        message: 'تم تصدير ${exportedFiles.length} صفحة كصور بدقة عالية',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    } finally {
      await rxDoc?.dispose();
    }
  }

  /// 6. Compress PDF file and save safely to Aura_PDF_Tools
  Future<ToolTaskResult> compressPdf(
    String inputPath, {
    String? outputFileName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final file = File(inputPath);
    if (!await file.exists()) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'الملف غير موجود / File not found');
    }

    try {
      onProgress?.call(0.1, 'جاري قراءة وتحليل المستند...');
      final bytes = await file.readAsBytes();
      final origSize = bytes.length;

      final sfDoc = PdfDocument(inputBytes: bytes);
      sfDoc.compressionLevel = PdfCompressionLevel.best;

      onProgress?.call(0.6, 'جاري ضغط مجاري البيانات والأشجار...');
      final compressedBytes = await sfDoc.save();
      sfDoc.dispose();

      final compSize = compressedBytes.length;
      final outputDir = await getOutputDir();
      final origBase = p.basenameWithoutExtension(inputPath);
      final baseName = outputFileName?.trim().isNotEmpty == true
          ? outputFileName!.trim()
          : '${origBase}_compressed';
      final outputPath = generateSafeFilePath(outputDir, baseName, '.pdf');

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedBytes);
      await notifyMediaStore(outputPath);

      stopwatch.stop();
      String _formatSize(int b) {
        if (b < 1024) return '$b B';
        if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
        return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
      }

      final origStr = _formatSize(origSize);
      final compStr = _formatSize(compSize);

      return ToolTaskResult(
        isSuccess: true,
        outputFiles: [outputFile],
        outputDirectory: outputDir.path,
        duration: stopwatch.elapsed,
        message: 'تم ضغط الملف بنجاح ($origStr ◄ $compStr)',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    }
  }

  /// 7. Extract plain text from all pages into a .txt file safely in Aura_PDF_Tools
  Future<ToolTaskResult> extractText(
    String inputPath, {
    String? outputFileName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final file = File(inputPath);
    if (!await file.exists()) {
      return ToolTaskResult(isSuccess: false, errorMessage: 'الملف غير موجود / File not found');
    }

    pdfrx.PdfDocument? rxDoc;
    try {
      onProgress?.call(0.1, 'جاري فتح المستند لاستخراج النصوص...');
      rxDoc = await pdfrx.PdfDocument.openFile(inputPath);
      final total = rxDoc.pages.length;
      final buffer = StringBuffer();

      for (int i = 1; i <= total; i++) {
        onProgress?.call(0.1 + (i / total) * 0.75, 'استخراج نصوص الصفحة $i من $total...');
        final page = rxDoc.pages[i - 1];
        final text = await PdfTextLayout.extractPageText(page);
        if (i > 1) buffer.writeln();
        buffer.writeln('--- Page $i ---');
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }

      onProgress?.call(0.9, 'جاري حفظ الملف النصي...');
      final outputDir = await getOutputDir();
      final origBase = p.basenameWithoutExtension(inputPath);
      final baseName = outputFileName?.trim().isNotEmpty == true
          ? outputFileName!.trim()
          : '${origBase}_text';
      final outputPath = generateSafeFilePath(outputDir, baseName, '.txt');

      final txtFile = File(outputPath);
      await txtFile.writeAsString(buffer.toString());
      await notifyMediaStore(outputPath);

      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: true,
        outputFiles: [txtFile],
        outputDirectory: outputDir.path,
        duration: stopwatch.elapsed,
        message: 'تم استخراج نصوص $total صفحة بنجاح إلى ملف نصي',
      );
    } catch (e) {
      stopwatch.stop();
      return ToolTaskResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        duration: stopwatch.elapsed,
      );
    } finally {
      await rxDoc?.dispose();
    }
  }
}

class _EncodeImageParams {
  final img.Image image;
  final bool isPng;
  final int jpgQuality;

  _EncodeImageParams({
    required this.image,
    required this.isPng,
    required this.jpgQuality,
  });
}

Uint8List _encodeImageTask(_EncodeImageParams params) {
  if (params.isPng) {
    return Uint8List.fromList(img.encodePng(params.image));
  } else {
    return Uint8List.fromList(img.encodeJpg(params.image, quality: params.jpgQuality));
  }
}

class _PngToJpgParams {
  final Uint8List pngBytes;
  final int jpgQuality;

  _PngToJpgParams({required this.pngBytes, required this.jpgQuality});
}

Uint8List _convertPngToJpgTask(_PngToJpgParams params) {
  final decodedImg = img.decodePng(params.pngBytes);
  if (decodedImg != null) {
    return Uint8List.fromList(img.encodeJpg(decodedImg, quality: params.jpgQuality));
  }
  return params.pngBytes;
}

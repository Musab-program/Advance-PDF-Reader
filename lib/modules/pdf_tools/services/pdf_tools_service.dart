import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;
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
          final template = srcDoc.pages[pIdx].createTemplate();
          final page = targetDoc.pages.add();
          page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
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
        for (final pageIdx in groupPages) {
          if (pageIdx >= 0 && pageIdx < totalPages) {
            final template = srcDoc.pages[pageIdx].createTemplate();
            final page = splitDoc.pages.add();
            page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
          }
        }

        final startPage = groupPages.first + 1;
        final endPage = groupPages.last + 1;
        final partSuffix = groupPages.length == 1
            ? 'page_$startPage'
            : 'pages_${startPage}_to_$endPage';

        final partBaseName = '${origBase}_$partSuffix';
        final outPath = generateSafeFilePath(outputDir, partBaseName, '.pdf');

        final splitBytes = await splitDoc.save();
        final splitFile = File(outPath);
        await splitFile.writeAsBytes(splitBytes);
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
      final total = orderedPageIndices.length;

      for (int i = 0; i < total; i++) {
        final pageIdx = orderedPageIndices[i];
        if (pageIdx >= 0 && pageIdx < srcDoc.pages.count) {
          onProgress?.call((i / total) * 0.85, 'تنظيم الصفحة ${i + 1} من $total...');
          final template = srcDoc.pages[pageIdx].createTemplate();
          final page = newDoc.pages.add();
          final turns = (pageRotations?[i] ?? 0) % 4;
          if (turns == 1) {
            page.rotation = PdfPageRotateAngle.rotateAngle90;
          } else if (turns == 2) {
            page.rotation = PdfPageRotateAngle.rotateAngle180;
          } else if (turns == 3) {
            page.rotation = PdfPageRotateAngle.rotateAngle270;
          }
          page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
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

    try {
      pdfDoc = PdfDocument();
      final totalImages = imagePaths.length;

      for (int i = 0; i < totalImages; i++) {
        final imgPath = imagePaths[i];
        final imgFile = File(imgPath);
        if (!await imgFile.exists()) continue;

        onProgress?.call((i / totalImages) * 0.85, 'معالجة الصورة ${i + 1} من $totalImages...');

        Uint8List imageBytes = await imgFile.readAsBytes();

        // Safe decode and downscale if image is overwhelmingly large (> 4000px)
        try {
          final decoded = img.decodeImage(imageBytes);
          if (decoded != null) {
            if (decoded.width > 3500 || decoded.height > 3500) {
              final resized = img.copyResize(
                decoded,
                width: decoded.width > decoded.height ? 2500 : null,
                height: decoded.height >= decoded.width ? 2500 : null,
                interpolation: img.Interpolation.linear,
              );
              imageBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));
            }
          }
        } catch (_) {
          // If decoding fails, attempt raw pass to PdfBitmap
        }

        PdfBitmap bitmap;
        try {
          bitmap = PdfBitmap(imageBytes);
        } catch (e) {
          throw Exception('صيغة صورة غير مدعومة أو ملف تالف: ${p.basename(imgPath)}');
        }

        final page = pdfDoc.pages.add();
        final pageWidth = page.size.width;
        final pageHeight = page.size.height;

        final availW = pageWidth - (margin * 2);
        final availH = pageHeight - (margin * 2);

        final imgW = bitmap.width.toDouble();
        final imgH = bitmap.height.toDouble();

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

      onProgress?.call(0.9, 'إنشاء ملف PDF النهائي...');

      final outputDir = await getOutputDir();
      final baseName = outputFileName?.trim().isNotEmpty == true
          ? outputFileName!.trim()
          : 'images_to_pdf_${DateTime.now().millisecondsSinceEpoch}';
      final outputPath = generateSafeFilePath(outputDir, baseName, '.pdf');

      final outputBytes = await pdfDoc.save();
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);

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
      final targetSubDirName = '${origBase}_images_${DateTime.now().millisecondsSinceEpoch}';
      final exportFolder = Directory(p.join(outputBaseDir.path, targetSubDirName));
      if (!await exportFolder.exists()) {
        await exportFolder.create(recursive: true);
      }

      final totalToExport = pageNumbers.length;

      if (asLongPicture && totalToExport > 1) {
        onProgress?.call(0.1, 'تصيير الصفحات لتجميع الصورة الطولية...');
        final List<img.Image> decodedList = [];
        int maxWidth = 0;
        int totalHeight = 0;

        for (int i = 0; i < totalToExport; i++) {
          final pNum = pageNumbers[i];
          if (pNum < 1 || pNum > totalDocPages) continue;

          onProgress?.call(0.1 + (i / totalToExport) * 0.7, 'معالجة الصفحة $pNum...');
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
                decodedList.add(dImg);
                if (dImg.width > maxWidth) maxWidth = dImg.width;
                totalHeight += dImg.height;
              }
            }
          }
        }

        if (decodedList.isNotEmpty) {
          onProgress?.call(0.85, 'خياطة وتجميع الصورة الطولية...');
          final stitched = img.Image(width: maxWidth, height: totalHeight);
          img.fill(stitched, color: img.ColorRgb8(255, 255, 255));
          int currentY = 0;
          for (final pageImg in decodedList) {
            final xOffset = (maxWidth - pageImg.width) ~/ 2;
            img.compositeImage(stitched, pageImg, dstX: xOffset, dstY: currentY);
            currentY += pageImg.height;
          }

          onProgress?.call(0.95, 'حفظ الصورة الطولية...');
          final outFilePath = p.join(exportFolder.path, '${origBase}_long_picture.jpg');
          final jpgBytes = Uint8List.fromList(img.encodeJpg(stitched, quality: jpgQuality));
          final longPicFile = File(outFilePath);
          await longPicFile.writeAsBytes(jpgBytes);
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
              final outFilePath = p.join(exportFolder.path, 'page_${pNum.toString().padLeft(3, '0')}.$ext');

              Uint8List finalBytes;
              if (isJpg) {
                final decodedImg = img.decodePng(pngBytes);
                if (decodedImg != null) {
                  finalBytes = Uint8List.fromList(img.encodeJpg(decodedImg, quality: jpgQuality));
                } else {
                  finalBytes = pngBytes;
                }
              } else {
                finalBytes = pngBytes;
              }

              final outFile = File(outFilePath);
              await outFile.writeAsBytes(finalBytes);
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
}

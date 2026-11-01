import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/modules/office_viewer/services/docx_parser.dart';
import 'package:pdf_reader/modules/office_viewer/services/xlsx_parser.dart';
import 'package:pdf_reader/modules/office_viewer/services/pptx_parser.dart';
import 'package:pdf_reader/modules/office_viewer/services/legacy_binary_parser.dart';

class _OfficeParseTask {
  final Uint8List bytes;
  final String fileType;
  final String fileName;
  final bool isDark;

  const _OfficeParseTask({
    required this.bytes,
    required this.fileType,
    required this.fileName,
    required this.isDark,
  });
}

class _OfficeParseOutput {
  final String? htmlContent;
  final XlsxWorkbook? workbook;
  final PptxPresentation? presentation;

  const _OfficeParseOutput({
    this.htmlContent,
    this.workbook,
    this.presentation,
  });
}

/// Top-level isolate entrypoint so parsing large Office files never blocks the UI thread.
_OfficeParseOutput _parseOfficeInIsolate(_OfficeParseTask task) {
  final type = task.fileType;
  if (type == 'DOCX') {
    final html = DocxParser.parseToHtml(task.bytes, isDark: task.isDark);
    return _OfficeParseOutput(htmlContent: html);
  } else if (type == 'XLSX') {
    final wb = XlsxParser.parse(task.bytes);
    return _OfficeParseOutput(workbook: wb);
  } else if (type == 'CSV') {
    final csvText = utf8.decode(task.bytes, allowMalformed: true);
    final wb = XlsxParser.parseCsv(csvText, sheetName: task.fileName);
    return _OfficeParseOutput(workbook: wb);
  } else if (type == 'PPTX') {
    final pres = PptxParser.parse(task.bytes);
    return _OfficeParseOutput(presentation: pres);
  } else {
    // Legacy binary formats: DOC, XLS, PPT, WPS, ET, DPS, RTF
    final html = LegacyBinaryParser.parseToHtml(
      task.bytes,
      task.fileName,
      type,
      isDark: task.isDark,
    );
    return _OfficeParseOutput(htmlContent: html);
  }
}

class OfficeViewerController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxString filePath = ''.obs;
  final RxString fileName = ''.obs;
  final RxString fileType = ''.obs; // 'DOCX', 'DOC', 'XLSX', 'XLS', 'CSV', 'PPTX', 'PPT'
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  // Search bar state across Word / Excel / PowerPoint
  final RxBool isSearchOpen = false.obs;
  final RxString searchQuery = ''.obs;
  final TextEditingController searchTextController = TextEditingController();

  // Zoom & Dual Layout Controls
  final RxDouble zoomScale = 1.0.obs;
  final RxBool isDocxReflowMode = false.obs; // false = WPS Page Mode (A4 Twips), true = Mobile Reflow Mode
  final TransformationController xlsxTransformController = TransformationController();
  final TransformationController pptxTransformController = TransformationController();

  // Word / Legacy HTML specific
  WebViewController? docxWebViewController;

  // Excel / CSV Grid Engine specific
  final Rx<XlsxWorkbook?> workbook = Rx<XlsxWorkbook?>(null);
  final RxInt activeSheetIndex = 0.obs;
  final RxInt selectedRow = 0.obs;
  final RxInt selectedCol = 0.obs;
  final RxBool freezeFirstRow = true.obs;
  final RxBool freezeFirstCol = false.obs;
  final RxList<double> currentColumnWidths = <double>[].obs;

  // Selection summary metrics (WPS Hint Bar: Sum, Avg, Count)
  final RxInt numericSelectionCount = 0.obs;
  final RxDouble numericSelectionSum = 0.0.obs;
  final RxDouble numericSelectionAvg = 0.0.obs;

  // PowerPoint Scene Graph & Presentation Mode specific
  final Rx<PptxPresentation?> presentation = Rx<PptxPresentation?>(null);
  final RxInt currentSlideIndex = 0.obs;
  final RxBool isSlideCanvasMode = true.obs; // true = 16:9 Vector Canvas, false = Outline Cards
  final RxBool isPresentationPlayMode = false.obs; // Fullscreen Play Mode
  final RxBool isLaserPenEnabled = false.obs;
  final RxList<Offset?> laserStrokePoints = <Offset?>[].obs;
  late final PageController pptPageController;

  bool get isWordFamily => fileType.value == 'DOCX' || fileType.value == 'DOC';
  bool get isExcelFamily => fileType.value == 'XLSX' || fileType.value == 'CSV';
  bool get isPptFamily => fileType.value == 'PPTX';
  bool get isLegacyBinaryFallback =>
      fileType.value == 'DOC' || fileType.value == 'XLS' || fileType.value == 'PPT';

  @override
  void onInit() {
    super.onInit();
    pptPageController = PageController();
    xlsxTransformController.addListener(_onXlsxTransformChanged);
    pptxTransformController.addListener(_onPptxTransformChanged);

    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      filePath.value = args['filePath'] ?? '';
      fileName.value = args['fileName'] ?? 'Document';
      fileType.value = (args['fileType'] ?? '').toString().toUpperCase();
      _loadFile();
    }
  }

  /// Called when a new Office document arrives from WhatsApp / Telegram / File Manager
  /// while the OfficeViewer is already open.
  Future<void> loadExternalOfficeFile({
    required String newPath,
    required String newName,
    required String newType,
  }) async {
    filePath.value = newPath;
    fileName.value = newName;
    fileType.value = newType.toUpperCase();
    zoomScale.value = 1.0;
    activeSheetIndex.value = 0;
    currentSlideIndex.value = 0;
    isSearchOpen.value = false;
    searchQuery.value = '';
    searchTextController.clear();
    await _loadFile();
  }

  void _onXlsxTransformChanged() {
    if (isExcelFamily) {
      final scale = xlsxTransformController.value.getMaxScaleOnAxis();
      if ((scale - zoomScale.value).abs() > 0.02) {
        zoomScale.value = scale.clamp(0.25, 4.0);
      }
    }
  }

  void _onPptxTransformChanged() {
    if (isPptFamily) {
      final scale = pptxTransformController.value.getMaxScaleOnAxis();
      if ((scale - zoomScale.value).abs() > 0.02) {
        zoomScale.value = scale.clamp(0.3, 4.5);
      }
    }
  }

  @override
  void onClose() {
    xlsxTransformController.removeListener(_onXlsxTransformChanged);
    pptxTransformController.removeListener(_onPptxTransformChanged);
    xlsxTransformController.dispose();
    pptxTransformController.dispose();
    pptPageController.dispose();
    searchTextController.dispose();
    super.onClose();
  }

  void toggleSearch() {
    isSearchOpen.value = !isSearchOpen.value;
    if (!isSearchOpen.value) {
      searchQuery.value = '';
      searchTextController.clear();
    }
  }

  void onSearchSubmitted(String query) {
    searchQuery.value = query.trim();
    if (searchQuery.value.isEmpty) return;

    if (isWordFamily || isLegacyBinaryFallback) {
      final escaped = searchQuery.value.replaceAll("'", "\\'");
      docxWebViewController?.runJavaScript("highlightQuery('$escaped');");
    } else if (isExcelFamily && workbook.value != null) {
      final sheet = workbook.value!.sheets[activeSheetIndex.value];
      final q = searchQuery.value.toLowerCase();
      // Find next matching cell starting after current selection
      for (final rEntry in sheet.cells.entries) {
        for (final cEntry in rEntry.value.entries) {
          if (cEntry.value.value.toLowerCase().contains(q)) {
            selectCell(rEntry.key, cEntry.key);
            return;
          }
        }
      }
    } else if (isPptFamily && presentation.value != null) {
      final q = searchQuery.value.toLowerCase();
      final slides = presentation.value!.slides;
      for (int i = 0; i < slides.length; i++) {
        final s = slides[i];
        final matchTitle = s.title.toLowerCase().contains(q);
        final matchBullets = s.bulletPoints.any((b) => b.toLowerCase().contains(q));
        if (matchTitle || matchBullets) {
          jumpToSlide(i);
          return;
        }
      }
    }
  }

  void zoomIn() {
    final next = (zoomScale.value + 0.25).clamp(0.25, 4.0);
    _applyZoom(next);
  }

  void zoomOut() {
    final next = (zoomScale.value - 0.25).clamp(0.25, 4.0);
    _applyZoom(next);
  }

  void resetZoom() {
    _applyZoom(1.0);
  }

  void _applyZoom(double targetScale) {
    zoomScale.value = targetScale;
    if (isWordFamily || isLegacyBinaryFallback) {
      docxWebViewController?.runJavaScript('setDocZoom($targetScale);');
    } else if (isExcelFamily) {
      xlsxTransformController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
    } else if (isPptFamily) {
      pptxTransformController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
    }
  }

  void toggleDocxLayoutMode() {
    isDocxReflowMode.value = !isDocxReflowMode.value;
    docxWebViewController?.runJavaScript('setReflowMode(${isDocxReflowMode.value});');
  }

  void toggleFreezeFirstRow() {
    freezeFirstRow.value = !freezeFirstRow.value;
  }

  void togglePptDisplayMode() {
    isSlideCanvasMode.value = !isSlideCanvasMode.value;
  }

  void togglePresentationPlayMode() {
    isPresentationPlayMode.value = !isPresentationPlayMode.value;
    if (!isPresentationPlayMode.value) {
      isLaserPenEnabled.value = false;
      laserStrokePoints.clear();
    }
  }

  void toggleLaserPen() {
    isLaserPenEnabled.value = !isLaserPenEnabled.value;
    if (!isLaserPenEnabled.value) {
      laserStrokePoints.clear();
    }
  }

  void clearLaserStrokes() {
    laserStrokePoints.clear();
  }

  Future<void> _loadFile() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final file = File(filePath.value);
      if (!await file.exists()) {
        errorMessage.value = 'الملف غير موجود / File not found';
        isLoading.value = false;
        return;
      }

      final bytes = await file.readAsBytes();
      final isDark = Get.isDarkMode;

      // Offload heavy XML/Archive parsing to a background isolate (like WPS Sandbox Worker)
      final parsed = await compute(
        _parseOfficeInIsolate,
        _OfficeParseTask(
          bytes: bytes,
          fileType: fileType.value,
          fileName: fileName.value,
          isDark: isDark,
        ),
      );

      if (parsed.htmlContent != null) {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..enableZoom(true)
          ..loadHtmlString(parsed.htmlContent!);
        docxWebViewController = controller;
      } else if (parsed.workbook != null) {
        workbook.value = parsed.workbook;
        activeSheetIndex.value = 0;
        _computeColumnWidthsForActiveSheet();
        selectCell(0, 0);
      } else if (parsed.presentation != null) {
        presentation.value = parsed.presentation;
        currentSlideIndex.value = 0;
      }

      _storageService.addRecentFile(filePath.value, fileName.value);
      final count = parsed.presentation?.slides.length ??
          parsed.workbook?.sheets.length ??
          1;
      _storageService.savePageCount(filePath.value, count);
      _storageService.saveProgress(filePath.value, 1.0);
    } catch (e) {
      errorMessage.value = 'تعذر فتح المستند: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _computeColumnWidthsForActiveSheet() {
    final wb = workbook.value;
    if (wb == null || wb.sheets.isEmpty) {
      currentColumnWidths.clear();
      return;
    }
    final sheet = wb.sheets[activeSheetIndex.value];
    final int totalCols = (sheet.maxCol < 10 ? 10 : sheet.maxCol).clamp(1, 200);
    final int sampleRows = sheet.maxRow.clamp(1, 250);

    final widths = List<double>.filled(totalCols, 115.0);
    for (int c = 0; c < totalCols; c++) {
      int maxChars = 5;
      for (int r = 0; r < sampleRows; r++) {
        final len = sheet.getCell(r, c).length;
        if (len > maxChars) maxChars = len;
      }
      widths[c] = (maxChars * 8.2 + 26.0).clamp(96.0, 340.0);
    }
    currentColumnWidths.assignAll(widths);
  }

  void selectCell(int row, int col) {
    selectedRow.value = row;
    selectedCol.value = col;
    _updateColumnSelectionStats(col);
  }

  void _updateColumnSelectionStats(int col) {
    final wb = workbook.value;
    if (wb == null || wb.sheets.isEmpty) return;
    final sheet = wb.sheets[activeSheetIndex.value];

    int count = 0;
    double sum = 0.0;
    for (final rowMap in sheet.cells.values) {
      final cell = rowMap[col];
      if (cell != null && cell.isNumeric) {
        final v = double.tryParse(cell.value.replaceAll(',', ''));
        if (v != null) {
          count++;
          sum += v;
        }
      }
    }
    numericSelectionCount.value = count;
    numericSelectionSum.value = sum;
    numericSelectionAvg.value = count > 0 ? (sum / count) : 0.0;
  }

  String get selectedCellReference {
    return '${XlsxParser.colToLetter(selectedCol.value)}${selectedRow.value + 1}';
  }

  String get selectedCellFormulaOrValue {
    final wb = workbook.value;
    if (wb == null || wb.sheets.isEmpty) return '';
    final sheet = wb.sheets[activeSheetIndex.value];
    final cell = sheet.getCellObject(selectedRow.value, selectedCol.value);
    if (cell == null) return '';
    if (cell.formula != null && cell.formula!.isNotEmpty) {
      return '${cell.formula}  →  ${cell.value}';
    }
    return cell.value;
  }

  void switchSheet(int index) {
    if (workbook.value != null && index >= 0 && index < workbook.value!.sheets.length) {
      activeSheetIndex.value = index;
      _computeColumnWidthsForActiveSheet();
      selectCell(0, 0);
      resetZoom();
    }
  }

  void jumpToSlide(int index) {
    final pres = presentation.value;
    if (pres == null || index < 0 || index >= pres.slides.length) return;
    currentSlideIndex.value = index;
    if (pptPageController.hasClients) {
      pptPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void nextSlide() {
    if (presentation.value != null &&
        currentSlideIndex.value < presentation.value!.slides.length - 1) {
      jumpToSlide(currentSlideIndex.value + 1);
    }
  }

  void prevSlide() {
    if (currentSlideIndex.value > 0) {
      jumpToSlide(currentSlideIndex.value - 1);
    }
  }
}

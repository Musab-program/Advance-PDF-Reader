import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/pdf_text_layout.dart';
import '../models/editor_models.dart';
import '../widgets/signature_dialog.dart';
import '../widgets/formatted_text_dialog.dart';
import '../../pdf_tools/models/tool_task_result.dart';
import '../../pdf_tools/widgets/tool_result_sheet.dart';
import '../../pdf_tools/services/pdf_tools_service.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

class DocumentEditorController extends GetxController {
  final String? initialFilePath;
  DocumentEditorController({this.initialFilePath});

  // Document state
  final RxString filePath = ''.obs;
  final RxString fileName = ''.obs;
  final RxInt fileSize = 0.obs;
  final RxInt totalPages = 0.obs;
  final RxInt currentPage = 1.obs;
  final RxBool isLoading = false.obs;
  final RxBool loadFailed = false.obs;
  final RxBool hasUnsavedChanges = false.obs;
  final RxBool isSaving = false.obs;
  final RxDouble saveProgress = 0.0.obs;

  PdfViewerController pdfViewerController = PdfViewerController();

  // Active Tool state (WPS tabs)
  final Rx<EditorTab> activeTab = EditorTab.none.obs;
  final Rx<AnnotateTool> activeAnnotateTool = AnnotateTool.pen.obs;
  final Rx<FillSignTool> activeFillSignTool = FillSignTool.signature.obs;
  final Rx<EditTool> activeEditTool = EditTool.formattedText.obs;
  final RxBool isDrawingModeActive = false.obs;
  final RxInt activeDrawingPageIndex = 0.obs;

  // Tool settings (WPS SettingBar)
  final Rx<Color> selectedColor = const Color(0xFFDC2626).obs; // Red
  final RxDouble strokeWidth = 3.0.obs;
  final RxDouble fontSize = 14.0.obs;

  // Stored modifications
  final RxList<DrawnStroke> strokes = <DrawnStroke>[].obs;
  final RxList<PlacedStamp> stamps = <PlacedStamp>[].obs;

  // Selected stamp ID for manipulation & floating toolbar
  final RxnString selectedStampId = RxnString();

  // Eyedropper mode for Smart Whiteout color picking
  final RxnString eyedropperTargetStampId = RxnString();
  bool get isEyedropperActive => eyedropperTargetStampId.value != null;

  // Current drawing path & live smart markup preview in progress
  final RxList<Offset> activePathPoints = <Offset>[].obs;
  final RxList<Rect> activeSnappedRects = <Rect>[].obs;

  // Cache structured text & page geometry per page
  final Map<int, PdfPageRawText> pageTextCache = {};
  final Map<int, Size> pageViewSizes = {};
  final Map<int, PdfPage> pageRefs = {};

  // Undo / Redo stacks
  final List<dynamic> _undoStack = [];
  final List<dynamic> _redoStack = [];

  // Fast scroller tracking & viewer zoom indicator
  final RxBool isScrollingFast = false.obs;
  final RxDouble currentZoom = 1.0.obs;

  // Cached page snapshot for 60 FPS eyedropper magnifier loupe
  int? _eyedropperCachePageNum;
  int _eyedropperCacheWidth = 0;
  int _eyedropperCacheHeight = 0;
  Uint8List? _eyedropperCachePixels;
  ui.Image? _eyedropperCacheImage;
  Future<void>? _eyedropperPendingLoad;

  @override
  void onInit() {
    super.onInit();
    pdfViewerController.addListener(_onViewerMatrixChanged);
    if (initialFilePath != null && initialFilePath!.isNotEmpty) {
      isLoading.value = true;
      loadFile(initialFilePath!);
    }
  }

  @override
  void onClose() {
    pdfViewerController.removeListener(_onViewerMatrixChanged);
    disposeEyedropperCache();
    super.onClose();
  }

  void _onViewerMatrixChanged() {
    if (!pdfViewerController.isReady) return;
    final z = pdfViewerController.currentZoom;
    if (z.isFinite && z > 0 && (z - currentZoom.value).abs() > 0.005) {
      currentZoom.value = z;
    }
  }

  void zoomIn() {
    if (pdfViewerController.isReady) {
      pdfViewerController.zoomUp();
    }
  }

  void zoomOut() {
    if (pdfViewerController.isReady) {
      pdfViewerController.zoomDown();
    }
  }

  void resetZoom() {
    if (!pdfViewerController.isReady) return;
    final minZ = pdfViewerController.minScale;
    final altFit = pdfViewerController.alternativeFitScale;
    final target = altFit != null && altFit > minZ ? altFit : 1.0;
    final pageRect = currentPage.value >= 1 &&
            currentPage.value <= pdfViewerController.layout.pageLayouts.length
        ? pdfViewerController.layout.pageLayouts[currentPage.value - 1]
        : Rect.zero;
    final viewW = pdfViewerController.viewSize.width;
    final fitWidth = (pageRect.width > 0 && viewW > 0) ? (viewW / pageRect.width) : target;
    pdfViewerController.setZoom(Offset.zero, fitWidth);
  }

  void _markDirty() {
    hasUnsavedChanges.value = strokes.isNotEmpty || stamps.isNotEmpty;
  }

  Size _currentPageViewSize([int? pageIndex]) {
    final idx = pageIndex ?? (currentPage.value - 1);
    return pageViewSizes[idx] ?? const Size(350, 500);
  }

  Future<void> pickAndLoadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        await loadFile(result.files.single.path!);
      }
    } catch (e) {
      AppToast.showError('خطأ أثناء اختيار الملف: $e');
    }
  }

  Future<void> loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      loadFailed.value = true;
      isLoading.value = false;
      AppToast.showError('الملف غير موجود');
      return;
    }

    try {
      isLoading.value = true;
      loadFailed.value = false;
      final size = await file.length();
      final rxDoc = await PdfDocument.openFile(path);
      final count = rxDoc.pages.length;
      await rxDoc.dispose();

      filePath.value = path;
      fileName.value = p.basename(path);
      fileSize.value = size;
      totalPages.value = count;
      currentPage.value = 1;
      strokes.clear();
      stamps.clear();
      selectedStampId.value = null;
      eyedropperTargetStampId.value = null;
      activePathPoints.clear();
      activeSnappedRects.clear();
      pageTextCache.clear();
      pageViewSizes.clear();
      pageRefs.clear();
      _undoStack.clear();
      _redoStack.clear();
      activeTab.value = EditorTab.none;
      isDrawingModeActive.value = false;
      hasUnsavedChanges.value = false;
    } catch (e) {
      loadFailed.value = true;
      AppToast.showError('تعذر فتح المستند: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> confirmDiscardChanges(BuildContext context) async {
    if (!hasUnsavedChanges.value || (strokes.isEmpty && stamps.isEmpty)) {
      return true;
    }

    final choice = await LuxuryDialog.showCustom<String>(
      context,
      builder: (ctx) => LuxuryDialog(
        compact: true,
        accentColor: const Color(0xFFD97706),
        icon: Icons.warning_amber_rounded,
        title: 'wps_unsaved_title'.tr,
        message: 'wps_unsaved_message'.tr,
        customActions: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LuxuryDialog.gradientButton(
              context: ctx,
              label: 'wps_save_edits'.tr,
              icon: Icons.save_rounded,
              onTap: () => Navigator.of(ctx).pop('save'),
              height: 44,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('stay'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Text('wps_continue_editing'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('discard'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Text('wps_discard_edits'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (choice == 'discard') return true;
    if (choice == 'save' && context.mounted) {
      return await showSaveOptionsSheet(context);
    }
    return false;
  }

  Future<void> requestExit(BuildContext context) async {
    final canLeave = await confirmDiscardChanges(context);
    if (canLeave) {
      hasUnsavedChanges.value = false;
      Get.back();
    }
  }

  Future<void> pickAndLoadFileWithGuard(BuildContext context) async {
    final canProceed = await confirmDiscardChanges(context);
    if (!canProceed) return;
    await pickAndLoadFile();
  }

  void onPageChanged(int page) {
    currentPage.value = page;
  }

  void jumpToPage(int page) {
    if (page >= 1 && page <= totalPages.value) {
      currentPage.value = page;
      pdfViewerController.goToPage(pageNumber: page);
    }
  }

  // ── Tab Management ──
  void switchTab(EditorTab tab) {
    eyedropperTargetStampId.value = null;
    if (activeTab.value == tab) {
      activeTab.value = EditorTab.none;
      isDrawingModeActive.value = false;
    } else {
      activeTab.value = tab;
      if (tab == EditorTab.annotate) {
        if (activeAnnotateTool.value == AnnotateTool.select) {
          isDrawingModeActive.value = false;
        } else {
          isDrawingModeActive.value = true;
          selectedStampId.value = null;
        }
      } else {
        isDrawingModeActive.value = false;
      }
    }
  }

  void selectAnnotateTool(AnnotateTool tool) {
    eyedropperTargetStampId.value = null;
    activeAnnotateTool.value = tool;
    if (tool == AnnotateTool.select) {
      isDrawingModeActive.value = false;
      return;
    }
    isDrawingModeActive.value = true;
    selectedStampId.value = null;
    switch (tool) {
      case AnnotateTool.highlighter:
        selectedColor.value = const Color(0xFFEAB308);
        strokeWidth.value = 14.0;
        break;
      case AnnotateTool.underline:
        selectedColor.value = const Color(0xFF2563EB);
        strokeWidth.value = 3.0;
        break;
      case AnnotateTool.strikeout:
        selectedColor.value = const Color(0xFFDC2626);
        strokeWidth.value = 3.0;
        break;
      case AnnotateTool.eraser:
        strokeWidth.value = 20.0;
        break;
      case AnnotateTool.pen:
        if (selectedColor.value.toARGB32() == const Color(0xFFEAB308).toARGB32()) {
          selectedColor.value = const Color(0xFFDC2626);
        }
        strokeWidth.value = 3.0;
        break;
      default:
        strokeWidth.value = 3.0;
        break;
    }
  }

  void setDrawingColor(Color color) {
    selectedColor.value = color;
    if (selectedStampId.value != null) {
      changeStampColor(selectedStampId.value!, color);
    } else if (activeAnnotateTool.value == AnnotateTool.eraser) {
      activeAnnotateTool.value = AnnotateTool.pen;
      strokeWidth.value = 3.0;
    }
  }

  void setStrokeWidth(double width) {
    strokeWidth.value = width;
    if (selectedStampId.value != null) {
      changeStampStrokeWidth(selectedStampId.value!, width.clamp(1.5, 12.0));
    }
  }

  // ── Eyedropper Color Picker for Smart Whiteout & Text Boxes ──
  void startEyedropperForStamp(String stampId) {
    selectedStampId.value = stampId;
    eyedropperTargetStampId.value = stampId;
    isDrawingModeActive.value = false;
  }

  void cancelEyedropper() {
    eyedropperTargetStampId.value = null;
    disposeEyedropperCache();
  }

  void disposeEyedropperCache() {
    _eyedropperCachePageNum = null;
    _eyedropperCacheWidth = 0;
    _eyedropperCacheHeight = 0;
    _eyedropperCachePixels = null;
    _eyedropperCacheImage?.dispose();
    _eyedropperCacheImage = null;
    _eyedropperPendingLoad = null;
  }

  ui.Image? get eyedropperPreviewImage => _eyedropperCacheImage;
  int get eyedropperPreviewWidth => _eyedropperCacheWidth;
  int get eyedropperPreviewHeight => _eyedropperCacheHeight;
  int? get eyedropperPreviewPageNum => _eyedropperCachePageNum;

  /// Pre-renders a reusable page snapshot so dragging the eyedropper loupe updates at 60 FPS.
  Future<void> ensureEyedropperPageImage(PdfPage? pdfPage) async {
    if (pdfPage == null) return;
    if (_eyedropperCachePageNum == pdfPage.pageNumber &&
        _eyedropperCachePixels != null &&
        _eyedropperCacheImage != null) {
      return;
    }
    if (_eyedropperPendingLoad != null) {
      await _eyedropperPendingLoad;
      return;
    }

    final completer = Completer<void>();
    _eyedropperPendingLoad = completer.future;
    try {
      final page = pdfPage.isLoaded ? pdfPage : await pdfPage.ensureLoaded();
      final double maxSide = 960.0;
      final scale = math.min(2.0, math.min(maxSide / math.max(1.0, page.width), maxSide / math.max(1.0, page.height)));
      final renderW = (page.width * scale).round().clamp(100, 1200);
      final renderH = (page.height * scale).round().clamp(100, 1600);

      final rendered = await page.render(
        x: 0,
        y: 0,
        width: renderW,
        height: renderH,
        fullWidth: renderW.toDouble(),
        fullHeight: renderH.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );

      if (rendered != null) {
        try {
          final bytesCopy = Uint8List.fromList(rendered.pixels);
          final imgCompleter = Completer<ui.Image>();
          ui.decodeImageFromPixels(
            bytesCopy,
            rendered.width,
            rendered.height,
            ui.PixelFormat.bgra8888,
            imgCompleter.complete,
          );
          final uiImg = await imgCompleter.future;
          _eyedropperCacheImage?.dispose();
          _eyedropperCachePageNum = page.pageNumber;
          _eyedropperCacheWidth = rendered.width;
          _eyedropperCacheHeight = rendered.height;
          _eyedropperCachePixels = bytesCopy;
          _eyedropperCacheImage = uiImg;
        } finally {
          rendered.dispose();
        }
      }
    } catch (e) {
      debugPrint('Eyedropper snapshot error: $e');
    } finally {
      _eyedropperPendingLoad = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  /// Synchronously samples a 3x3 average color from the cached page snapshot at [localPos].
  Color? sampleEyedropperColorSync(Offset localPos, Size pageViewSize, int pageNumber) {
    final pixels = _eyedropperCachePixels;
    if (pixels == null ||
        _eyedropperCachePageNum != pageNumber ||
        _eyedropperCacheWidth <= 0 ||
        _eyedropperCacheHeight <= 0 ||
        pageViewSize.width <= 0 ||
        pageViewSize.height <= 0) {
      return null;
    }

    final normX = (localPos.dx / pageViewSize.width).clamp(0.0, 0.9999);
    final normY = (localPos.dy / pageViewSize.height).clamp(0.0, 0.9999);
    final cx = (normX * _eyedropperCacheWidth).floor().clamp(0, _eyedropperCacheWidth - 1);
    final cy = (normY * _eyedropperCacheHeight).floor().clamp(0, _eyedropperCacheHeight - 1);

    int sumR = 0, sumG = 0, sumB = 0, count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      final py = (cy + dy).clamp(0, _eyedropperCacheHeight - 1);
      for (int dx = -1; dx <= 1; dx++) {
        final px = (cx + dx).clamp(0, _eyedropperCacheWidth - 1);
        final off = (py * _eyedropperCacheWidth + px) * 4;
        if (off + 2 < pixels.length) {
          sumB += pixels[off];
          sumG += pixels[off + 1];
          sumR += pixels[off + 2];
          count++;
        }
      }
    }
    if (count == 0) return null;
    return Color.fromARGB(
      255,
      (sumR / count).round().clamp(0, 255),
      (sumG / count).round().clamp(0, 255),
      (sumB / count).round().clamp(0, 255),
    );
  }

  Future<void> pickPageColorAt(
    Offset localPos,
    Size pageViewSize,
    PdfPage? pdfPage,
  ) async {
    final targetId = eyedropperTargetStampId.value;
    if (targetId == null) return;

    Color? sampledColor = pdfPage != null
        ? sampleEyedropperColorSync(localPos, pageViewSize, pdfPage.pageNumber)
        : null;

    if (sampledColor == null) {
      sampledColor = Colors.white;
      if (pdfPage != null && pageViewSize.width > 0 && pageViewSize.height > 0) {
        try {
          final page = pdfPage.isLoaded ? pdfPage : await pdfPage.ensureLoaded();
          final fullW = page.width.round().clamp(1, 8000);
          final fullH = page.height.round().clamp(1, 8000);
          final normX = (localPos.dx / pageViewSize.width).clamp(0.0, 0.9999);
          final normY = (localPos.dy / pageViewSize.height).clamp(0.0, 0.9999);
          final int cx = (normX * fullW).floor().clamp(0, fullW - 1).toInt();
          final int cy = (normY * fullH).floor().clamp(0, fullH - 1).toInt();
          final int patchX = (cx - 1).clamp(0, math.max(0, fullW - 3)).toInt();
          final int patchY = (cy - 1).clamp(0, math.max(0, fullH - 3)).toInt();
          final int patchW = (fullW - patchX).clamp(1, 3).toInt();
          final int patchH = (fullH - patchY).clamp(1, 3).toInt();

          final rendered = await page.render(
            x: patchX,
            y: patchY,
            width: patchW,
            height: patchH,
            fullWidth: fullW.toDouble(),
            fullHeight: fullH.toDouble(),
            backgroundColor: 0xFFFFFFFF,
          );

          if (rendered != null) {
            try {
              final pixels = rendered.pixels;
              final count = rendered.width * rendered.height;
              if (count > 0 && pixels.length >= count * 4) {
                int sumR = 0, sumG = 0, sumB = 0;
                for (int i = 0; i < count; i++) {
                  final off = i * 4;
                  sumB += pixels[off];
                  sumG += pixels[off + 1];
                  sumR += pixels[off + 2];
                }
                sampledColor = Color.fromARGB(
                  255,
                  (sumR / count).round().clamp(0, 255),
                  (sumG / count).round().clamp(0, 255),
                  (sumB / count).round().clamp(0, 255),
                );
              }
            } finally {
              rendered.dispose();
            }
          }
        } catch (e) {
          debugPrint('Eyedropper render error: $e');
        }
      }
    }

    changeStampBackgroundColor(targetId, sampledColor);
    eyedropperTargetStampId.value = null;
    selectedStampId.value = targetId;
    disposeEyedropperCache();
    AppToast.showSuccess('wps_color_picked'.tr);
  }

  Future<void> commitEyedropperAt(
    Offset localPos,
    Size pageViewSize,
    PdfPage? pdfPage,
  ) =>
      pickPageColorAt(localPos, pageViewSize, pdfPage);

  // ── Stamp Selection & Manipulation ──
  void selectStamp(String? id) {
    selectedStampId.value = id;
    if (id != null) {
      final stamp = stamps.firstWhereOrNull((s) => s.id == id);
      if (stamp != null && stamp.type != StampType.whiteout) {
        selectedColor.value = stamp.color;
        strokeWidth.value = stamp.strokeWidth.clamp(1.5, 12.0);
      }
    }
  }

  static bool isFixedMarkupType(StampType type) =>
      type == StampType.highlightRect ||
      type == StampType.underlineRect ||
      type == StampType.strikeoutRect;

  void duplicateStamp(String id) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final original = stamps[index];
    if (isFixedMarkupType(original.type)) return;
    final copy = original.copy();
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    const offsetDelta = Offset(20, 20);
    final duplicated = PlacedStamp(
      id: newId,
      type: copy.type,
      pageIndex: copy.pageIndex,
      position: copy.position + offsetDelta,
      size: copy.size,
      text: copy.text,
      imageBytes: copy.imageBytes,
      rawSignatureLines: copy.rawSignatureLines,
      color: copy.color,
      backgroundColor: copy.backgroundColor,
      borderColor: copy.borderColor,
      fontSize: copy.fontSize,
      strokeWidth: copy.strokeWidth,
      isBold: copy.isBold,
      alignment: copy.alignment,
      pageViewSize: copy.pageViewSize,
      lineRects: copy.lineRects?.map((r) => r.shift(offsetDelta)).toList(),
    );
    stamps.add(duplicated);
    selectedStampId.value = newId;
    _undoStack.add(duplicated);
    _redoStack.clear();
    _markDirty();
    AppToast.showSuccess('wps_duplicate'.tr);
  }

  void changeStampColor(String id, Color newColor) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      stamps[index].color = newColor;
      stamps.refresh();
      _markDirty();
    }
  }

  void changeStampStrokeWidth(String id, double newWidth) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      stamps[index].strokeWidth = newWidth.clamp(1.0, 12.0);
      stamps.refresh();
      _markDirty();
    }
  }

  void changeStampBackgroundColor(String id, Color? newColor) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      stamps[index].backgroundColor = newColor;
      stamps.refresh();
      _markDirty();
    }
  }

  void changeStampBorderColor(String id, Color? newColor) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      stamps[index].borderColor = newColor;
      stamps.refresh();
      _markDirty();
    }
  }

  void toggleStampBorder(String id) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final stamp = stamps[index];
    stamp.borderColor = stamp.borderColor == null ? const Color(0xFF94A3B8) : null;
    stamps.refresh();
    _markDirty();
  }

  void changeStampFontSize(String id, double delta) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      stamps[index].fontSize = (stamps[index].fontSize + delta).clamp(10.0, 72.0);
      stamps.refresh();
      _markDirty();
    }
  }

  void changeStampScale(String id, double factor) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      final cur = stamps[index];
      if (isFixedMarkupType(cur.type)) return;
      final oldSize = cur.size;
      final newSize = Size(
        (oldSize.width * factor).clamp(24.0, 600.0),
        (oldSize.height * factor).clamp(16.0, 600.0),
      );
      if (cur.lineRects != null && oldSize.width > 0 && oldSize.height > 0) {
        final sx = newSize.width / oldSize.width;
        final sy = newSize.height / oldSize.height;
        cur.lineRects = cur.lineRects!.map((r) {
          return Rect.fromLTWH(
            cur.position.dx + (r.left - cur.position.dx) * sx,
            cur.position.dy + (r.top - cur.position.dy) * sy,
            r.width * sx,
            r.height * sy,
          );
        }).toList();
      }
      cur.size = newSize;
      if (cur.type == StampType.quickText || cur.type == StampType.formattedTextBox) {
        cur.fontSize = (cur.fontSize * factor).clamp(10.0, 64.0);
      }
      stamps.refresh();
      _markDirty();
    }
  }

  void updateStampPosition(String id, Offset newOffset) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      final cur = stamps[index];
      if (isFixedMarkupType(cur.type)) return;
      final delta = newOffset - cur.position;
      cur.position = newOffset;
      if (cur.lineRects != null) {
        cur.lineRects = cur.lineRects!.map((r) => r.shift(delta)).toList();
      }
      stamps.refresh();
      _markDirty();
    }
  }

  void updateStampSize(String id, Size newSize) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      final s = stamps[index];
      if (isFixedMarkupType(s.type)) return;
      final oldWidth = s.size.width;
      final oldHeight = s.size.height;
      final clampedWidth = newSize.width.clamp(20.0, 600.0);
      final clampedHeight = newSize.height.clamp(16.0, 600.0);
      if (s.lineRects != null && oldWidth > 0 && oldHeight > 0) {
        final sx = clampedWidth / oldWidth;
        final sy = clampedHeight / oldHeight;
        s.lineRects = s.lineRects!.map((r) {
          return Rect.fromLTWH(
            s.position.dx + (r.left - s.position.dx) * sx,
            s.position.dy + (r.top - s.position.dy) * sy,
            r.width * sx,
            r.height * sy,
          );
        }).toList();
      }
      s.size = Size(clampedWidth, clampedHeight);
      if (oldHeight > 0 && (s.type == StampType.quickText || s.type == StampType.formattedTextBox)) {
        final ratio = clampedHeight / oldHeight;
        s.fontSize = (s.fontSize * ratio).clamp(8.0, 72.0);
      }
      stamps.refresh();
      _markDirty();
    }
  }

  void removeStamp(String id) {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index != -1) {
      final removed = stamps.removeAt(index);
      if (selectedStampId.value == id) {
        selectedStampId.value = null;
      }
      _undoStack.add([removed]);
      _redoStack.clear();
      _markDirty();
    }
  }

  Size _measureQuickTextSize(String text, double textFontSize, {bool isBold = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: textFontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: PdfTextLayout.isRtlDominantText(text) ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 320.0);
    return Size(
      (painter.width + 16.0).clamp(42.0, 340.0),
      (painter.height + 10.0).clamp(26.0, 140.0),
    );
  }

  Future<void> editStampContent(String id, BuildContext context) async {
    final index = stamps.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final stamp = stamps[index];

    if (stamp.type == StampType.formattedTextBox) {
      final result = await FormattedTextDialog.show(
        context,
        initialConfig: FormattedTextConfig(
          text: stamp.text ?? '',
          fontSize: stamp.fontSize,
          isBold: stamp.isBold,
          alignment: stamp.alignment,
          textColor: stamp.color,
          backgroundColor: stamp.backgroundColor,
          borderColor: stamp.borderColor,
        ),
      );
      if (result != null) {
        stamp.text = result.text;
        stamp.fontSize = result.fontSize;
        stamp.isBold = result.isBold;
        stamp.alignment = result.alignment;
        stamp.color = result.textColor;
        stamp.backgroundColor = result.backgroundColor;
        stamp.borderColor = result.borderColor;
        stamps.refresh();
        _markDirty();
        if (result.pickBackgroundFromPage) {
          startEyedropperForStamp(stamp.id);
        }
      }
    } else if (stamp.type == StampType.quickText) {
      _showQuickTextInputDialog(context, initialText: stamp.text, onDone: (newText) {
        stamp.text = newText;
        stamp.size = _measureQuickTextSize(newText, stamp.fontSize, isBold: stamp.isBold);
        stamps.refresh();
        _markDirty();
      });
    }
  }

  // ── Page Metrics & Structured Text Caching ──
  void registerPageMetrics(int pageIndex, Size pageViewSize, PdfPage? page) {
    if (pageViewSize.width > 0 && pageViewSize.height > 0) {
      pageViewSizes[pageIndex] = pageViewSize;
    }
    if (page != null) {
      pageRefs[pageIndex] = page;
      cachePageText(pageIndex + 1, page);
    }
  }

  Future<PdfPageRawText?> cachePageText(int pageNumber, PdfPage page) async {
    final existing = pageTextCache[pageNumber];
    if (existing != null) return existing;
    try {
      final targetPage = page.isLoaded ? page : await page.ensureLoaded();
      final text = await targetPage.loadText();
      if (text != null) {
        pageTextCache[pageNumber] = text;
      }
      return text;
    } catch (_) {
      return null;
    }
  }

  /// Groups individual character boxes into crisp per-line horizontal rectangles.
  static List<Rect> clusterCharBoxesIntoLines(List<Rect> charBoxes) {
    if (charBoxes.isEmpty) return const [];
    final sorted = List<Rect>.from(charBoxes)
      ..sort((a, b) {
        final lineTol = (a.height > 0 ? a.height : 12.0) * 0.55;
        if ((a.center.dy - b.center.dy).abs() <= lineTol) {
          return a.left.compareTo(b.left);
        }
        return a.center.dy.compareTo(b.center.dy);
      });

    final lines = <Rect>[];
    Rect current = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      final avgH = ((current.height + next.height) / 2.0).clamp(8.0, 60.0);
      final sameLine = (next.center.dy - current.center.dy).abs() <= avgH * 0.65;
      final horizGap = next.left - current.right;
      final reasonableGap = horizGap <= (avgH * 3.0).clamp(24.0, 60.0);
      if (sameLine && reasonableGap) {
        current = Rect.fromLTRB(
          math.min(current.left, next.left),
          math.min(current.top, next.top),
          math.max(current.right, next.right),
          math.max(current.bottom, next.bottom),
        );
      } else {
        lines.add(current.inflate(1.0));
        current = next;
      }
    }
    lines.add(current.inflate(1.0));
    return lines;
  }

  static double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq <= 0.0001) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  bool get _isSmartMarkupTool =>
      activeAnnotateTool.value == AnnotateTool.highlighter ||
      activeAnnotateTool.value == AnnotateTool.underline ||
      activeAnnotateTool.value == AnnotateTool.strikeout;

  StampType get _currentMarkupStampType {
    switch (activeAnnotateTool.value) {
      case AnnotateTool.underline:
        return StampType.underlineRect;
      case AnnotateTool.strikeout:
        return StampType.strikeoutRect;
      default:
        return StampType.highlightRect;
    }
  }

  List<Rect> _computeSnappedLineRects(
    List<Offset> points,
    PdfPageRawText? pageText,
    PdfPage? pdfPage,
    Size pageViewSize,
  ) {
    if (points.length < 2 || pageText == null || pdfPage == null || pageText.charRects.isEmpty) {
      return const [];
    }

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (final pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    final strokeBounds = Rect.fromLTRB(minX, minY, maxX, maxY);

    final startPt = points.first;
    final endPt = points.last;

    int firstIdx = -1;
    double bestFirstDist = 26.0;
    int lastIdx = -1;
    double bestLastDist = 26.0;

    final nearChars = <Rect>[];
    final indexedBoxes = <int, Rect>{};

    for (int i = 0; i < pageText.charRects.length; i++) {
      final cr = pageText.charRects[i];
      if (cr.isEmpty) continue;
      final box = cr.toRect(page: pdfPage, scaledPageSize: pageViewSize);
      indexedBoxes[i] = box;

      final dFirst = (box.center - startPt).distance;
      if (dFirst < bestFirstDist) {
        bestFirstDist = dFirst;
        firstIdx = i;
      }

      final dLast = (box.center - endPt).distance;
      if (dLast < bestLastDist) {
        bestLastDist = dLast;
        lastIdx = i;
      }

      if (box.inflate(3.0).overlaps(strokeBounds)) {
        // Confirm at least one path segment runs close to this character box
        for (int j = 1; j < points.length; j++) {
          if (box.inflate(6.0).contains(points[j]) ||
              box.inflate(6.0).contains(points[j - 1]) ||
              _distancePointToSegment(box.center, points[j - 1], points[j]) <=
                  math.max(box.height * 0.75, 10.0)) {
            nearChars.add(box);
            break;
          }
        }
      }
    }

    if (nearChars.isEmpty) {
      return const [];
    }

    // Browser-style paragraph selection between start and end char indices
    if (firstIdx != -1 && lastIdx != -1 && (firstIdx - lastIdx).abs() >= 1) {
      final lo = math.min(firstIdx, lastIdx);
      final hi = math.max(firstIdx, lastIdx);
      final firstBox = indexedBoxes[firstIdx];
      final lastBox = indexedBoxes[lastIdx];

      if (firstBox != null && lastBox != null) {
        final verticalBandTop = math.min(firstBox.top, lastBox.top) - 18.0;
        final verticalBandBottom = math.max(firstBox.bottom, lastBox.bottom) + 18.0;
        final streamBoxes = <Rect>[];
        bool jumpedOutsideColumnOrPage = false;

        for (int i = lo; i <= hi; i++) {
          final b = indexedBoxes[i];
          if (b == null) continue;
          if (b.center.dy < verticalBandTop || b.center.dy > verticalBandBottom) {
            jumpedOutsideColumnOrPage = true;
            break;
          }
          streamBoxes.add(b);
        }

        if (!jumpedOutsideColumnOrPage && streamBoxes.isNotEmpty) {
          return clusterCharBoxesIntoLines(streamBoxes);
        }
      }
    }

    return clusterCharBoxesIntoLines(nearChars);
  }

  // ── Drawing Actions (Page Overlays) ──
  void startDrawing(Offset localPos, int pageIndex, {PdfPage? pdfPage}) {
    activeDrawingPageIndex.value = pageIndex;
    activePathPoints.clear();
    activeSnappedRects.clear();
    activePathPoints.add(localPos);
    selectedStampId.value = null;
    if (pdfPage != null) {
      pageRefs[pageIndex] = pdfPage;
      cachePageText(pageIndex + 1, pdfPage);
    }
  }

  void updateDrawing(Offset localPos, {int? pageIndex, Size? pageViewSize, PdfPage? pdfPage}) {
    activePathPoints.add(localPos);
    if (_isSmartMarkupTool && pageIndex != null && pageViewSize != null && pdfPage != null) {
      final pageText = pageTextCache[pageIndex + 1];
      if (pageText != null && pageText.charRects.isNotEmpty) {
        final snapped = _computeSnappedLineRects(activePathPoints, pageText, pdfPage, pageViewSize);
        activeSnappedRects.assignAll(snapped);
      }
    }
  }

  void cancelActiveDrawing() {
    if (activePathPoints.isNotEmpty || activeSnappedRects.isNotEmpty) {
      activePathPoints.clear();
      activeSnappedRects.clear();
    }
  }

  Future<void> endDrawing(int pageIndex, Size pageViewSize, {PdfPage? pdfPage}) async {
    final points = List<Offset>.from(activePathPoints);
    activePathPoints.clear();
    activeSnappedRects.clear();

    if (points.length < 2) {
      return;
    }

    if (activeAnnotateTool.value == AnnotateTool.eraser) {
      _eraseNear(points, pageIndex, pageViewSize);
      return;
    }

    // ── Smart Text Markup Snapping (Highlight / Underline / Strikeout) ──
    if (_isSmartMarkupTool && pdfPage != null) {
      final pageText = pageTextCache[pageIndex + 1] ?? await cachePageText(pageIndex + 1, pdfPage);
      final lineRects = _computeSnappedLineRects(points, pageText, pdfPage, pageViewSize);

      if (lineRects.isNotEmpty) {
        final union = lineRects.reduce((a, b) => a.expandToInclude(b));
        final markupStamp = PlacedStamp(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: _currentMarkupStampType,
          pageIndex: pageIndex,
          position: union.topLeft,
          size: union.size,
          color: selectedColor.value,
          strokeWidth: strokeWidth.value.clamp(2.0, 8.0),
          pageViewSize: pageViewSize,
          lineRects: lineRects,
        );

        stamps.add(markupStamp);
        selectedStampId.value = markupStamp.id;
        activeAnnotateTool.value = AnnotateTool.select;
        isDrawingModeActive.value = false;
        _undoStack.add(markupStamp);
        _redoStack.clear();
        _markDirty();
        return;
      }
    }

    // Fallback: Freehand stroke (Blank areas or scanned PDFs without text layer)
    final stroke = DrawnStroke(
      points: points,
      color: selectedColor.value,
      strokeWidth: strokeWidth.value,
      isHighlighter: activeAnnotateTool.value == AnnotateTool.highlighter,
      isEraser: false,
      pageIndex: pageIndex,
      pageViewSize: pageViewSize,
    );

    strokes.add(stroke);
    _undoStack.add(stroke);
    _redoStack.clear();
    _markDirty();
  }

  Future<void> addMarkupFromTextSelection(
    PdfTextSelectionDelegate delegate,
    StampType markupType,
  ) async {
    final ranges = await delegate.getSelectedTextRanges();
    if (ranges.isEmpty) return;

    int addedCount = 0;
    for (final range in ranges) {
      final pageIndex = range.pageNumber - 1;
      final page = pageRefs[pageIndex];
      final viewSize = pageViewSizes[pageIndex];
      if (page == null || viewSize == null) continue;

      final selectedBoxes = <Rect>[];
      final safeStart = range.start.clamp(0, range.pageText.charRects.length);
      final safeEnd = range.end.clamp(0, range.pageText.charRects.length);
      for (int i = safeStart; i < safeEnd; i++) {
        final cr = range.pageText.charRects[i];
        if (cr.isNotEmpty) {
          selectedBoxes.add(cr.toRect(page: page, scaledPageSize: viewSize));
        }
      }

      final lineRects = clusterCharBoxesIntoLines(selectedBoxes);
      if (lineRects.isEmpty) continue;

      final union = lineRects.reduce((a, b) => a.expandToInclude(b));
      final Color defaultColor = markupType == StampType.underlineRect
          ? const Color(0xFF2563EB)
          : markupType == StampType.strikeoutRect
              ? const Color(0xFFDC2626)
              : const Color(0xFFEAB308);

      final stamp = PlacedStamp(
        id: '${DateTime.now().microsecondsSinceEpoch}_$addedCount',
        type: markupType,
        pageIndex: pageIndex,
        position: union.topLeft,
        size: union.size,
        color: defaultColor,
        strokeWidth: 2.5,
        pageViewSize: viewSize,
        text: range.text,
        lineRects: lineRects,
      );
      stamps.add(stamp);
      _undoStack.add(stamp);
      addedCount++;
    }

    if (addedCount > 0) {
      selectedStampId.value = stamps.last.id;
      activeAnnotateTool.value = AnnotateTool.select;
      isDrawingModeActive.value = false;
      _redoStack.clear();
      _markDirty();
      await delegate.clearTextSelection();
      AppToast.showSuccess('wps_markup_added'.tr);
    }
  }

  static bool _segmentsCross(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset o, Offset p, Offset q) =>
        (p.dx - o.dx) * (q.dy - o.dy) - (p.dy - o.dy) * (q.dx - o.dx);
    final d1 = cross(c, d, a);
    final d2 = cross(c, d, b);
    final d3 = cross(a, b, c);
    final d4 = cross(a, b, d);
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static bool _segmentIntersectsRect(Offset p0, Offset p1, Rect r) {
    final dx = p1.dx - p0.dx;
    final dy = p1.dy - p0.dy;
    double tMin = 0.0;
    double tMax = 1.0;

    bool clip(double p, double q) {
      if (p.abs() < 1e-6) return q >= 0.0;
      final t = q / p;
      if (p < 0.0) {
        if (t > tMax) return false;
        if (t > tMin) tMin = t;
      } else {
        if (t < tMin) return false;
        if (t < tMax) tMax = t;
      }
      return true;
    }

    return clip(-dx, p0.dx - r.left) &&
        clip(dx, r.right - p0.dx) &&
        clip(-dy, p0.dy - r.top) &&
        clip(dy, r.bottom - p0.dy);
  }

  void _eraseNear(List<Offset> eraserPoints, int pageIndex, [Size? currentPageSize]) {
    if (eraserPoints.isEmpty) return;
    final erasedStrokes = <DrawnStroke>[];
    final radius = math.max(strokeWidth.value, 14.0);

    for (final s in strokes.where((s) => s.pageIndex == pageIndex)) {
      final sx = (currentPageSize != null && s.pageViewSize.width > 0)
          ? currentPageSize.width / s.pageViewSize.width
          : 1.0;
      final sy = (currentPageSize != null && s.pageViewSize.height > 0)
          ? currentPageSize.height / s.pageViewSize.height
          : 1.0;

      bool intersects = false;
      for (int i = 0; i < s.points.length; i++) {
        final pt = Offset(s.points[i].dx * sx, s.points[i].dy * sy);
        final prevPt = i > 0 ? Offset(s.points[i - 1].dx * sx, s.points[i - 1].dy * sy) : pt;

        for (int j = 0; j < eraserPoints.length; j++) {
          final ep = eraserPoints[j];
          if ((pt - ep).distance <= radius) {
            intersects = true;
            break;
          }
          if (i > 0 && _distancePointToSegment(ep, prevPt, pt) <= radius) {
            intersects = true;
            break;
          }
          if (j > 0) {
            final prevEp = eraserPoints[j - 1];
            if (_distancePointToSegment(pt, prevEp, ep) <= radius ||
                (i > 0 && _segmentsCross(prevPt, pt, prevEp, ep))) {
              intersects = true;
              break;
            }
          }
        }
        if (intersects) break;
      }
      if (intersects) {
        erasedStrokes.add(s);
      }
    }

    final erasedStamps = <PlacedStamp>[];
    for (final st in stamps.where((st) => st.pageIndex == pageIndex)) {
      final sx = (currentPageSize != null && st.pageViewSize.width > 0)
          ? currentPageSize.width / st.pageViewSize.width
          : 1.0;
      final sy = (currentPageSize != null && st.pageViewSize.height > 0)
          ? currentPageSize.height / st.pageViewSize.height
          : 1.0;

      final List<Rect> hitRects;
      if (st.lineRects != null && st.lineRects!.isNotEmpty) {
        hitRects = st.lineRects!
            .map((r) => Rect.fromLTWH(r.left * sx, r.top * sy, r.width * sx, r.height * sy))
            .toList();
      } else {
        hitRects = [
          Rect.fromLTWH(
            st.position.dx * sx,
            st.position.dy * sy,
            st.size.width * sx,
            st.size.height * sy,
          ),
        ];
      }

      bool intersects = false;
      for (final rect in hitRects) {
        final inflated = rect.inflate((radius * 0.45).clamp(4.0, 14.0));
        for (int j = 0; j < eraserPoints.length; j++) {
          final ep = eraserPoints[j];
          if (inflated.contains(ep) ||
              (j > 0 && _segmentIntersectsRect(eraserPoints[j - 1], ep, inflated))) {
            intersects = true;
            break;
          }
        }
        if (intersects) break;
      }

      if (intersects) {
        erasedStamps.add(st);
      }
    }

    if (erasedStrokes.isNotEmpty || erasedStamps.isNotEmpty) {
      if (erasedStrokes.isNotEmpty) {
        strokes.removeWhere((s) => erasedStrokes.contains(s));
      }
      if (erasedStamps.isNotEmpty) {
        stamps.removeWhere((s) => erasedStamps.contains(s));
        if (selectedStampId.value != null &&
            erasedStamps.any((e) => e.id == selectedStampId.value)) {
          selectedStampId.value = null;
        }
      }
      _undoStack.add(EraseAction(
        erasedStrokes: erasedStrokes,
        erasedStamps: erasedStamps,
      ));
      _redoStack.clear();
      _markDirty();
    }
  }

  // ── Shape Placement (WPS Annotate Shapes) ──
  void addShape(StampType shapeType) {
    final pageIdx = currentPage.value - 1;
    final viewSize = _currentPageViewSize(pageIdx);
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final shapeColor = activeAnnotateTool.value == AnnotateTool.eraser
        ? const Color(0xFFDC2626)
        : selectedColor.value;
    final width = strokeWidth.value.clamp(2.0, 10.0);

    final initialSize = shapeType == StampType.circleShape
        ? const Size(96, 96)
        : (shapeType == StampType.lineShape || shapeType == StampType.arrowShape)
            ? const Size(120, 48)
            : const Size(130, 84);

    final stamp = PlacedStamp(
      id: newId,
      type: shapeType,
      pageIndex: pageIdx,
      position: Offset(
        (viewSize.width * 0.2).clamp(24.0, 140.0),
        (viewSize.height * 0.25).clamp(40.0, 200.0),
      ),
      size: initialSize,
      color: shapeColor,
      strokeWidth: width,
      pageViewSize: viewSize,
    );
    stamps.add(stamp);
    selectedStampId.value = newId;
    activeAnnotateTool.value = AnnotateTool.select;
    isDrawingModeActive.value = false;
    _undoStack.add(stamp);
    _redoStack.clear();
    _markDirty();
    AppToast.showSuccess('wps_shape_added'.tr);
  }

  // ── Fill & Sign Actions ──
  Future<void> handleFillSignAction(FillSignTool tool, BuildContext context) async {
    activeFillSignTool.value = tool;

    switch (tool) {
      case FillSignTool.signature:
        final data = await SignatureDialog.show(context);
        if (data != null) {
          _addSignatureStamp(data);
        }
        break;

      case FillSignTool.quickText:
        _showQuickTextInputDialog(context, onDone: (text) {
          _addQuickTextStamp(text);
        });
        break;

      case FillSignTool.check:
        _addSymbolStamp(StampType.check, '✔', const Color(0xFF16A34A));
        break;

      case FillSignTool.cross:
        _addSymbolStamp(StampType.cross, '✖', const Color(0xFFDC2626));
        break;

      case FillSignTool.dot:
        _addSymbolStamp(StampType.dot, '●', const Color(0xFF2563EB));
        break;

      case FillSignTool.dateStamp:
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        _addSymbolStamp(StampType.dateStamp, dateStr, const Color(0xFF1E293B));
        break;
    }
  }

  void _addSignatureStamp(SignatureData data) {
    final pageIdx = currentPage.value - 1;
    final viewSize = _currentPageViewSize(pageIdx);
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final height = (160.0 / data.aspectRatio.clamp(0.5, 3.5)).clamp(50.0, 140.0);
    final stamp = PlacedStamp(
      id: newId,
      type: StampType.signature,
      pageIndex: pageIdx,
      position: const Offset(40, 120),
      size: Size(160, height),
      imageBytes: data.pngBytes,
      rawSignatureLines: data.normalizedLines,
      color: data.color,
      pageViewSize: viewSize,
    );
    stamps.add(stamp);
    selectedStampId.value = newId;
    _undoStack.add(stamp);
    _redoStack.clear();
    _markDirty();
    AppToast.showSuccess('wps_signature_added'.tr);
  }

  void _addQuickTextStamp(String text) {
    final pageIdx = currentPage.value - 1;
    final viewSize = _currentPageViewSize(pageIdx);
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final measured = _measureQuickTextSize(text, fontSize.value, isBold: false);
    final stamp = PlacedStamp(
      id: newId,
      type: StampType.quickText,
      pageIndex: pageIdx,
      position: const Offset(40, 100),
      size: measured,
      text: text,
      color: selectedColor.value,
      fontSize: fontSize.value,
      isBold: false,
      pageViewSize: viewSize,
    );
    stamps.add(stamp);
    selectedStampId.value = newId;
    _undoStack.add(stamp);
    _redoStack.clear();
    _markDirty();
    AppToast.showSuccess('wps_quick_text_added'.tr);
  }

  void _addSymbolStamp(StampType type, String text, Color color) {
    final pageIdx = currentPage.value - 1;
    final viewSize = _currentPageViewSize(pageIdx);
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final stamp = PlacedStamp(
      id: newId,
      type: type,
      pageIndex: pageIdx,
      position: const Offset(50, 100),
      size: type == StampType.dateStamp ? const Size(96, 26) : const Size(44, 44),
      text: text,
      color: color,
      fontSize: type == StampType.dateStamp ? 12 : 22,
      isBold: type == StampType.dateStamp,
      alignment: type == StampType.dateStamp ? TextAlign.center : TextAlign.left,
      strokeWidth: 3.5,
      pageViewSize: viewSize,
    );
    stamps.add(stamp);
    selectedStampId.value = newId;
    _undoStack.add(stamp);
    _redoStack.clear();
    _markDirty();
    AppToast.showSuccess('wps_symbol_added'.tr);
  }

  void _showQuickTextInputDialog(
    BuildContext context, {
    String? initialText,
    required ValueChanged<String> onDone,
  }) {
    final textController = TextEditingController(text: initialText ?? '');
    LuxuryDialog.showCustom(
      context,
      builder: (ctx) => LuxuryDialog(
        compact: true,
        icon: Icons.text_fields_rounded,
        title: initialText == null ? 'wps_quick_text_title'.tr : 'wps_edit_text_title'.tr,
        body: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'wps_quick_text_hint'.tr,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        secondaryButtonText: 'cancel'.tr,
        primaryButtonText: initialText == null ? 'wps_insert'.tr : 'wps_save_changes'.tr,
        primaryButtonIcon: Icons.check_rounded,
        closeOnPrimary: false,
        onPrimaryPressed: () {
          final text = textController.text.trim();
          if (text.isNotEmpty) {
            Navigator.of(ctx).pop();
            onDone(text);
          }
        },
      ),
    );
  }

  // ── Edit Actions (Formatted Box & Smart Whiteout) ──
  Future<void> handleEditAction(EditTool tool, BuildContext context) async {
    activeEditTool.value = tool;
    final pageIdx = currentPage.value - 1;
    final viewSize = _currentPageViewSize(pageIdx);

    if (tool == EditTool.whiteout) {
      final newId = DateTime.now().microsecondsSinceEpoch.toString();
      final stamp = PlacedStamp(
        id: newId,
        type: StampType.whiteout,
        pageIndex: pageIdx,
        position: const Offset(40, 100),
        size: const Size(140, 36),
        color: Colors.transparent,
        backgroundColor: Colors.white,
        borderColor: null,
        pageViewSize: viewSize,
      );
      stamps.add(stamp);
      selectedStampId.value = newId;
      _undoStack.add(stamp);
      _redoStack.clear();
      _markDirty();
      AppToast.showSuccess('wps_whiteout_added'.tr);
    } else if (tool == EditTool.formattedText) {
      final result = await FormattedTextDialog.show(context);
      if (result != null) {
        final newId = DateTime.now().microsecondsSinceEpoch.toString();
        final stamp = PlacedStamp(
          id: newId,
          type: StampType.formattedTextBox,
          pageIndex: pageIdx,
          position: const Offset(40, 100),
          size: const Size(220, 100),
          text: result.text,
          fontSize: result.fontSize,
          isBold: result.isBold,
          alignment: result.alignment,
          color: result.textColor,
          backgroundColor: result.backgroundColor,
          borderColor: result.borderColor,
          pageViewSize: viewSize,
        );
        stamps.add(stamp);
        selectedStampId.value = newId;
        _undoStack.add(stamp);
        _redoStack.clear();
        _markDirty();
        if (result.pickBackgroundFromPage) {
          startEyedropperForStamp(newId);
        } else {
          AppToast.showSuccess('wps_formatted_box_added'.tr);
        }
      }
    }
  }

  // ── Undo / Redo ──
  void undo() {
    if (_undoStack.isEmpty) return;
    final lastAction = _undoStack.removeLast();

    if (lastAction is EraseAction) {
      strokes.addAll(lastAction.erasedStrokes);
      stamps.addAll(lastAction.erasedStamps);
      _redoStack.add(lastAction);
    } else if (lastAction is DrawnStroke) {
      strokes.remove(lastAction);
      _redoStack.add(lastAction);
    } else if (lastAction is PlacedStamp) {
      stamps.remove(lastAction);
      if (selectedStampId.value == lastAction.id) {
        selectedStampId.value = null;
      }
      _redoStack.add(lastAction);
    } else if (lastAction is List<DrawnStroke>) {
      strokes.addAll(lastAction);
      _redoStack.add(lastAction);
    } else if (lastAction is List<PlacedStamp>) {
      stamps.addAll(lastAction);
      _redoStack.add(lastAction);
    }
    _markDirty();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final lastRedo = _redoStack.removeLast();

    if (lastRedo is EraseAction) {
      strokes.removeWhere((s) => lastRedo.erasedStrokes.contains(s));
      stamps.removeWhere((s) => lastRedo.erasedStamps.contains(s));
      if (selectedStampId.value != null &&
          lastRedo.erasedStamps.any((e) => e.id == selectedStampId.value)) {
        selectedStampId.value = null;
      }
      _undoStack.add(lastRedo);
    } else if (lastRedo is DrawnStroke) {
      strokes.add(lastRedo);
      _undoStack.add(lastRedo);
    } else if (lastRedo is PlacedStamp) {
      stamps.add(lastRedo);
      _undoStack.add(lastRedo);
    } else if (lastRedo is List<DrawnStroke>) {
      strokes.removeWhere((s) => lastRedo.contains(s));
      _undoStack.add(lastRedo);
    } else if (lastRedo is List<PlacedStamp>) {
      stamps.removeWhere((s) => lastRedo.contains(s));
      _undoStack.add(lastRedo);
    }
    _markDirty();
  }

  void exitActiveTool() {
    isDrawingModeActive.value = false;
    activeTab.value = EditorTab.none;
    selectedStampId.value = null;
    eyedropperTargetStampId.value = null;
    activeSnappedRects.clear();
  }

  // ── Conversion Actions ──
  Future<void> copyCurrentPageText() async {
    final pageNum = currentPage.value;
    String? text;

    if (filePath.isNotEmpty) {
      try {
        final doc = await PdfDocument.openFile(filePath.value);
        if (pageNum >= 1 && pageNum <= doc.pages.length) {
          final page = doc.pages[pageNum - 1];
          text = await PdfTextLayout.extractPageText(page);
        }
        await doc.dispose();
      } catch (_) {}
    }

    if (text == null || text.trim().isEmpty) {
      final pageText = pageTextCache[pageNum];
      text = pageText?.fullText;
    }

    if (text == null || text.trim().isEmpty) {
      AppToast.showInfo('wps_no_text_found'.tr);
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    AppToast.showSuccess('wps_page_text_copied'.tr);
  }

  Future<void> extractText(BuildContext context) async {
    if (filePath.isEmpty) return;
    try {
      isLoading.value = true;
      String fullText = '';
      try {
        final doc = await PdfDocument.openFile(filePath.value);
        final buffer = StringBuffer();
        for (int i = 0; i < doc.pages.length; i++) {
          final page = doc.pages[i];
          final pageText = await PdfTextLayout.extractPageText(page);
          if (pageText.trim().isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.writeln();
              buffer.writeln('--- ${'wps_page'.tr} ${i + 1} ---');
              buffer.writeln();
            }
            buffer.write(pageText);
          }
        }
        await doc.dispose();
        fullText = buffer.toString();
      } catch (_) {
        final bytes = await File(filePath.value).readAsBytes();
        final doc = sf.PdfDocument(inputBytes: bytes);
        final extractor = sf.PdfTextExtractor(doc);
        fullText = extractor.extractText();
        doc.dispose();
      }

      if (fullText.trim().isEmpty) {
        AppToast.showInfo('wps_no_extractable_text'.tr);
        return;
      }

      final base = p.basenameWithoutExtension(fileName.value);
      final defaultFileName = '${base}_extracted';

      // Ask user for file name and show destination directory
      String? chosenName = defaultFileName;
      if (context.mounted) {
        chosenName = await _showExportFileNameDialog(context, defaultFileName);
        if (chosenName == null || chosenName.trim().isEmpty) {
          return;
        }
      }

      final targetDir = await PdfToolsService().getOutputDir(subFolder: 'AuraPDF');
      final outPath = PdfToolsService().generateSafeFilePath(targetDir, chosenName.trim(), '.txt');
      final outFile = File(outPath);
      await outFile.writeAsString(fullText);
      await PdfToolsService.notifyMediaStore(outPath);

      if (context.mounted) {
        ToolResultSheet.show(
          context,
          title: 'wps_text_extracted_success'.tr,
          result: ToolTaskResult(
            isSuccess: true,
            outputFiles: [outFile],
            message: 'wps_file_saved_in_download'.tr,
          ),
        );
      }
    } catch (e) {
      AppToast.showError('${'wps_extract_failed'.tr}: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> _showExportFileNameDialog(BuildContext context, String defaultName) {
    final textController = TextEditingController(text: defaultName);
    String? errorText;
    return LuxuryDialog.showCustom<String>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => LuxuryDialog(
          compact: true,
          accentColor: const Color(0xFF16A34A),
          icon: Icons.drive_file_rename_outline_rounded,
          title: 'wps_export_extracted_text'.tr,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'wps_export_file_name_label'.tr,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                decoration: InputDecoration(
                  suffixText: '.txt',
                  hintText: 'wps_file_name_hint'.tr,
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'wps_save_location_aurapdf'.tr,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          secondaryButtonText: 'cancel'.tr,
          primaryButtonText: 'wps_export'.tr,
          primaryButtonIcon: Icons.file_download_done_rounded,
          closeOnPrimary: false,
          onPrimaryPressed: () {
            final val = textController.text.trim();
            if (val.isEmpty) {
              setDialogState(() => errorText = 'wps_enter_file_name_first'.tr);
              return;
            }
            Navigator.of(ctx).pop(val);
          },
        ),
      ),
    );
  }

  // ── High-Res Text/Date/Box Rasterizers for PDF Export ──
  Future<Uint8List> _renderTextToBitmap(
    String text,
    Color color,
    double fontSize, {
    bool isDateStamp = false,
    bool isBold = false,
    TextAlign alignment = TextAlign.center,
    required Size targetSize,
  }) async {
    const scale = 3.0;
    final renderWidth = (targetSize.width * scale).clamp(40.0, 3000.0);
    final renderHeight = (targetSize.height * scale).clamp(20.0, 3000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (isDateStamp) {
      final bgPaint = Paint()..color = const Color(0xFFEFF6FF);
      final borderPaint = Paint()
        ..color = const Color(0xFF93C5FD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (scale / 2.5);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, renderWidth, renderHeight),
        Radius.circular(6 * (scale / 2.5)),
      );
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderPaint);
    }

    final isRtl = PdfTextLayout.isRtlDominantText(text);
    final effectiveAlignment = isDateStamp ? TextAlign.center : alignment;
    final effectiveFontSize = isDateStamp
        ? (renderHeight * 0.52).clamp(10.0, 150.0)
        : (fontSize * scale).clamp(10.0, 200.0);

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: effectiveFontSize,
        fontWeight: (isBold || isDateStamp) ? FontWeight.bold : FontWeight.normal,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: effectiveAlignment,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
    )..layout(maxWidth: renderWidth - (8.0 * scale));

    final offsetX = (effectiveAlignment == TextAlign.center || isDateStamp)
        ? ((renderWidth - textPainter.width) / 2.0).clamp(0.0, renderWidth)
        : (isRtl ? (renderWidth - textPainter.width - (4.0 * scale)) : 4.0 * scale);
    final offsetY = ((renderHeight - textPainter.height) / 2.0).clamp(0.0, renderHeight);

    textPainter.paint(canvas, Offset(offsetX, offsetY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(renderWidth.toInt(), renderHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _renderFormattedBoxToBitmap({
    required String text,
    required Color color,
    required double fontSize,
    required bool isBold,
    required TextAlign alignment,
    Color? backgroundColor,
    Color? borderColor,
    required Size targetSize,
  }) async {
    const scale = 3.0;
    final renderWidth = (targetSize.width * scale).clamp(40.0, 3000.0);
    final renderHeight = (targetSize.height * scale).clamp(20.0, 3000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background fill
    if (backgroundColor != null && backgroundColor.a > 0) {
      final bgPaint = Paint()..color = backgroundColor;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, renderWidth, renderHeight),
        Radius.circular(6 * scale),
      );
      canvas.drawRRect(rrect, bgPaint);
    }

    // Border
    if (borderColor != null && borderColor.a > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, renderWidth, renderHeight),
        Radius.circular(6 * scale),
      );
      canvas.drawRRect(rrect, borderPaint);
    }

    final isRtl = PdfTextLayout.isRtlDominantText(text);
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: (fontSize * scale).clamp(10.0, 200.0),
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: alignment,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
    )..layout(maxWidth: renderWidth - (16 * scale));

    final offsetY = ((renderHeight - textPainter.height) / 2.0).clamp(2.0 * scale, renderHeight);
    textPainter.paint(canvas, Offset(8 * scale, offsetY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(renderWidth.toInt(), renderHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ── Two-Option Save Sheet (New Separate Copy vs Overwrite Original) ──
  Future<bool> showSaveOptionsSheet(BuildContext context) async {
    if (filePath.isEmpty) return false;
    if (strokes.isEmpty && stamps.isEmpty) {
      AppToast.showInfo('wps_no_modifications_to_save'.tr);
      return false;
    }

    final origBase = p.basenameWithoutExtension(fileName.value.isNotEmpty ? fileName.value : filePath.value);
    final nameController = TextEditingController(text: '${origBase}_edited');
    bool overwriteOriginal = false;
    String? nameError;

    final confirmed = await LuxuryDialog.showCustom<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          final primary = theme.primaryColor;
          final warningAmber = const Color(0xFFD97706);

          return LuxuryDialog(
            compact: true,
            maxWidth: 385,
            accentColor: overwriteOriginal ? warningAmber : null,
            icon: Icons.save_rounded,
            title: 'wps_save_dialog_title'.tr,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Option 1: Save as new separate copy
                InkWell(
                  onTap: () => setDialogState(() => overwriteOriginal = false),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !overwriteOriginal ? primary.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !overwriteOriginal ? primary : theme.dividerColor.withValues(alpha: 0.4),
                        width: !overwriteOriginal ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              !overwriteOriginal
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: !overwriteOriginal ? primary : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'wps_save_as_new_copy'.tr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'wps_save_as_new_copy_desc'.tr,
                          style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                        ),
                        if (!overwriteOriginal) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: nameController,
                            onChanged: (_) {
                              if (nameError != null) {
                                setDialogState(() => nameError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'wps_new_version_name'.tr,
                              suffixText: '.pdf',
                              isDense: true,
                              errorText: nameError,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: Overwrite original file
                InkWell(
                  onTap: () => setDialogState(() {
                    overwriteOriginal = true;
                    nameError = null;
                  }),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: overwriteOriginal
                          ? warningAmber.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: overwriteOriginal
                            ? warningAmber
                            : theme.dividerColor.withValues(alpha: 0.4),
                        width: overwriteOriginal ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          overwriteOriginal
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: overwriteOriginal ? warningAmber : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'wps_overwrite_original'.tr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'wps_overwrite_original_desc'.tr,
                                style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            secondaryButtonText: 'cancel'.tr,
            primaryButtonText: overwriteOriginal ? 'wps_overwrite_and_save'.tr : 'wps_save_copy_btn'.tr,
            primaryButtonIcon: Icons.check_rounded,
            closeOnPrimary: false,
            onPrimaryPressed: () {
              if (!overwriteOriginal && nameController.text.trim().isEmpty) {
                setDialogState(() => nameError = 'wps_enter_version_name_first'.tr);
                return;
              }
              Navigator.of(ctx).pop(true);
            },
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return false;
    final customName = overwriteOriginal ? null : nameController.text.trim();
    return await saveModifications(
      context,
      overwriteOriginal: overwriteOriginal,
      customOutputName: customName,
    );
  }

  /// Applies all current stamps and freehand strokes onto [doc], emitting real PDF annotations
  /// for markup (highlight/underline/strikeout) and shapes (rectangle/ellipse/line/arrow),
  /// and crisp vector/bitmap graphics for signatures, whiteout, text boxes, symbols, and ink strokes.
  Future<void> applyModificationsToDocument(
    sf.PdfDocument doc, {
    ValueChanged<double>? onProgress,
  }) async {
    final totalDocPages = doc.pages.count;

    for (int i = 0; i < totalDocPages; i++) {
      final page = doc.pages[i];
      final pageSize = page.getClientSize();

      // 1. Render placed stamps for this page
      final pageStamps = stamps.where((s) => s.pageIndex == i).toList();
      for (final stamp in pageStamps) {
        final viewW = stamp.pageViewSize.width > 0 ? stamp.pageViewSize.width : pageSize.width;
        final viewH = stamp.pageViewSize.height > 0 ? stamp.pageViewSize.height : pageSize.height;
        final scaleX = pageSize.width / viewW;
        final scaleY = pageSize.height / viewH;
        final strokeScale = (scaleX + scaleY) / 2.0;

        final bounds = Rect.fromLTWH(
          stamp.position.dx * scaleX,
          stamp.position.dy * scaleY,
          stamp.size.width * scaleX,
          stamp.size.height * scaleY,
        );

        final r = (stamp.color.r * 255.0).round().clamp(0, 255);
        final g = (stamp.color.g * 255.0).round().clamp(0, 255);
        final b = (stamp.color.b * 255.0).round().clamp(0, 255);
        final pdfColor = sf.PdfColor(r, g, b);

        if (stamp.type == StampType.whiteout) {
          final bg = stamp.backgroundColor ?? Colors.white;
          final bgR = (bg.r * 255.0).round().clamp(0, 255);
          final bgG = (bg.g * 255.0).round().clamp(0, 255);
          final bgB = (bg.b * 255.0).round().clamp(0, 255);

          sf.PdfPen? borderPen;
          if (stamp.borderColor != null && stamp.borderColor!.a > 0) {
            final bc = stamp.borderColor!;
            borderPen = sf.PdfPen(
              sf.PdfColor(
                (bc.r * 255.0).round().clamp(0, 255),
                (bc.g * 255.0).round().clamp(0, 255),
                (bc.b * 255.0).round().clamp(0, 255),
              ),
              width: 1.0 * strokeScale,
            );
          }

          page.graphics.drawRectangle(
            pen: borderPen,
            brush: sf.PdfSolidBrush(sf.PdfColor(bgR, bgG, bgB)),
            bounds: bounds,
          );
        } else if (stamp.type == StampType.highlightRect ||
            stamp.type == StampType.underlineRect ||
            stamp.type == StampType.strikeoutRect) {
          final scaledLineRects = (stamp.lineRects != null && stamp.lineRects!.isNotEmpty)
              ? stamp.lineRects!
                  .map((lr) => Rect.fromLTWH(
                        lr.left * scaleX,
                        lr.top * scaleY,
                        lr.width * scaleX,
                        lr.height * scaleY,
                      ))
                  .toList()
              : <Rect>[bounds];
          final unionBounds = scaledLineRects.reduce((a, b) => a.expandToInclude(b));
          final markupType = stamp.type == StampType.underlineRect
              ? sf.PdfTextMarkupAnnotationType.underline
              : stamp.type == StampType.strikeoutRect
                  ? sf.PdfTextMarkupAnnotationType.strikethrough
                  : sf.PdfTextMarkupAnnotationType.highlight;

          final markupAnnotation = sf.PdfTextMarkupAnnotation(
            unionBounds,
            stamp.text ?? '',
            pdfColor,
            author: 'AuraPDF',
            opacity: stamp.type == StampType.highlightRect ? 0.35 : 1.0,
            setAppearance: true,
            boundsCollection: scaledLineRects,
            textMarkupAnnotationType: markupType,
          );
          page.annotations.add(markupAnnotation);
        } else if (stamp.type == StampType.rectShape) {
          final rectAnn = sf.PdfRectangleAnnotation(
            bounds,
            '',
            color: pdfColor,
            border: sf.PdfAnnotationBorder(stamp.strokeWidth * strokeScale),
            setAppearance: true,
          );
          page.annotations.add(rectAnn);
        } else if (stamp.type == StampType.circleShape) {
          final ellipseAnn = sf.PdfEllipseAnnotation(
            bounds,
            '',
            color: pdfColor,
            border: sf.PdfAnnotationBorder(stamp.strokeWidth * strokeScale),
            setAppearance: true,
          );
          page.annotations.add(ellipseAnn);
        } else if (stamp.type == StampType.lineShape || stamp.type == StampType.arrowShape) {
          final isArrow = stamp.type == StampType.arrowShape;
          final linePoints = <int>[
            bounds.left.round(),
            (pageSize.height - bounds.top).round(),
            bounds.right.round(),
            (pageSize.height - bounds.bottom).round(),
          ];
          final lineAnn = sf.PdfLineAnnotation(
            linePoints,
            '',
            color: pdfColor,
            innerColor: isArrow ? pdfColor : null,
            border: sf.PdfAnnotationBorder(stamp.strokeWidth * strokeScale),
            endLineStyle: isArrow ? sf.PdfLineEndingStyle.openArrow : sf.PdfLineEndingStyle.none,
            lineIntent: isArrow ? sf.PdfLineIntent.lineArrow : sf.PdfLineIntent.lineDimension,
            setAppearance: true,
          );
          page.annotations.add(lineAnn);
        } else if (stamp.type == StampType.signature) {
          if (stamp.rawSignatureLines != null && stamp.rawSignatureLines!.isNotEmpty) {
            final pen = sf.PdfPen(pdfColor, width: 3.5 * strokeScale);
            for (final line in stamp.rawSignatureLines!) {
              for (int j = 1; j < line.length; j++) {
                final p1 = Offset(
                  bounds.left + line[j - 1].dx * bounds.width,
                  bounds.top + line[j - 1].dy * bounds.height,
                );
                final p2 = Offset(
                  bounds.left + line[j].dx * bounds.width,
                  bounds.top + line[j].dy * bounds.height,
                );
                page.graphics.drawLine(pen, p1, p2);
              }
            }
          } else if (stamp.imageBytes != null) {
            final pdfImage = sf.PdfBitmap(stamp.imageBytes!);
            page.graphics.drawImage(pdfImage, bounds);
          }
        } else if (stamp.type == StampType.check) {
          final pen = sf.PdfPen(pdfColor, width: stamp.strokeWidth * strokeScale);
          page.graphics.drawLine(
            pen,
            Offset(bounds.left + bounds.width * 0.16, bounds.top + bounds.height * 0.54),
            Offset(bounds.left + bounds.width * 0.42, bounds.top + bounds.height * 0.80),
          );
          page.graphics.drawLine(
            pen,
            Offset(bounds.left + bounds.width * 0.42, bounds.top + bounds.height * 0.80),
            Offset(bounds.left + bounds.width * 0.84, bounds.top + bounds.height * 0.22),
          );
        } else if (stamp.type == StampType.cross) {
          final pen = sf.PdfPen(pdfColor, width: stamp.strokeWidth * strokeScale);
          page.graphics.drawLine(
            pen,
            Offset(bounds.left + bounds.width * 0.22, bounds.top + bounds.height * 0.22),
            Offset(bounds.right - bounds.width * 0.22, bounds.bottom - bounds.height * 0.22),
          );
          page.graphics.drawLine(
            pen,
            Offset(bounds.right - bounds.width * 0.22, bounds.top + bounds.height * 0.22),
            Offset(bounds.left + bounds.width * 0.22, bounds.bottom - bounds.height * 0.22),
          );
        } else if (stamp.type == StampType.dot) {
          page.graphics.drawEllipse(bounds, brush: sf.PdfSolidBrush(pdfColor));
        } else if (stamp.type == StampType.formattedTextBox &&
            stamp.text != null &&
            stamp.text!.isNotEmpty) {
          final imgBytes = await _renderFormattedBoxToBitmap(
            text: stamp.text!,
            color: stamp.color,
            fontSize: stamp.fontSize,
            isBold: stamp.isBold,
            alignment: stamp.alignment,
            backgroundColor: stamp.backgroundColor,
            borderColor: stamp.borderColor,
            targetSize: Size(bounds.width, bounds.height),
          );
          final pdfImage = sf.PdfBitmap(imgBytes);
          page.graphics.drawImage(pdfImage, bounds);
        } else if (stamp.text != null && stamp.text!.isNotEmpty) {
          final imgBytes = await _renderTextToBitmap(
            stamp.text!,
            stamp.color,
            stamp.fontSize,
            isDateStamp: stamp.type == StampType.dateStamp,
            isBold: stamp.isBold,
            alignment: stamp.type == StampType.dateStamp ? TextAlign.center : stamp.alignment,
            targetSize: Size(bounds.width, bounds.height),
          );
          final pdfImage = sf.PdfBitmap(imgBytes);
          page.graphics.drawImage(pdfImage, bounds);
        }
      }

      // 2. Render drawn freehand strokes for this page
      final pageStrokes = strokes.where((s) => s.pageIndex == i).toList();
      for (final stroke in pageStrokes) {
        if (stroke.points.length < 2) continue;

        final scaleX =
            pageSize.width / (stroke.pageViewSize.width > 0 ? stroke.pageViewSize.width : pageSize.width);
        final scaleY =
            pageSize.height / (stroke.pageViewSize.height > 0 ? stroke.pageViewSize.height : pageSize.height);
        final strokeScale = (scaleX + scaleY) / 2.0;

        final r = (stroke.color.r * 255.0).round().clamp(0, 255);
        final g = (stroke.color.g * 255.0).round().clamp(0, 255);
        final b = (stroke.color.b * 255.0).round().clamp(0, 255);

        final pdfPen = sf.PdfPen(
          sf.PdfColor(r, g, b),
          width: stroke.strokeWidth * strokeScale,
        );

        if (stroke.isHighlighter) {
          page.graphics.save();
          page.graphics.setTransparency(0.35);
          for (int j = 1; j < stroke.points.length; j++) {
            final p1 = Offset(stroke.points[j - 1].dx * scaleX, stroke.points[j - 1].dy * scaleY);
            final p2 = Offset(stroke.points[j].dx * scaleX, stroke.points[j].dy * scaleY);
            page.graphics.drawLine(pdfPen, p1, p2);
          }
          page.graphics.restore();
        } else {
          for (int j = 1; j < stroke.points.length; j++) {
            final p1 = Offset(stroke.points[j - 1].dx * scaleX, stroke.points[j - 1].dy * scaleY);
            final p2 = Offset(stroke.points[j].dx * scaleX, stroke.points[j].dy * scaleY);
            page.graphics.drawLine(pdfPen, p1, p2);
          }
        }
      }

      onProgress?.call(0.1 + (0.8 * (i + 1) / math.max(1, totalDocPages)));
    }
  }

  // ── Save All Modifications to PDF File (Pixel-Perfect Scaling & Real Annotations) ──
  Future<bool> saveModifications(
    BuildContext context, {
    bool overwriteOriginal = false,
    String? customOutputName,
  }) async {
    if (filePath.isEmpty) return false;

    if (strokes.isEmpty && stamps.isEmpty) {
      AppToast.showInfo('لا توجد تعديلات لحفظها');
      return false;
    }

    try {
      isSaving.value = true;
      saveProgress.value = 0.1;

      final srcBytes = await File(filePath.value).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: srcBytes);
      await applyModificationsToDocument(
        doc,
        onProgress: (pVal) => saveProgress.value = pVal,
      );

      final savedBytes = doc.saveSync();
      doc.dispose();

      String targetPath;
      if (overwriteOriginal) {
        targetPath = filePath.value;
      } else {
        final targetDir = await PdfToolsService().getOutputDir(subFolder: 'AuraPDF');
        final base = p.basenameWithoutExtension(filePath.value);
        final desiredName = (customOutputName != null && customOutputName.trim().isNotEmpty)
            ? customOutputName.trim()
            : '${base}_edited_${DateTime.now().millisecondsSinceEpoch % 10000}';
        targetPath = PdfToolsService().generateSafeFilePath(targetDir, desiredName, '.pdf');
      }

      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(savedBytes);
      await PdfToolsService.notifyMediaStore(targetPath);
      saveProgress.value = 1.0;
      hasUnsavedChanges.value = false;

      exitActiveTool();

      if (context.mounted) {
        ToolResultSheet.show(
          context,
          title: 'تم حفظ تعديلات المستند بنجاح',
          result: ToolTaskResult(
            isSuccess: true,
            outputFiles: [targetFile],
            message: overwriteOriginal
                ? 'تم تحديث الملف الأصلي بنجاح'
                : 'تم حفظ المستند المعدل في مجلد Download/AuraPDF بنجاح',
          ),
        );
      }
      return true;
    } catch (e) {
      AppToast.showError('تعذر حفظ التعديلات: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}

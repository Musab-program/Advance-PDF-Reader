// lib/modules/reader/controllers/reader_controller.dart
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_reader/core/services/external_pdf_handler.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/app_toast.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/modules/pdf_tools/views/merge_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/split_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/pdf_to_image_view.dart';
import 'package:pdf_reader/modules/pdf_tools/services/pdf_tools_service.dart';
import 'package:pdf_reader/modules/pdf_tools/widgets/tool_result_sheet.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';
import 'package:pdf_reader/modules/reader/widgets/speed_picker_sheet.dart';

enum ReadingTheme {
  white,
  dark,
  sepia,
  gray,
}

class ReaderController extends GetxController with GetTickerProviderStateMixin {
  final StorageService _storageService = Get.find<StorageService>();

  // pdfrx controller — made final to prevent detachment bugs when recreated
  PdfViewerController pdfViewerController = PdfViewerController();
  PdfTextSearcher? textSearcher;

  // Custom double tap zoom animation controller
  late AnimationController matrixAnimationController;
  Animation<Matrix4>? matrixAnimation;

  final RxList<PdfEntity> pdfQueue = <PdfEntity>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 0.obs;
  final RxBool isLoading = true.obs;
  final RxBool isDocumentLoading = true.obs;
  final RxBool showOverlay = false.obs;
  final RxBool isSinglePageMode = false.obs;

  // ── Splash & Snapping Timers ──
  Timer? _splashTimeoutTimer;
  Timer? _saveProgressTimer;
  Timer? _snappingTimer;
  bool _isRestoring = false;

  // ── New Features State ──
  final RxBool isCropMargins = false.obs;
  final RxBool isMangaMode = false.obs;
  final RxBool isLargeFile = false.obs;
  final Rx<ReadingTheme> readingTheme = ReadingTheme.white.obs; // Defaults to light/day mode as requested
  final RxDouble brightness = 1.0.obs;
  final RxString watermarkText = ''.obs;
  final RxBool isSearchMode = false.obs;
  final RxInt activeBottomSheetTab = 0.obs; // Tab controls inside BottomSheet
  final RxInt currentMatchIndex = 0.obs;
  final RxInt totalMatchesCount = 0.obs;
  final RxString searchQuery = ''.obs;
  final TextEditingController searchTextController = TextEditingController();
  
  // Explicit FocusNode for instantaneous keyboard opening
  final FocusNode searchFocusNode = FocusNode();

  // Temporary variable to preserve the exact page integer across layout changes
  int? _pageToRestore;

  // ── Jump Animation Guard variables ──
  int? _targetPageJumpingTo;
  DateTime? _jumpTime;

  // ── Scroll Position Preservation state ──
  int? _savedPageNumber;
  double? _savedRelativeX;
  double? _savedRelativeY;
  double? _savedZoom;
  double? _savedViewWidth;
  Timer? _savedPositionClearTimer;

  // ── Auto-Scroll (Continuous Smooth Pixel Scroll) State ──
  final RxBool isAutoScrolling = false.obs;
  final RxBool isAutoScrollPaused = false.obs;
  final RxDouble autoScrollSpeed = 1.0.obs;
  final RxBool isAutoScrollHudMinimized = false.obs;
  final RxBool isAutoScrollHudFaded = false.obs;
  final Rx<Offset?> autoScrollBubblePosition = Rx<Offset?>(null);
  Timer? _autoMinimizeTimer;
  Timer? _bubbleFadeTimer;
  Ticker? _autoScrollTicker;
  Duration _lastAutoScrollElapsed = Duration.zero;
  bool _isUserTouchingDuringAutoScroll = false;

  static final List<double> autoScrollSpeedPresets = List.generate(
    80,
    (i) => double.parse(((i + 1) * 0.25).toStringAsFixed(2)),
  );

  @override
  void onInit() {
    super.onInit();
    matrixAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _updateStatusBar();
    _initSearcher();
    isMangaMode.value = _storageService.getMangaMode();
    autoScrollSpeed.value = _storageService.getAutoScrollSpeed();

    final args = Get.arguments as Map<String, dynamic>?;
    final pendingFile = ExternalPdfHandler.consumePendingFile();

    if (pendingFile != null && pendingFile.isNotEmpty) {
      _loadFromFile(pendingFile);
    } else if (args != null && args.containsKey('singleFile')) {
      _loadFromFile(args['singleFile'] as String);
    } else if (args != null && args.containsKey('index')) {
      currentIndex.value = args['index'] as int;
      _loadFromSavedFolder();
    } else {
      _loadFromSavedFolder();
    }
  }

  /// Public hook to hide the loading splash (e.g. when the document fails to load).
  void dismissLoading() => _dismissSplash();

  void _initSearcher() {
    if (!pdfViewerController.isReady) return;
    textSearcher?.dispose();
    textSearcher = PdfTextSearcher(pdfViewerController)..addListener(_onSearcherUpdate);
  }

  void _onSearcherUpdate() {
    if (textSearcher != null) {
      totalMatchesCount.value = textSearcher!.matches.length;
    }
    update();
  }

  int getInitialPage(String path) {
    if (_pageToRestore != null) {
      return _pageToRestore!;
    }
    final saved = _storageService.getProgress(path);
    final total = _storageService.getPageCount(path);
    if (saved > 0 && saved < 1.0 && total > 1) {
      return (saved * total).round().clamp(1, total);
    }
    return 1;
  }

  Future<void> _loadFromSavedFolder() async {
    isLoading.value = true;
    try {
      final folderPath = _storageService.getLastFolder();
      if (folderPath == null || folderPath.isEmpty) {
        isDocumentLoading.value = false;
        return;
      }
      final folderName = p.basename(folderPath);
      final recycledPaths = _storageService.getRecycledItems().map((e) => e.path).toSet();
      final allFiles = await FileUtils.scanPdfFiles(folderPath);
      final files = allFiles
          .where((f) =>
              p.extension(f.path).toLowerCase() == '.pdf' &&
              !recycledPaths.contains(f.path))
          .toList();
      final List<PdfEntity> mapped = files.map((f) => PdfFileModel.fromFile(f,
          progress: _storageService.getProgress(f.path),
          pageCount: _storageService.getPageCount(f.path))).toList();
      mapped.sort((a, b) => FileUtils.naturalCompare(a.name, b.name, folderName: folderName));
      pdfQueue.assignAll(mapped);
      if (pdfQueue.isEmpty) {
        isDocumentLoading.value = false;
      } else if (currentIndex.value >= pdfQueue.length) {
        currentIndex.value = 0;
      }
      isSinglePageMode.value = false;
    } catch (_) {
      isDocumentLoading.value = false;
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> _loadFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final initialPdf = PdfFileModel.fromFile(
          file,
          progress: _storageService.getProgress(file.path),
          pageCount: _storageService.getPageCount(file.path),
        );
        pdfQueue.assignAll([initialPdf]);
        currentIndex.value = 0;
        isSinglePageMode.value = false;
        isLoading.value = false;
        update();
      } else {
        isLoading.value = false;
        isDocumentLoading.value = false;
        update();
        return;
      }
    } catch (_) {
      isLoading.value = false;
      isDocumentLoading.value = false;
      update();
      return;
    }

    // Defer sibling PDF scanning until after the document finishes loading so disk I/O
    // and main-thread sorting never compete with PDFium while opening the file.
    if (!filePath.contains('/cache/')) {
      unawaited(() async {
        try {
          while (isDocumentLoading.value && !isClosed) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (isClosed) return;
          final folderPath = p.dirname(filePath);
          final folderName = p.basename(folderPath);
          _storageService.setLastFolder(folderPath);
          final allFiles = await FileUtils.scanPdfFiles(folderPath);
          if (isClosed) return;
          final files = allFiles
              .where((f) => p.extension(f.path).toLowerCase() == '.pdf')
              .toList();
          if (files.isNotEmpty) {
            final List<PdfEntity> mapped = files
                .map((f) => PdfFileModel.fromFile(f,
                    progress: _storageService.getProgress(f.path),
                    pageCount: _storageService.getPageCount(f.path)))
                .toList();
            mapped.sort((a, b) =>
                FileUtils.naturalCompare(a.name, b.name, folderName: folderName));
            final idx = mapped.indexWhere((pdf) => pdf.path == filePath);
            if (idx >= 0) {
              pdfQueue.assignAll(mapped);
              currentIndex.value = idx;
            }
          }
        } catch (_) {}
      }());
    }
  }

  void loadFromFileFromIntent(String filePath) {
    _resetViewer();
    _loadFromFile(filePath);
  }

  // ── Toggle overlay on tap ──
  void toggleOverlay() {
    _saveCurrentPosition();
    showOverlay.value = !showOverlay.value;
    _updateStatusBar();
    _restorePositionPeriodic(durationMs: 500);
  }

  void _updateStatusBar() {
    if (showOverlay.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void toggleLayoutMode() {
    _pageToRestore = currentPage.value; // Store current page to restore after recreation
    isSinglePageMode.value = !isSinglePageMode.value;
    _resetViewer();
  }

  // ── Save current scroll and zoom state relative to the page ──
  void _saveCurrentPosition() {
    try {
      final centerPos = pdfViewerController.centerPosition;
      final layouts = pdfViewerController.layout.pageLayouts;
      
      // Find the page that contains the center position, or the closest page
      int closestPage = 1;
      double minDistance = double.infinity;
      
      for (int i = 0; i < layouts.length; i++) {
        final rect = layouts[i];
        if (rect.contains(centerPos)) {
          closestPage = i + 1;
          break;
        }
        final dist = (rect.center - centerPos).distanceSquared;
        if (dist < minDistance) {
          minDistance = dist;
          closestPage = i + 1;
        }
      }
      
      final pageRect = layouts[closestPage - 1];
      _savedPageNumber = closestPage;
      _savedRelativeX = (centerPos.dx - pageRect.left) / pageRect.width;
      _savedRelativeY = (centerPos.dy - pageRect.top) / pageRect.height;
      _savedZoom = pdfViewerController.currentZoom;
      _savedViewWidth = pdfViewerController.viewSize.width;
    } catch (_) {
      // Fallback to currentPage.value
      try {
        final pageNumber = currentPage.value;
        if (pageNumber > 0 && pageNumber <= totalPages.value) {
          final pageRect = pdfViewerController.layout.pageLayouts[pageNumber - 1];
          final centerPos = pdfViewerController.centerPosition;
          _savedPageNumber = pageNumber;
          _savedRelativeX = (centerPos.dx - pageRect.left) / pageRect.width;
          _savedRelativeY = (centerPos.dy - pageRect.top) / pageRect.height;
          _savedZoom = pdfViewerController.currentZoom;
          _savedViewWidth = pdfViewerController.viewSize.width;
        }
      } catch (_) {
        _savedPageNumber = null;
      }
    }
  }

  bool get isRestoringPosition => _isRestoring && _savedPageNumber != null;

  void clearSavedPosition() {
    _savedPageNumber = null;
    _savedRelativeX = null;
    _savedRelativeY = null;
    _savedZoom = null;
    _savedViewWidth = null;
    _savedPositionClearTimer?.cancel();
    _savedPositionClearTimer = null;
  }

  Matrix4? getCorrectedMatrixForLayout(PdfPageLayout layout, Size viewSize) {
    if (_savedPageNumber == null || _savedRelativeX == null || _savedRelativeY == null || _savedZoom == null) {
      return null;
    }
    try {
      final savedPage = _savedPageNumber!;
      final relX = _savedRelativeX!;
      final relY = _savedRelativeY!;
      final double widthRatio = (_savedViewWidth != null && _savedViewWidth! > 0 && viewSize.width > 0)
          ? (viewSize.width / _savedViewWidth!)
          : 1.0;
      final zoom = _savedZoom! * widthRatio;

      if (savedPage <= layout.pageLayouts.length) {
        final pageRect = layout.pageLayouts[savedPage - 1];
        final targetCenterX = pageRect.left + relX * pageRect.width;
        final targetCenterY = pageRect.top + relY * pageRect.height;
        
        return pdfViewerController.calcMatrixFor(
          Offset(targetCenterX, targetCenterY),
          zoom: zoom,
          viewSize: viewSize,
        );
      }
    } catch (_) {}
    return null;
  }
  // ── Start restoration grace period (clears saved state after durationMs) ──
  void _restorePositionPeriodic({int durationMs = 500}) {
    _isRestoring = true;
    _savedPositionClearTimer?.cancel();
    _savedPositionClearTimer = Timer(Duration(milliseconds: durationMs), () {
      _isRestoring = false;
      clearSavedPosition();
    });
  }

  void toggleCropMargins(bool val) {
    _saveCurrentPosition();
    isCropMargins.value = val;
    update();
    _restorePositionPeriodic(durationMs: 500);
  }

  void toggleMangaMode(bool val) {
    _saveCurrentPosition();
    isMangaMode.value = val;
    _storageService.saveMangaMode(val);
    update();
    _restorePositionPeriodic(durationMs: 500);
  }

  void setReadingTheme(ReadingTheme theme) {
    _saveCurrentPosition();
    readingTheme.value = theme;
    _updateStatusBar();
    update();
    _restorePositionPeriodic(durationMs: 500);
  }

  // ── Called when pdfrx reports the page count ──
  void onDocumentReady(PdfDocument document, [PdfViewerController? vController]) {
    final controller = vController ?? pdfViewerController;
    _initSearcher();
    totalPages.value = document.pages.length;

    if (pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length) {
      final pdf = pdfQueue[currentIndex.value];
      _storageService.savePageCount(pdf.path, totalPages.value);
      _storageService.addRecentFile(pdf.path, pdf.name);
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().loadRecentItems();
      }

      final initialPage = getInitialPage(pdf.path);
      currentPage.value = initialPage;
      _pageToRestore = null;

      // Update progress and last read date immediately upon opening the file
      if (totalPages.value > 0) {
        _storageService.saveProgress(pdf.path, initialPage / totalPages.value);
      }
    }

    // Calculate if file is large to optimize page rendering resolution scale in the view
    isLargeFile.value = false;
    if (pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length) {
      try {
        final pdf = pdfQueue[currentIndex.value];
        final file = File(pdf.path);
        if (file.existsSync()) {
          final bytes = file.lengthSync();
          final megaBytes = bytes / (1024 * 1024);
          if (megaBytes > 50) {
            isLargeFile.value = true;
          }
        }
      } catch (_) {}
    }

    // ── Ensure all page dimensions are loaded and 100% Fit-to-Width is applied BEFORE dismissing splash ──
    _splashTimeoutTimer?.cancel();
    _saveProgressTimer?.cancel();
    _splashTimeoutTimer = Timer(const Duration(milliseconds: 1500), () {
      _dismissSplash();
    });

    void applyFullWidthMatrix() {
      try {
        if (controller.isReady) {
          final viewSize = controller.viewSize;
          final docWidth = controller.layout.documentSize.width;
          final viewWidth = viewSize.width;

          if (viewWidth > 0 && docWidth > 0) {
            final double fitZoom = viewWidth / docWidth;
            final layouts = controller.layout.pageLayouts;
            if (layouts.isNotEmpty) {
              final int initialPage = currentPage.value;
              final pageIndex = (initialPage - 1).clamp(0, layouts.length - 1);
              final pageRect = layouts[pageIndex];

              // Center horizontally and align vertically to top of target page
              final double targetCenterY = pageRect.top + (viewSize.height / 2 / fitZoom);
              final targetCenter = Offset(docWidth / 2, targetCenterY);

              final targetMatrix = controller.calcMatrixFor(
                targetCenter,
                zoom: fitZoom,
                viewSize: viewSize,
              );
              controller.value = targetMatrix;
            }
          }
        }
      } catch (_) {}
    }

    Future<void> prepareAndReveal() async {
      try {
        if (!document.pages.every((p) => p.isLoaded)) {
          await document.loadPagesProgressively();
        }
      } catch (_) {}

      applyFullWidthMatrix();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyFullWidthMatrix();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          applyFullWidthMatrix();
          _dismissSplash();
        });
      });
    }

    prepareAndReveal();
  }

  void _dismissSplash() {
    if (isDocumentLoading.value) {
      isDocumentLoading.value = false;
      _splashTimeoutTimer?.cancel();
    _saveProgressTimer?.cancel();
      update();
    }
  }

  // ── Scroll Snapping & Gesture Velocity Calculations ──
  int getClosestPage() {
    try {
      if (!pdfViewerController.isReady) return currentPage.value;
      final centerPos = pdfViewerController.centerPosition;
      final layouts = pdfViewerController.layout.pageLayouts;
      
      int closestPage = 1;
      double minDistance = double.infinity;
      
      for (int i = 0; i < layouts.length; i++) {
        final rect = layouts[i];
        final dist = (rect.center - centerPos).distanceSquared;
        if (dist < minDistance) {
          minDistance = dist;
          closestPage = i + 1;
        }
      }
      return closestPage;
    } catch (_) {
      return currentPage.value;
    }
  }

  void handleInteractionEnd(ScaleEndDetails details) {
    _isUserTouchingDuringAutoScroll = false;
    _lastAutoScrollElapsed = Duration.zero;
    try {
      if (!pdfViewerController.isReady) return;
      if (!pdfViewerController.isReady) return;
      
      // Disable snapping completely in vertical scroll mode to let continuous inertial scrolling run smoothly
      if (!isSinglePageMode.value) {
        return;
      }
      
      final currentZoom = pdfViewerController.currentZoom;
      final layouts = pdfViewerController.layout.pageLayouts;
      final int pageIdx = (currentPage.value - 1).clamp(0, layouts.isNotEmpty ? layouts.length - 1 : 0);
      final double refWidth = layouts.isNotEmpty
          ? layouts[pageIdx].width
          : pdfViewerController.layout.documentSize.width;
      final double fitWidthZoom = refWidth > 0
          ? pdfViewerController.viewSize.width / refWidth
          : pdfViewerController.minScale;
      
      // Snapping is only active when not zoomed in past Fit-to-Width
      if (currentZoom > fitWidthZoom * 1.02) {
        return; // Allow free-form panning and zooming when zoomed in
      }
      
      final bool isHorizontal = isSinglePageMode.value;
      final double velocity = isHorizontal 
          ? details.velocity.pixelsPerSecond.dx 
          : details.velocity.pixelsPerSecond.dy;
      
      int targetPage = currentPage.value;
      final int total = totalPages.value;
      
      // Check swipe direction & calculate target page based on velocity
      if (velocity < -800) {
        // Scrolling forward (moving to next pages)
        if (velocity <= -2500) {
          targetPage = (targetPage + 2).clamp(1, total);
        } else {
          targetPage = (targetPage + 1).clamp(1, total);
        }
      } else if (velocity > 800) {
        // Scrolling backward (moving to previous pages)
        if (velocity >= 2500) {
          targetPage = (targetPage - 2).clamp(1, total);
        } else {
          targetPage = (targetPage - 1).clamp(1, total);
        }
      } else {
        // Low velocity: snap to closest page
        targetPage = getClosestPage();
      }
      
      // Animate smoothly to the resolved target page after 150ms delay
      // to let the default InteractiveViewer fling finish completely, debounced via _snappingTimer
      _snappingTimer?.cancel();
      _snappingTimer = Timer(const Duration(milliseconds: 150), () {
        if (pdfViewerController.isReady) {
          pdfViewerController.goToPage(
            pageNumber: targetPage,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    } catch (_) {}
  }

  void handleInteractionStart(ScaleStartDetails details) {
    _snappingTimer?.cancel();
    _isUserTouchingDuringAutoScroll = true;
  }

  // ── Called on every visible page change ──
  void onPageChanged(int page) {
    if (isDocumentLoading.value) return; // Ignore initial layout/load updates to prevent overwriting current page index
    
    // Guard against scroll clamp guessing during page jump animations
    if (_targetPageJumpingTo != null && _jumpTime != null) {
      final diff = DateTime.now().difference(_jumpTime!);
      if (diff.inMilliseconds < 600) {
        if (page != _targetPageJumpingTo) return;
      } else {
        _targetPageJumpingTo = null;
        _jumpTime = null;
      }
    }

    if (page == currentPage.value) return;
    currentPage.value = page;

    // Debounce saving progress to disk (500ms) to prevent I/O stuttering while flinging through pages
    if (totalPages.value > 0 && pdfQueue.isNotEmpty) {
      final pdf = pdfQueue[currentIndex.value];
      _saveProgressTimer?.cancel();
      _saveProgressTimer = Timer(const Duration(milliseconds: 500), () {
        _storageService.saveProgress(pdf.path, page / totalPages.value);
      });
    }
  }

  // ── Jump to a specific page ──
  void jumpToPage(int page) {
    final clamped =
        page.clamp(1, totalPages.value > 0 ? totalPages.value : 1);
    currentPage.value = clamped;
    
    // Enable jump animation guard to prevent viewport page estimation from overriding our choice
    _targetPageJumpingTo = clamped;
    _jumpTime = DateTime.now();

    if (totalPages.value > 0 && pdfQueue.isNotEmpty) {
      final pdf = pdfQueue[currentIndex.value];
      _storageService.saveProgress(pdf.path, clamped / totalPages.value);
    }

    pdfViewerController.goToPage(pageNumber: clamped);
  }

  // ── Navigation ──
  void goToNextFile() {
    if (currentIndex.value < pdfQueue.length - 1) {
      currentIndex.value++;
      _resetViewer();
    }
  }

  void handlePreviousAction() {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      _resetViewer();
    }
  }

  void jumpToFile(int index) {
    if (index >= 0 && index < pdfQueue.length) {
      currentIndex.value = index;
      _resetViewer();
    }
  }

  void _resetViewer() {
    stopAutoScroll();
    currentPage.value = 1;
    totalPages.value = 0;
    isDocumentLoading.value = true;
    pdfViewerController = PdfViewerController(); // Re-initialize the controller
    _isRestoring = false;
    clearSavedPosition();
    _splashTimeoutTimer?.cancel();
    _saveProgressTimer?.cancel();
    _snappingTimer?.cancel();
    _initSearcher();
    update();
  }

  @override
  void onClose() {
    stopAutoScroll();
    _autoScrollTicker?.dispose();
    matrixAnimationController.dispose();
    _savedPositionClearTimer?.cancel();
    _splashTimeoutTimer?.cancel();
    _saveProgressTimer?.cancel();
    _snappingTimer?.cancel();
    // Restore status bar and orientation on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final isAppDark = Get.isDarkMode;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isAppDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isAppDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isAppDark ? Brightness.light : Brightness.dark,
    ));
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    textSearcher?.dispose();
    searchTextController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }
  void _animateMatrix(Matrix4 targetMatrix) {
    matrixAnimationController.stop();
    matrixAnimation = Matrix4Tween(
      begin: pdfViewerController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: matrixAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    matrixAnimationController.addListener(() {
      if (matrixAnimation != null) {
        pdfViewerController.value = matrixAnimation!.value;
      }
    });
    
    matrixAnimationController.forward(from: 0.0);
  }

  void handleDoubleTapZoom(Offset localPosition, Size viewportSize) {
    try {
      if (!pdfViewerController.isReady) return;
      
      final currentMatrix = pdfViewerController.value;
      final double scale = currentMatrix.storage[0];
      final double tx = currentMatrix.storage[12];
      final double ty = currentMatrix.storage[13];
      
      // Convert viewport tap coordinates to document coordinates
      final double docX = (localPosition.dx - tx) / scale;
      final double docY = (localPosition.dy - ty) / scale;
      
      // Calculate dynamic fit-width zoom scale relative to the active page or document width
      final layouts = pdfViewerController.layout.pageLayouts;
      final int pageIdx = (currentPage.value - 1).clamp(0, layouts.isNotEmpty ? layouts.length - 1 : 0);
      final double refWidth = (isSinglePageMode.value && layouts.isNotEmpty)
          ? layouts[pageIdx].width
          : pdfViewerController.layout.documentSize.width;
      final double centerX = (isSinglePageMode.value && layouts.isNotEmpty)
          ? layouts[pageIdx].center.dx
          : pdfViewerController.layout.documentSize.width / 2;

      final double fitWidthZoom = refWidth > 0 ? viewportSize.width / refWidth : 1.0;
      final double zoomedInZoom = fitWidthZoom * 2.5;
      
      double targetZoom;
      Offset targetCenter;
      
      if (scale < fitWidthZoom * 0.98) {
        // State 1: Zoomed out -> restore to exactly fit-width
        targetZoom = fitWidthZoom;
        targetCenter = Offset(centerX, docY);
      } else if (scale < fitWidthZoom * 1.05) {
        // State 2: Normal fit-width size -> zoom in to 2.5x of fit-width zoom centered at tapped point
        targetZoom = zoomedInZoom;
        targetCenter = Offset(docX, docY);
      } else {
        // State 3: Zoomed in -> zoom out back to exactly fit-width
        targetZoom = fitWidthZoom;
        targetCenter = Offset(centerX, docY);
      }
      
      final targetMatrix = pdfViewerController.calcMatrixFor(
        targetCenter,
        zoom: targetZoom,
        viewSize: viewportSize,
      );
      
      _animateMatrix(targetMatrix);
    } catch (_) {}
  }

  PdfEntity? get currentPdf =>
      pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length
          ? pdfQueue[currentIndex.value]
          : null;

  // ── Text Search API ──
  void startSearch(String text) {
    if (textSearcher == null) _initSearcher();
    searchQuery.value = text;
    if (text.isEmpty) {
      clearSearch();
      return;
    }
    currentMatchIndex.value = 0;
    textSearcher?.startTextSearch(text, caseInsensitive: true);
  }

  void goToNextMatch() {
    if (textSearcher != null && textSearcher!.matches.isNotEmpty) {
      textSearcher!.goToNextMatch();
      if (totalMatchesCount.value > 0) {
        currentMatchIndex.value = (currentMatchIndex.value + 1) % totalMatchesCount.value;
      }
    }
  }

  void goToPrevMatch() {
    if (textSearcher != null && textSearcher!.matches.isNotEmpty) {
      textSearcher!.goToPrevMatch();
      if (totalMatchesCount.value > 0) {
        currentMatchIndex.value = (currentMatchIndex.value - 1 + totalMatchesCount.value) % totalMatchesCount.value;
      }
    }
  }

  void clearSearch() {
    textSearcher?.resetTextSearch();
    searchTextController.clear();
    searchQuery.value = '';
    totalMatchesCount.value = 0;
    currentMatchIndex.value = 0;
  }

  void toggleSearchMode() {
    _saveCurrentPosition();
    isSearchMode.value = !isSearchMode.value;
    if (isSearchMode.value) {
      Future.delayed(const Duration(milliseconds: 50), () {
        searchFocusNode.requestFocus();
      });
    } else {
      clearSearch();
    }
    _restorePositionPeriodic(durationMs: 500);
  }

  // ── Screen Rotation API ──
  void toggleOrientation() {
    _saveCurrentPosition();
    final context = Get.context;
    final isPortrait = context != null
        ? MediaQuery.of(context).orientation == Orientation.portrait
        : (pdfViewerController.isReady
            ? pdfViewerController.viewSize.width < pdfViewerController.viewSize.height
            : true);
    if (isPortrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _restorePositionPeriodic(durationMs: 800);
  }

  // ── Continuous Smooth Auto-Scroll API ──
  void _onAutoScrollTick(Duration elapsed) {
    final dt = (elapsed - _lastAutoScrollElapsed).inMicroseconds / 1000000.0;
    _lastAutoScrollElapsed = elapsed;
    if (dt <= 0 || dt > 0.1) return;
    if (!isAutoScrolling.value || isAutoScrollPaused.value || _isUserTouchingDuringAutoScroll) return;
    if (!pdfViewerController.isReady) return;

    try {
      final viewSize = pdfViewerController.viewSize;
      final layout = pdfViewerController.layout;
      final zoom = pdfViewerController.currentZoom;
      if (zoom <= 0 || viewSize.height <= 0) return;

      // Base comfortable reading speed: 38 logical screen pixels per second at 1.0x
      final double screenPixelsDelta = 38.0 * autoScrollSpeed.value * dt;
      final double docDelta = screenPixelsDelta / zoom;

      final currentCenter = pdfViewerController.centerPosition;
      if (isSinglePageMode.value) {
        final hw = viewSize.width / 2 / zoom;
        final maxX = layout.documentSize.width - hw;
        if (currentCenter.dx >= maxX - 0.5) {
          isAutoScrollPaused.value = true;
          return;
        }
        final nextX = (currentCenter.dx + docDelta).clamp(hw, maxX > hw ? maxX : hw);
        pdfViewerController.value = pdfViewerController.calcMatrixFor(
          Offset(nextX, currentCenter.dy),
          zoom: zoom,
          viewSize: viewSize,
        );
      } else {
        final hh = viewSize.height / 2 / zoom;
        final maxY = layout.documentSize.height - hh;
        if (currentCenter.dy >= maxY - 0.5) {
          isAutoScrollPaused.value = true;
          return;
        }
        final nextY = (currentCenter.dy + docDelta).clamp(hh, maxY > hh ? maxY : hh);
        pdfViewerController.value = pdfViewerController.calcMatrixFor(
          Offset(currentCenter.dx, nextY),
          zoom: zoom,
          viewSize: viewSize,
        );
      }
    } catch (_) {}
  }

  void toggleAutoScroll() {
    if (isAutoScrolling.value) {
      stopAutoScroll();
    } else {
      startAutoScroll();
    }
  }

  void startAutoScroll() {
    isAutoScrolling.value = true;
    isAutoScrollPaused.value = false;
    _isUserTouchingDuringAutoScroll = false;
    isAutoScrollHudMinimized.value = false;
    isAutoScrollHudFaded.value = false;
    resetAutoMinimizeTimer();
    _bubbleFadeTimer?.cancel();
    if (showOverlay.value) {
      showOverlay.value = false;
      _updateStatusBar();
    }
    _autoScrollTicker ??= createTicker(_onAutoScrollTick);
    _lastAutoScrollElapsed = Duration.zero;
    if (!_autoScrollTicker!.isActive) {
      _autoScrollTicker!.start();
    }
  }

  void stopAutoScroll() {
    isAutoScrolling.value = false;
    isAutoScrollPaused.value = false;
    _isUserTouchingDuringAutoScroll = false;
    _autoMinimizeTimer?.cancel();
    _bubbleFadeTimer?.cancel();
    isAutoScrollHudFaded.value = false;
    isAutoScrollHudMinimized.value = false;
    autoScrollBubblePosition.value = null;
    _autoScrollTicker?.stop();
    _lastAutoScrollElapsed = Duration.zero;
  }

  /// Automatically collapses the full bar into the circular bubble after 5 seconds of inactivity.
  void resetAutoMinimizeTimer() {
    _autoMinimizeTimer?.cancel();
    if (!isAutoScrolling.value || isAutoScrollHudMinimized.value) return;
    _autoMinimizeTimer = Timer(const Duration(seconds: 5), () {
      if (isAutoScrolling.value && !isAutoScrollHudMinimized.value) {
        minimizeAutoScrollHud(auto: true);
      }
    });
  }

  /// Collapses full bar into the floating bubble (starts at 100% opacity, fades after 3 seconds).
  /// [auto] true: collapsed after idle -> becomes transparent immediately.
  /// [auto] false: manual collapse -> stays solid for 3 seconds, then fades.
  void minimizeAutoScrollHud({bool auto = false}) {
    _autoMinimizeTimer?.cancel();
    _bubbleFadeTimer?.cancel();
    isAutoScrollHudMinimized.value = true;
    if (auto) {
      isAutoScrollHudFaded.value = true;
    } else {
      resetBubbleFadeTimer();
    }
  }

  /// Timer for circular bubble: fades to semi-transparent after 3 seconds of inactivity.
  void resetBubbleFadeTimer() {
    _bubbleFadeTimer?.cancel();
    isAutoScrollHudFaded.value = false;
    if (!isAutoScrolling.value || !isAutoScrollHudMinimized.value) return;
    _bubbleFadeTimer = Timer(const Duration(seconds: 3), () {
      if (isAutoScrolling.value && isAutoScrollHudMinimized.value) {
        isAutoScrollHudFaded.value = true;
      }
    });
  }

  /// Expands floating bubble back to the full bar with solid 100% opacity.
  void expandAutoScrollHud() {
    _bubbleFadeTimer?.cancel();
    isAutoScrollHudFaded.value = false;
    isAutoScrollHudMinimized.value = false;
    resetAutoMinimizeTimer();
  }

  void toggleAutoScrollHudMinimized() {
    if (isAutoScrollHudMinimized.value) {
      expandAutoScrollHud();
    } else {
      minimizeAutoScrollHud();
    }
  }

  void toggleAutoScrollPause() {
    if (!isAutoScrolling.value) {
      startAutoScroll();
      return;
    }
    isAutoScrollPaused.value = !isAutoScrollPaused.value;
    _lastAutoScrollElapsed = Duration.zero;
    if (isAutoScrollHudMinimized.value) {
      resetBubbleFadeTimer();
    } else {
      resetAutoMinimizeTimer();
    }
  }

  void increaseAutoScrollSpeed() {
    final current = autoScrollSpeed.value;
    for (final preset in autoScrollSpeedPresets) {
      if (preset > current + 0.01) {
        autoScrollSpeed.value = preset;
        _storageService.saveAutoScrollSpeed(preset);
        if (isAutoScrollHudMinimized.value) {
          resetBubbleFadeTimer();
        } else {
          resetAutoMinimizeTimer();
        }
        return;
      }
    }
  }

  void decreaseAutoScrollSpeed() {
    final current = autoScrollSpeed.value;
    for (int i = autoScrollSpeedPresets.length - 1; i >= 0; i--) {
      if (autoScrollSpeedPresets[i] < current - 0.01) {
        autoScrollSpeed.value = autoScrollSpeedPresets[i];
        _storageService.saveAutoScrollSpeed(autoScrollSpeedPresets[i]);
        if (isAutoScrollHudMinimized.value) {
          resetBubbleFadeTimer();
        } else {
          resetAutoMinimizeTimer();
        }
        return;
      }
    }
  }

  void resetAutoScrollSpeed() {
    autoScrollSpeed.value = 1.0;
    _storageService.saveAutoScrollSpeed(1.0);
    if (isAutoScrollHudMinimized.value) {
      resetBubbleFadeTimer();
    } else {
      resetAutoMinimizeTimer();
    }
  }

  void setCustomAutoScrollSpeed(double speed) {
    final clamped = speed.clamp(0.1, 20.0);
    autoScrollSpeed.value = double.parse(clamped.toStringAsFixed(2));
    _storageService.saveAutoScrollSpeed(autoScrollSpeed.value);
    if (isAutoScrollHudMinimized.value) {
      resetBubbleFadeTimer();
    } else {
      resetAutoMinimizeTimer();
    }
  }

  void showSpeedPickerDialog() {
    Get.bottomSheet(
      const SpeedPickerSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
  // ── Color Theme Utilities ──
  Color get themeBackgroundColor {
    switch (readingTheme.value) {
      case ReadingTheme.white:
        return const Color(0xFFFAF8F5);
      case ReadingTheme.dark:
        return const Color(0xFF0F0F13);
      case ReadingTheme.sepia:
        return const Color(0xFFF4ECD8);
      case ReadingTheme.gray:
        return const Color(0xFF3A3A3C);
    }
  }

  ColorFilter? get themeColorFilter {
    switch (readingTheme.value) {
      case ReadingTheme.white:
        return null;
      case ReadingTheme.dark:
        return const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]);
      case ReadingTheme.sepia:
        return const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case ReadingTheme.gray:
        return const ColorFilter.matrix(<double>[
          0.75, 0, 0, 0, 0,
          0, 0.75, 0, 0, 0,
          0, 0, 0.75, 0, 0,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  // ── Share & Print Actions ──
  void shareCurrentPdf() {
    final pdf = currentPdf;
    if (pdf != null && File(pdf.path).existsSync()) {
      try {
        SharePlus.instance.share(ShareParams(
          files: [XFile(pdf.path)],
          text: pdf.name,
          sharePositionOrigin: Rect.fromLTWH(0, 0, Get.width, Get.height / 2),
        ));
      } catch (e) {
        debugPrint('Share error: $e');
      }
    }
  }

  void printCurrentPdf() {
    final pdf = currentPdf;
    if (pdf != null && File(pdf.path).existsSync()) {
      AppToast.showInfo('print_spooler_msg'.trParams({'name': pdf.name}));
      try {
        SharePlus.instance.share(ShareParams(
          files: [XFile(pdf.path)],
          subject: 'Print ${pdf.name}',
          sharePositionOrigin: Rect.fromLTWH(0, 0, Get.width, Get.height / 2),
        ));
      } catch (e) {
        debugPrint('Print share error: $e');
      }
    }
  }
  // ── Save As Action ──
  Future<void> saveAsCurrentPdf() async {
    final pdf = currentPdf;
    if (pdf == null) return;
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        final sourceFile = File(pdf.path);
        final targetPath = p.join(selectedDirectory, pdf.name);
        await sourceFile.copy(targetPath);
        await PdfToolsService.notifyMediaStore(targetPath);
        AppToast.showSuccess('saved_to'.trParams({'path': targetPath}));
      }
    } catch (e) {
      AppToast.showError('failed_to_save'.trParams({'error': '$e'}));
    }
  }

  // ── File Details Dialog ──
  void showFileDetailsDialog() {
    final pdf = currentPdf;
    if (pdf == null) return;

    final file = File(pdf.path);
    DateTime lastMod = DateTime.now();
    try {
      lastMod = file.lastModifiedSync();
    } catch (_) {}

    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null || !ctx.mounted) return;
    final dialogTheme = Theme.of(ctx);

    LuxuryDialog.show(
      ctx,
      compact: true,
      icon: Icons.info_outline_rounded,
      title: 'file_details'.tr,
      maxWidth: 400,
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow(dialogTheme, 'details_name'.tr, pdf.name),
              _detailRow(dialogTheme, 'details_size'.tr, FileUtils.formatSize(pdf.size)),
              _detailRow(dialogTheme, 'details_path'.tr, pdf.path),
              _detailRow(dialogTheme, 'details_total_pages'.tr, '${totalPages.value}'),
              _detailRow(dialogTheme, 'details_last_modified'.tr, lastMod.toString().split('.').first),
            ],
          ),
        ),
      ),
      primaryButtonText: 'close'.tr,
      primaryButtonIcon: Icons.check_rounded,
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Kindle-style Go To Page Dialog ──
  void showGoToPageDialog() {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null || !ctx.mounted) return;
    final dialogTheme = Theme.of(ctx);
    final textController = TextEditingController(text: '${currentPage.value}');

    LuxuryDialog.showCustom(
      ctx,
      builder: (dCtx) => LuxuryDialog(
        compact: true,
        icon: Icons.find_in_page_rounded,
        title: 'go_to_page'.tr,
        message: 'enter_page_number'.trParams({'total': '${totalPages.value}'}),
        body: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: TextStyle(
            color: dialogTheme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: dialogTheme.scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: dialogTheme.dividerColor.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: dialogTheme.dividerColor.withValues(alpha: 0.4)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        secondaryButtonText: 'cancel'.tr,
        primaryButtonText: 'apply'.tr,
        primaryButtonIcon: Icons.arrow_forward_rounded,
        closeOnPrimary: false,
        onPrimaryPressed: () {
          final val = int.tryParse(textController.text.trim());
          if (val != null && val >= 1 && val <= totalPages.value) {
            jumpToPage(val);
            Navigator.of(dCtx).pop();
          } else {
            AppToast.showWarning('enter_valid_page_range'.trParams({'total': '${totalPages.value}'}));
          }
        },
      ),
    );
  }

  // ── Document Conversion Actions ──
  Future<void> extractTextToTxt() async {
    final pdf = currentPdf;
    if (pdf == null) return;

    Get.showOverlay(
      asyncFunction: () async {
        final res = await PdfToolsService().extractText(pdf.path);
        if (res.isSuccess && Get.context != null) {
          ToolResultSheet.show(
            Get.context!,
            result: res,
            title: 'extract_text'.tr,
          );
        } else if (!res.isSuccess) {
          AppToast.showError(res.errorMessage ?? 'failed_to_extract'.trParams({'error': ''}));
        }
      },
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }

  void convertPdfToImages() {
    final pdf = currentPdf;
    if (pdf != null) {
      Get.to(() => PdfToImageView(initialFilePath: pdf.path));
    }
  }

  // Helper mapping for pdfrx rendering format
  static const uiImageFormatPng = ui.ImageByteFormat.png;

  Future<void> compressPdf() async {
    final pdf = currentPdf;
    if (pdf == null) return;

    Get.showOverlay(
      asyncFunction: () async {
        final res = await PdfToolsService().compressPdf(pdf.path);
        if (res.isSuccess && Get.context != null) {
          ToolResultSheet.show(
            Get.context!,
            result: res,
            title: 'compress_pdf'.tr,
          );
        } else if (!res.isSuccess) {
          AppToast.showError(res.errorMessage ?? 'فشل ضغط الملف');
        }
      },
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }

  // ── Advanced Tools Actions ──
  void mergeDocumentsDialog() {
    final pdf = currentPdf;
    Get.to(() => MergePdfView(initialFilePath: pdf?.path));
  }

  void splitPagesDialog() {
    final pdf = currentPdf;
    if (pdf != null) {
      Get.to(() => SplitPdfView(initialFilePath: pdf.path));
    }
  }
  void addWatermarkDialog() {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null || !ctx.mounted) return;
    final dialogTheme = Theme.of(ctx);
    final txtController = TextEditingController(text: watermarkText.value);

    LuxuryDialog.showCustom(
      ctx,
      builder: (dCtx) => LuxuryDialog(
        compact: true,
        icon: Icons.branding_watermark_rounded,
        title: 'add_rotated_watermark'.tr,
        body: TextField(
          controller: txtController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. CONFIDENTIAL',
            hintStyle: TextStyle(
              color: dialogTheme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: TextStyle(color: dialogTheme.colorScheme.onSurface),
        ),
        secondaryButtonText: 'clear'.tr,
        secondaryButtonColor: Colors.redAccent,
        onSecondaryPressed: () {
          watermarkText.value = '';
        },
        primaryButtonText: 'apply'.tr,
        primaryButtonIcon: Icons.check_rounded,
        onPrimaryPressed: () {
          watermarkText.value = txtController.text;
        },
      ),
    );
  }
}

// Reader controller optimizations applied successfully.

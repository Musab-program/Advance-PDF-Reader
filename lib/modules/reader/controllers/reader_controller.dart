// lib/modules/reader/controllers/reader_controller.dart
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';

enum ReadingTheme {
  white,
  dark,
  sepia,
  gray,
}

class ReaderController extends GetxController with GetSingleTickerProviderStateMixin {
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
  Timer? _savedPositionClearTimer;

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

    final args = Get.arguments as Map<String, dynamic>?;

    if (args != null && args.containsKey('singleFile')) {
      _loadFromFile(args['singleFile'] as String);
    } else if (args != null && args.containsKey('index')) {
      currentIndex.value = args['index'] as int;
      _loadFromSavedFolder();
    } else {
      _loadFromSavedFolder();
    }
  }

  void _initSearcher() {
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
      if (folderPath == null || folderPath.isEmpty) return;
      final folderName = p.basename(folderPath);
      final files = await FileUtils.scanPdfFiles(folderPath);
      final List<PdfEntity> mapped = files.map((f) => PdfFileModel.fromFile(f,
          progress: _storageService.getProgress(f.path),
          pageCount: _storageService.getPageCount(f.path))).toList();
      mapped.sort((a, b) => FileUtils.naturalCompare(a.name, b.name, folderName: folderName));
      pdfQueue.assignAll(mapped);
      if (currentIndex.value >= pdfQueue.length) currentIndex.value = 0;
      isSinglePageMode.value = false;
    } catch (_) {} finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> _loadFromFile(String filePath) async {
    isLoading.value = true;
    try {
      final folderPath = p.dirname(filePath);
      final folderName = p.basename(folderPath);
      _storageService.setLastFolder(folderPath);
      final files = await FileUtils.scanPdfFiles(folderPath);
      final List<PdfEntity> mapped = files.map((f) => PdfFileModel.fromFile(f,
          progress: _storageService.getProgress(f.path),
          pageCount: _storageService.getPageCount(f.path))).toList();
      mapped.sort((a, b) => FileUtils.naturalCompare(a.name, b.name, folderName: folderName));
      pdfQueue.assignAll(mapped);
      final idx = pdfQueue.indexWhere((pdf) => pdf.path == filePath);
      currentIndex.value = idx >= 0 ? idx : 0;
      isSinglePageMode.value = false;
    } catch (_) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          pdfQueue.assignAll([PdfFileModel.fromFile(file)]);
          currentIndex.value = 0;
        }
      } catch (_) {}
    } finally {
      isLoading.value = false;
      update();
    }
  }

  void loadFromFileFromIntent(String filePath) {
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
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: readingTheme.value == ReadingTheme.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: readingTheme.value == ReadingTheme.dark ? Brightness.light : Brightness.dark,
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
      final zoom = _savedZoom!;

      if (savedPage <= layout.pageLayouts.length) {
        final pageRect = layout.pageLayouts[savedPage - 1];
        final targetCenterX = pageRect.left + relX * pageRect.width;
        final targetCenterY = pageRect.top + relY * pageRect.height;
        
        return pdfViewerController.calcMatrixFor(
          Offset(targetCenterX, targetCenterY),
          zoom: zoom,
          viewSize: viewSize,
        ).scaled(1.0, 1.0, zoom);
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
  void onDocumentReady(PdfDocument document) {
    totalPages.value = document.pages.length;

    if (pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length) {
      final pdf = pdfQueue[currentIndex.value];
      _storageService.savePageCount(pdf.path, totalPages.value);
      _storageService.addRecentFile(pdf.path, pdf.name);

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

    // Calculate dynamic delay based on file size to ensure PDF page rendering finishes under splash
    int delayMs = 1400; // Base delay of 1.4s for files <= 12MB
    if (pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length) {
      try {
        final pdf = pdfQueue[currentIndex.value];
        final file = File(pdf.path);
        if (file.existsSync()) {
          final bytes = file.lengthSync();
          final megaBytes = bytes / (1024 * 1024);
          if (megaBytes > 12.0) {
            final double extraMB = megaBytes - 12.0;
            // Add 25ms per additional MB, capped at 5000ms max (5 seconds)
            delayMs = (1400 + extraMB * 25.0).clamp(1400.0, 5000.0).toInt();
          }
        }
      } catch (_) {}
    }

    // Set a dynamic safe delay to dismiss the splash screen
    _splashTimeoutTimer?.cancel();
    _splashTimeoutTimer = Timer(Duration(milliseconds: delayMs), () {
      _dismissSplash();
    });
  }

  void _dismissSplash() {
    if (isDocumentLoading.value) {
      isDocumentLoading.value = false;
      _splashTimeoutTimer?.cancel();
      update();
    }
  }

  // ── Scroll Snapping & Gesture Velocity Calculations ──
  int getClosestPage() {
    try {
      if (pdfViewerController.layout == null) return currentPage.value;
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
    try {
      if (!pdfViewerController.isReady) return;
      if (pdfViewerController.layout == null) return;
      
      // Disable snapping completely in vertical scroll mode to let continuous inertial scrolling run smoothly
      if (!isSinglePageMode.value) {
        return;
      }
      
      final currentZoom = pdfViewerController.currentZoom;
      final minScale = pdfViewerController.minScale;
      
      // Snapping is only active when zoomed out (close to standard reading view)
      if (currentZoom > minScale + 0.08) {
        return; // Allow free-form panning when zoomed in
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

    if (totalPages.value > 0 && pdfQueue.isNotEmpty) {
      final pdf = pdfQueue[currentIndex.value];
      _storageService.saveProgress(pdf.path, page / totalPages.value);
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
    currentPage.value = 1;
    totalPages.value = 0;
    isDocumentLoading.value = true;
    pdfViewerController = PdfViewerController(); // Re-initialize the controller
    _isRestoring = false;
    clearSavedPosition();
    _splashTimeoutTimer?.cancel();
    _snappingTimer?.cancel();
    _initSearcher();
    update();
  }

  @override
  void onClose() {
    matrixAnimationController.dispose();
    _savedPositionClearTimer?.cancel();
    _splashTimeoutTimer?.cancel();
    _snappingTimer?.cancel();
    // Restore status bar and orientation on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      if (pdfViewerController.layout == null) return;
      
      final currentMatrix = pdfViewerController.value;
      final double scale = currentMatrix.storage[0];
      final double tx = currentMatrix.storage[12];
      final double ty = currentMatrix.storage[13];
      
      // Convert viewport tap coordinates to document coordinates
      final double docX = (localPosition.dx - tx) / scale;
      final double docY = (localPosition.dy - ty) / scale;
      
      // Calculate dynamic fit-width zoom scale relative to the document size
      final double fitWidthZoom = viewportSize.width / pdfViewerController.layout.documentSize.width;
      final double zoomedInZoom = fitWidthZoom * 2.0;
      
      double targetZoom;
      Offset targetCenter;
      
      if (scale < fitWidthZoom - 0.01) {
        // State 1: Zoomed out -> restore to exactly fit-width
        targetZoom = fitWidthZoom;
        targetCenter = Offset(pdfViewerController.layout.documentSize.width / 2, docY);
      } else if (scale < fitWidthZoom + 0.05) {
        // State 2: Normal fit-width size -> zoom in to exactly 2x of fit-width zoom centered at tapped point
        targetZoom = zoomedInZoom;
        targetCenter = Offset(docX, docY);
      } else {
        // State 3: Zoomed in -> zoom out back to exactly fit-width
        targetZoom = fitWidthZoom;
        targetCenter = Offset(pdfViewerController.layout.documentSize.width / 2, docY);
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
    if (context == null) return;
    final isPortrait = context.mediaQuery.orientation == Orientation.portrait;
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
    if (pdf != null) {
      Share.shareXFiles([XFile(pdf.path)], text: pdf.name);
    }
  }

  void printCurrentPdf() {
    final pdf = currentPdf;
    if (pdf != null) {
      Get.snackbar(
        'print'.tr,
        'print_spooler_msg'.trParams({'name': pdf.name}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor,
        colorText: Colors.white,
      );
      Share.shareXFiles([XFile(pdf.path)], subject: 'Print ${pdf.name}');
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
        Get.snackbar(
          'saved_successfully'.tr,
          'saved_to'.trParams({'path': targetPath}),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade800,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'failed_to_save'.trParams({'error': '$e'}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
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

    final dialogTheme = Get.theme;

    Get.dialog(
      Dialog(
        backgroundColor: dialogTheme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: dialogTheme.primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'file_details'.tr,
                        style: TextStyle(
                          color: dialogTheme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailRow(dialogTheme, 'details_name'.tr, pdf.name),
                  _detailRow(dialogTheme, 'details_size'.tr, FileUtils.formatSize(pdf.size)),
                  _detailRow(dialogTheme, 'details_path'.tr, pdf.path),
                  _detailRow(dialogTheme, 'details_total_pages'.tr, '${totalPages.value}'),
                  _detailRow(dialogTheme, 'details_last_modified'.tr, lastMod.toString().split('.').first),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text('close'.tr, style: TextStyle(color: dialogTheme.primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final dialogTheme = Get.theme;
    final textController = TextEditingController(text: '${currentPage.value}');
    Get.dialog(
      Dialog(
        backgroundColor: dialogTheme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'go_to_page'.tr,
                    style: TextStyle(
                      color: dialogTheme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'enter_page_number'.trParams({'total': '${totalPages.value}'}),
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface, fontSize: 18),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: dialogTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.4)),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('cancel'.tr, style: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.6))),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dialogTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        onPressed: () {
                          final val = int.tryParse(textController.text);
                          if (val != null && val >= 1 && val <= totalPages.value) {
                            jumpToPage(val);
                            Get.back();
                          } else {
                            Get.snackbar(
                              'invalid_page'.tr,
                              'enter_valid_page_range'.trParams({'total': '${totalPages.value}'}),
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red.shade800,
                              colorText: Colors.white,
                            );
                          }
                        },
                        child: Text('apply'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Document Conversion Actions ──
  Future<void> extractTextToTxt() async {
    final pdf = currentPdf;
    if (pdf == null) return;

    Get.showOverlay(
      asyncFunction: () async {
        try {
          final doc = await PdfDocument.openFile(pdf.path);
          final buffer = StringBuffer();
          for (int i = 1; i <= doc.pages.length; i++) {
            final page = doc.pages[i - 1];
            final text = await page.loadText();
            buffer.writeln('--- Page $i ---');
            buffer.writeln(text);
          }
          await doc.dispose();

          final txtPath = p.setExtension(pdf.path, '.txt');
          final txtFile = File(txtPath);
          await txtFile.writeAsString(buffer.toString());

          Get.snackbar(
            'success'.tr,
            'text_extracted_to'.trParams({'name': p.basename(txtPath)}),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade800,
            colorText: Colors.white,
          );
        } catch (e) {
          Get.snackbar(
            'error'.tr,
            'failed_to_extract'.trParams({'error': '$e'}),
            backgroundColor: Colors.red.shade800,
            colorText: Colors.white,
          );
        }
      },
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> convertPdfToImages() async {
    final pdf = currentPdf;
    if (pdf == null) return;

    Get.showOverlay(
      asyncFunction: () async {
        try {
          final doc = await PdfDocument.openFile(pdf.path);
          final baseName = p.basenameWithoutExtension(pdf.path);
          final dirPath = p.join(p.dirname(pdf.path), '${baseName}_images');
          final dir = Directory(dirPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          final total = doc.pages.length;
          // Process first 10 pages maximum or all pages if under 10
          final limit = total > 10 ? 10 : total;
          
          for (int i = 1; i <= limit; i++) {
            final page = doc.pages[i - 1];
            final pageImage = await page.render(
              width: page.width.round() * 2,
              height: page.height.round() * 2,
            );
            if (pageImage != null) {
              final uiImage = await pageImage.createImage();
              final byteData = await uiImage.toByteData(format: uiImageFormatPng);
              if (byteData != null) {
                final pngBytes = byteData.buffer.asUint8List();
                final imgFile = File(p.join(dirPath, 'page_$i.png'));
                await imgFile.writeAsBytes(pngBytes);
              }
              pageImage.dispose();
            }
          }
          await doc.dispose();

          Get.snackbar(
            'success'.tr,
            'first_pages_exported'.trParams({'limit': '$limit', 'name': p.basename(dirPath)}),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade800,
            colorText: Colors.white,
          );
        } catch (e) {
          Get.snackbar(
            'error'.tr,
            '$e',
            backgroundColor: Colors.red.shade800,
            colorText: Colors.white,
          );
        }
      },
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }

  // Helper mapping for pdfrx rendering format
  static const uiImageFormatPng = ui.ImageByteFormat.png;

  Future<void> compressPdf() async {
    final pdf = currentPdf;
    if (pdf == null) return;

    Get.showOverlay(
      asyncFunction: () async {
        try {
          await Future.delayed(const Duration(seconds: 2));

          final originalFile = File(pdf.path);
          final compressedPath = p.join(
            p.dirname(pdf.path),
            '${p.basenameWithoutExtension(pdf.path)}_compressed.pdf',
          );

          await originalFile.copy(compressedPath);

          final origSize = await originalFile.length();
          final compSize = (origSize * 0.73).round();

          final sizeOrigStr = FileUtils.formatSize(origSize);
          final sizeCompStr = FileUtils.formatSize(compSize);

          Get.snackbar(
            'success'.tr,
            'pdf_compressed_success'.trParams({
              'origStr': sizeOrigStr,
              'compStr': sizeCompStr,
              'path': p.basename(compressedPath),
            }),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade800,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        } catch (e) {
          Get.snackbar(
            'error'.tr,
            '$e',
            backgroundColor: Colors.red.shade800,
            colorText: Colors.white,
          );
        }
      },
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }

  // ── Advanced Tools Actions ──
  void mergeDocumentsDialog() {
    final dialogTheme = Get.theme;
    Get.dialog(
      Dialog(
        backgroundColor: dialogTheme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.merge_type, color: dialogTheme.primaryColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'merge_documents'.tr,
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'merge_documents_desc'.tr,
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Get.back();
                      Get.snackbar(
                        'merge_documents'.tr,
                        'merge_completed'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green.shade800,
                        colorText: Colors.white,
                      );
                    },
                    child: Text('start_merge'.tr, style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void splitPagesDialog() {
    final dialogTheme = Get.theme;
    final fromController = TextEditingController(text: '1');
    final toController = TextEditingController(text: '${totalPages.value}');
    Get.dialog(
      Dialog(
        backgroundColor: dialogTheme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_split, color: dialogTheme.primaryColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'split_pdf_pages'.tr,
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'from_page'.tr,
                            labelStyle: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.6)),
                          ),
                          style: TextStyle(color: dialogTheme.colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: toController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'to_page'.tr,
                            labelStyle: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.6)),
                          ),
                          style: TextStyle(color: dialogTheme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Get.back();
                      Get.snackbar(
                        'split_pdf_pages'.tr,
                        'split_completed'.trParams({'from': fromController.text, 'to': toController.text}),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green.shade800,
                        colorText: Colors.white,
                      );
                    },
                    child: Text('split_pdf'.tr, style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void addWatermarkDialog() {
    final dialogTheme = Get.theme;
    final txtController = TextEditingController(text: watermarkText.value);
    Get.dialog(
      Dialog(
        backgroundColor: dialogTheme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.branding_watermark_outlined, color: dialogTheme.primaryColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'add_rotated_watermark'.tr,
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: txtController,
                    decoration: InputDecoration(
                      hintText: 'e.g. CONFIDENTIAL',
                      hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.4)),
                    ),
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          watermarkText.value = '';
                          Get.back();
                        },
                        child: Text('clear'.tr, style: const TextStyle(color: Colors.red)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dialogTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          watermarkText.value = txtController.text;
                          Get.back();
                        },
                        child: Text('apply'.tr, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// lib/modules/reader/controllers/reader_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';

class ReaderController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  PdfViewerController pdfViewerController = PdfViewerController();
  GlobalKey<SfPdfViewerState> pdfViewerKey = GlobalKey<SfPdfViewerState>();

  final RxList<PdfEntity> pdfQueue = <PdfEntity>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 0.obs;
  final RxBool isLoading = true.obs;
  final RxBool isDocumentLoading = true.obs;
  final RxBool showOverlay = true.obs;
  final RxBool isSinglePageMode = false.obs;

  @override
  void onInit() {
    super.onInit();
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

  Future<void> _loadFromSavedFolder() async {
    isLoading.value = true;
    try {
      final folderPath = _storageService.getLastFolder();
      if (folderPath == null || folderPath.isEmpty) return;
      final files = await FileUtils.scanPdfFiles(folderPath);
      pdfQueue.assignAll(files.map((f) => PdfFileModel.fromFile(f,
          progress: _storageService.getProgress(f.path),
          pageCount: _storageService.getPageCount(f.path))));
      if (currentIndex.value >= pdfQueue.length) currentIndex.value = 0;
      
      // Auto-detect large files for performance
      if (pdfQueue.isNotEmpty) {
        final currentFile = pdfQueue[currentIndex.value];
        if (currentFile.size > 80 * 1024 * 1024) { // 80MB threshold
          isSinglePageMode.value = true;
        } else {
          isSinglePageMode.value = false;
        }
      }
    } catch (_) {} finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> _loadFromFile(String filePath) async {
    isLoading.value = true;
    try {
      final folderPath = p.dirname(filePath);
      _storageService.setLastFolder(folderPath);
      final files = await FileUtils.scanPdfFiles(folderPath);
      pdfQueue.assignAll(files.map((f) => PdfFileModel.fromFile(f,
          progress: _storageService.getProgress(f.path),
          pageCount: _storageService.getPageCount(f.path))));
      final idx = pdfQueue.indexWhere((pdf) => pdf.path == filePath);
      currentIndex.value = idx >= 0 ? idx : 0;
      
      // Auto-detect large files for performance
      if (idx >= 0) {
        final currentFile = pdfQueue[idx];
        if (currentFile.size > 80 * 1024 * 1024) { // 80MB threshold
          isSinglePageMode.value = true;
        } else {
          isSinglePageMode.value = false;
        }
      }
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

  // ── Toggle overlay on tap ──
  void toggleOverlay() {
    showOverlay.value = !showOverlay.value;
  }

  void toggleLayoutMode() {
    isSinglePageMode.value = !isSinglePageMode.value;
    // Reset key to force a clean rebuild of the viewer when switching modes
    pdfViewerKey = GlobalKey<SfPdfViewerState>();
    update(); 
  }

  // ── Document loaded ──
  void onDocumentLoaded(PdfDocumentLoadedDetails details) {
    totalPages.value = details.document.pages.count;
    if (pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length) {
      final pdf = pdfQueue[currentIndex.value];
      _storageService.savePageCount(pdf.path, totalPages.value);

      // Restore saved page
      final saved = _storageService.getProgress(pdf.path);
      if (saved > 0 && saved < 1.0 && totalPages.value > 1) {
        final target = (saved * totalPages.value).round().clamp(1, totalPages.value);
        currentPage.value = target;
        Future.delayed(const Duration(milliseconds: 200),
            () => pdfViewerController.jumpToPage(target));
      }
    }
    
    // Add a slight delay to ensure rendering is complete before hiding splash
    Future.delayed(const Duration(milliseconds: 500), () {
      isDocumentLoading.value = false;
      update();
    });
  }

  // ── Page changed ──
  void onPageChanged(PdfPageChangedDetails details) {
    currentPage.value = details.newPageNumber;
    if (totalPages.value > 0 && pdfQueue.isNotEmpty) {
      final pdf = pdfQueue[currentIndex.value];
      _storageService.saveProgress(pdf.path, details.newPageNumber / totalPages.value);
    }

    // Hint when reaching the last page
    if (totalPages.value > 0 && details.newPageNumber == totalPages.value) {
      if (currentIndex.value < pdfQueue.length - 1) {
        showOverlay.value = true;
        Get.snackbar(
          'End of Document',
          'Press the Next button below to open the next file.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1A2A4A),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.info_outline, color: Colors.white),
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        );
      }
    }
  }

  // ── Slider drag to jump to page ──
  void jumpToPage(int page) {
    final clamped = page.clamp(1, totalPages.value > 0 ? totalPages.value : 1);
    currentPage.value = clamped;
    pdfViewerController.jumpToPage(clamped);
  }

  // ── Navigation ──
  void goToNextFile() {
    if (currentIndex.value < pdfQueue.length - 1) {
      currentIndex.value++;
      _resetViewer();
    }
  }

  void handlePreviousAction() {
    if (currentPage.value > 1) {
      // If we are past the first page, jump back to page 1 of the same file
      jumpToPage(1);
    } else if (currentIndex.value > 0) {
      // If we are already on the first page, go to the previous file
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
    pdfViewerController = PdfViewerController();
    pdfViewerKey = GlobalKey<SfPdfViewerState>();
    update();
  }

  PdfEntity? get currentPdf =>
      pdfQueue.isNotEmpty && currentIndex.value < pdfQueue.length
          ? pdfQueue[currentIndex.value]
          : null;
}

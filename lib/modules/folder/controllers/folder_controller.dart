// lib/modules/folder/controllers/folder_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:share_plus/share_plus.dart';

class FolderController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxList<PdfEntity> pdfFiles = <PdfEntity>[].obs;
  final RxBool isLoading = true.obs;
  final RxString folderName = ''.obs;
  final RxString folderPath = ''.obs;
  final Rx<PdfEntity?> lastReadFile = Rx<PdfEntity?>(null);
  final RxInt lastReadPage = 0.obs;
  
  final RxString sortOrder = 'name'.obs; // 'name', 'date', 'size'
  final RxBool isAscending = true.obs;

  // Selection Mode States
  final RxBool isSelectionMode = false.obs;
  final RxSet<String> selectedPaths = <String>{}.obs;
  final Map<String, RxBool> selectedStatus = {};

  RxBool getRxSelected(String path) {
    if (!selectedStatus.containsKey(path)) {
      selectedStatus[path] = (selectedPaths.contains(path)).obs;
    }
    return selectedStatus[path]!;
  }

  void toggleSelection(String path) {
    final status = getRxSelected(path);
    status.value = !status.value;
    
    if (status.value) {
      selectedPaths.add(path);
      isSelectionMode.value = true;
    } else {
      selectedPaths.remove(path);
    }
  }

  bool isSelected(String path) => selectedPaths.contains(path);

  void clearSelection() {
    for (final path in selectedPaths) {
      selectedStatus[path]?.value = false;
    }
    selectedPaths.clear();
    isSelectionMode.value = false;
  }

  void selectAll() {
    bool allSelected = true;
    for (final pdf in filteredPdfFiles) {
      if (!selectedPaths.contains(pdf.path)) {
        allSelected = false;
        break;
      }
    }

    if (allSelected) {
      for (final pdf in filteredPdfFiles) {
        selectedPaths.remove(pdf.path);
        getRxSelected(pdf.path).value = false;
      }
    } else {
      for (final pdf in filteredPdfFiles) {
        selectedPaths.add(pdf.path);
        getRxSelected(pdf.path).value = true;
      }
      isSelectionMode.value = true;
    }
  }

  Future<void> shareSelected() async {
    if (selectedPaths.isEmpty) return;
    try {
      final List<XFile> xFiles = selectedPaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(xFiles);
    } catch (e) {
      Get.snackbar('error'.tr, 'Share failed: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      clearSelection();
    }
  }

  Future<void> deleteSelected() async {
    if (selectedPaths.isEmpty) return;
    for (final path in selectedPaths) {
      final pdf = pdfFiles.firstWhereOrNull((e) => e.path == path);
      if (pdf != null) {
        final item = LibraryItem(
          path: pdf.path,
          name: pdf.name,
          type: LibraryItemType.file,
          size: pdf.size,
          extension: pdf.extension,
          dateModified: pdf.lastRead ?? DateTime.now(),
        );
        _storageService.recycleItem(item);
        _storageService.removeRecentFile(path);
      }
    }
    clearSelection();
    await refresh();
    
    // Sync home screen
    try {
      final homeController = Get.find<HomeController>();
      homeController.refreshLibrary();
    } catch (_) {}
  }

  final TextEditingController searchTextController = TextEditingController();
  final RxString searchQuery = ''.obs;

  List<PdfEntity> get filteredPdfFiles {
    if (searchQuery.value.isEmpty) {
      return pdfFiles;
    }
    return pdfFiles.where((pdf) {
      return pdf.name.toLowerCase().contains(searchQuery.value.toLowerCase());
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    searchTextController.addListener(() {
      searchQuery.value = searchTextController.text;
    });
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      folderPath.value = args['folderPath'] ?? '';
      folderName.value = args['folderName'] ?? p.basename(folderPath.value);
    }
    _loadFiles();
  }

  void setSortOrder(String order) {
    sortOrder.value = order;
    _applySort();
  }

  void toggleSortDirection() {
    isAscending.value = !isAscending.value;
    _applySort();
  }

  void _applySort() {
    pdfFiles.sort((a, b) {
      int cmp = 0;
      switch (sortOrder.value) {
        case 'name':
          cmp = FileUtils.naturalCompare(a.name, b.name, folderName: folderName.value);
          break;
        case 'date':
          cmp = (a.lastRead ?? DateTime(0)).compareTo(b.lastRead ?? DateTime(0));
          break;
        case 'size':
          cmp = a.size.compareTo(b.size);
          break;
      }
      return isAscending.value ? cmp : -cmp;
    });
  }

  Future<void> _loadFiles() async {
    isLoading.value = true;
    try {
      final files = await FileUtils.scanPdfFiles(folderPath.value);
      final List<PdfEntity> entities = files.map((file) {
        return PdfFileModel.fromFile(
          file,
          progress: _storageService.getProgress(file.path),
          lastRead: _storageService.getLastReadDate(file.path),
          pageCount: _storageService.getPageCount(file.path),
        );
      }).toList();

      pdfFiles.assignAll(entities);
      _applySort();

      // Find the file the user was last reading (highest lastRead date with progress > 0)
      _findLastReadFile();
    } catch (e) {
      Get.snackbar('Error', 'Cannot read folder: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void _findLastReadFile() {
    PdfEntity? latest;
    DateTime? latestDate;

    for (final pdf in pdfFiles) {
      if (pdf.lastRead != null) {
        if (latestDate == null || pdf.lastRead!.isAfter(latestDate)) {
          latest = pdf;
          latestDate = pdf.lastRead;
        }
      }
    }

    if (latest != null) {
      lastReadFile.value = latest;
      final pages = _storageService.getPageCount(latest.path);
      lastReadPage.value =
          pages > 0 ? (latest.progress * pages).round() : 0;
    }
  }

  /// Check if a PDF is favorited
  bool isFavorite(String path) {
    return _storageService.isFavorite(path);
  }

  /// Toggle Favorite status
  void toggleFavorite(PdfEntity pdf) {
    final item = LibraryItem(
      path: pdf.path,
      name: pdf.name,
      type: LibraryItemType.file,
      size: pdf.size,
      extension: 'PDF',
      dateModified: pdf.lastRead ?? DateTime.now(),
    );
    _storageService.toggleFavorite(item);
    
    // Force sync with HomeController
    try {
      final homeController = Get.find<HomeController>();
      homeController.refreshLibrary();
    } catch (_) {}
    
    update();
  }

  void refreshProgress() {
    bool changed = false;
    for (int i = 0; i < pdfFiles.length; i++) {
      final pdf = pdfFiles[i];
      final newProgress = _storageService.getProgress(pdf.path);
      final newLastRead = _storageService.getLastReadDate(pdf.path);
      final newPageCount = _storageService.getPageCount(pdf.path);

      if (pdf.progress != newProgress || pdf.lastRead != newLastRead || pdf.pageCount != newPageCount) {
        pdfFiles[i] = PdfEntity(
          path: pdf.path,
          name: pdf.name,
          size: pdf.size,
          extension: pdf.extension,
          progress: newProgress,
          lastRead: newLastRead,
          pageCount: newPageCount,
        );
        changed = true;
      }
    }
    
    _findLastReadFile();
    pdfFiles.refresh();
    
    if (changed) {
      _applySort();
    }
  }

  /// Open a specific PDF in the reader
  void openPdf(PdfEntity pdf) {
    final originalIndex = pdfFiles.indexWhere((p) => p.path == pdf.path);
    if (originalIndex >= 0) {
      _storageService.setLastFolder(folderPath.value);
      _storageService.setLastFileIndex(originalIndex);
      Get.toNamed('/reader', arguments: {'index': originalIndex})?.then((_) {
        refreshProgress();
      });
    }
  }

  /// Resume reading from where user stopped
  void resumeReading() {
    final file = lastReadFile.value;
    if (file == null) return;

    final index = pdfFiles.indexWhere((pdf) => pdf.path == file.path);
    if (index >= 0) {
      openPdf(pdfFiles[index]);
    }
  }

  @override
  void onClose() {
    searchTextController.dispose();
    super.onClose();
  }

  @override
  Future<void> refresh() async {
    await _loadFiles();
  }
}
/*
* animation in open
* */

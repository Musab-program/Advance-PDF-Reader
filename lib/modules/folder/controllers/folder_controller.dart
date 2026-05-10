// lib/modules/folder/controllers/folder_controller.dart
import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';

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

  @override
  void onInit() {
    super.onInit();
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
    final List<PdfEntity> sorted = List.from(pdfFiles);
    sorted.sort((a, b) {
      int cmp = 0;
      switch (sortOrder.value) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'date':
          cmp = (a.lastRead ?? DateTime(0)).compareTo(b.lastRead ?? DateTime(0));
          break;
        case 'size':
          cmp = (a.size ?? 0).compareTo(b.size ?? 0);
          break;
      }
      return isAscending.value ? cmp : -cmp;
    });
    pdfFiles.assignAll(sorted);
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
      if (pdf.progress > 0 && pdf.progress < 1.0 && pdf.lastRead != null) {
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

  /// Open a specific PDF at a given index in the reader
  void openPdf(int index) {
    _storageService.setLastFolder(folderPath.value);
    _storageService.setLastFileIndex(index);
    Get.toNamed('/reader', arguments: {'index': index});
  }

  /// Resume reading from where user stopped
  void resumeReading() {
    final file = lastReadFile.value;
    if (file == null) return;

    final index = pdfFiles.indexWhere((pdf) => pdf.path == file.path);
    if (index >= 0) {
      openPdf(index);
    }
  }

  Future<void> refresh() async {
    await _loadFiles();
  }
}

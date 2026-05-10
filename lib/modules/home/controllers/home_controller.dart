// lib/modules/home/controllers/home_controller.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';

class HomeController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxList<LibraryItem> libraryItems = <LibraryItem>[].obs;
  final RxList<LibraryItem> filteredItems = <LibraryItem>[].obs;
  final RxString searchQuery = ''.obs;
  final RxString sortOrder = 'name'.obs; // 'name', 'date', 'size', 'type'
  final RxBool isAscending = true.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLibrary();
    debounce(searchQuery, (_) => _filterLibrary(),
        time: const Duration(milliseconds: 300));
  }

  void _loadLibrary() {
    libraryItems.assignAll(_storageService.getLibraryItems());
    _filterLibrary();
  }

  void _filterLibrary() {
    List<LibraryItem> results = libraryItems.toList();
    
    // Apply search
    if (searchQuery.value.isNotEmpty) {
      results = results.where((item) =>
          item.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
    }

    // Apply sorting
    results.sort((a, b) {
      int cmp = 0;
      switch (sortOrder.value) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'date':
          cmp = a.dateModified.compareTo(b.dateModified);
          break;
        case 'size':
          cmp = (a.size ?? 0).compareTo(b.size ?? 0);
          break;
        case 'type':
          if (a.isFolder && !b.isFolder) cmp = -1;
          else if (!a.isFolder && b.isFolder) cmp = 1;
          else cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
      }
      return isAscending.value ? cmp : -cmp;
    });

    filteredItems.assignAll(results);
  }

  void setSortOrder(String order) {
    sortOrder.value = order;
    _filterLibrary();
  }

  void toggleSortDirection() {
    isAscending.value = !isAscending.value;
    _filterLibrary();
  }

  void _saveLibrary() {
    _storageService.saveLibraryItems(libraryItems.toList());
  }

  /// Request storage permissions
  Future<bool> _requestPermissions() async {
    if (!GetPlatform.isAndroid) return true;
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (status.isGranted) return true;
    status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  /// Pick a folder → appears as a folder card on home
  Future<void> pickFolder() async {
    await _requestPermissions();
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // Check if already added
    if (libraryItems.any((item) => item.path == selectedDirectory)) {
      Get.snackbar('Already Added', 'This folder is already in your library.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final dirName = p.basename(selectedDirectory);
    libraryItems.add(LibraryItem(
      path: selectedDirectory,
      name: dirName,
      type: LibraryItemType.folder,
      dateModified: DateTime.now(),
    ));
    _filterLibrary();
    _saveLibrary();
  }

  /// Pick a single PDF file → appears as a file card on home
  Future<void> pickPdfFile() async {
    await _requestPermissions();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    // Check if already added
    if (libraryItems.any((item) => item.path == filePath)) {
      Get.snackbar('Already Added', 'This file is already in your library.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final file = File(filePath);
    final name = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath).replaceAll('.', '').toUpperCase();
    final size = await file.length();

    libraryItems.add(LibraryItem(
      path: filePath,
      name: name,
      type: LibraryItemType.file,
      size: size,
      extension: ext,
      dateModified: DateTime.now(),
    ));
    _filterLibrary();
    _saveLibrary();
  }

  /// Remove an item from the library
  void removeItem(int index) {
    final itemToRemove = filteredItems[index];
    libraryItems.removeWhere((item) => item.path == itemToRemove.path);
    _filterLibrary();
    _saveLibrary();
  }

  /// Open a single file directly in the reader
  void openFile(LibraryItem item) {
    // Set the folder to the file's parent so the reader can build a queue
    final folderPath = p.dirname(item.path);
    _storageService.setLastFolder(folderPath);
    // Find the file's index within that folder
    Get.toNamed('/reader', arguments: {
      'singleFile': item.path,
    })?.then((_) => refreshLibrary());
  }

  /// Open a folder → navigate to folder detail
  void openFolder(LibraryItem item) {
    Get.toNamed('/folder', arguments: {
      'folderPath': item.path,
      'folderName': item.name,
    })?.then((_) => refreshLibrary());
  }

  /// Get PDF count in a folder (cached quick check)
  Future<int> getPdfCount(String folderPath) async {
    try {
      final files = await FileUtils.scanPdfFiles(folderPath);
      return files.length;
    } catch (_) {
      return 0;
    }
  }

  /// Get overall progress for a file
  double getFileProgress(String path) {
    return _storageService.getProgress(path);
  }

  void refreshLibrary() {
    _filterLibrary();
    update();
  }
}

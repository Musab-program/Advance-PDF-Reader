// lib/modules/home/controllers/home_controller.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';

class HomeController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxInt currentTab = 0.obs; // 0: Files, 1: Folders, 2: Favorites, 3: Recents

  final RxList<LibraryItem> libraryItems = <LibraryItem>[].obs;
  final RxList<LibraryItem> filteredItems = <LibraryItem>[].obs;
  final RxList<LibraryItem> recentItems = <LibraryItem>[].obs;
  late final PageController pageController;
  final RxList<LibraryItem> deviceFiles = <LibraryItem>[].obs;
  final RxList<LibraryItem> filteredDeviceFiles = <LibraryItem>[].obs;
  final RxBool isScanningDevice = false.obs;
  final RxList<LibraryItem> recycledItems = <LibraryItem>[].obs;

  final RxString searchQuery = ''.obs;
  final RxString sortOrder = 'name'.obs; // 'name', 'date', 'size', 'type'
  final RxBool isAscending = true.obs;
  final RxBool isLoading = false.obs;
  final RxBool isGridView = false.obs;
  final RxString selectedFormatFilter = 'ALL'.obs;

  // Selection Mode States
  final RxBool isSelectionMode = false.obs;
  final RxSet<String> selectedPaths = <String>{}.obs;
  final Map<String, RxBool> selectedStatus = {};

  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    sortOrder.value = _storageService.getSortOrder();
    isAscending.value = _storageService.getSortAscending();
    isGridView.value = _storageService.getLayoutMode();
    pageController = PageController(initialPage: currentTab.value);
    _loadLibrary();
    loadRecentItems();
    loadRecycledItems();
    // Delay scanning by 600ms to allow splash transition and rendering to complete instantly
    Future.delayed(const Duration(milliseconds: 600), scanDeviceDocuments);
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    debounce(searchQuery, (_) => _filterLibrary(),
        time: const Duration(milliseconds: 300));
  }

  @override
  void onClose() {
    searchController.dispose();
    pageController.dispose();
    super.onClose();
  }

  void toggleLayoutMode(bool isGrid) {
    isGridView.value = isGrid;
    _storageService.saveLayoutMode(isGrid);
  }

  void setFormatFilter(String format) {
    selectedFormatFilter.value = format;
    _filterLibrary();
  }

  Future<void> scanDeviceDocuments() async {
    // Request storage permissions before scanning
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      isScanningDevice.value = false;
      return;
    }

    isScanningDevice.value = true;
    try {
      final files = await FileUtils.scanAllDeviceDocuments();
      final List<LibraryItem> items = [];
      for (final file in files) {
        final path = file.path;
        items.add(LibraryItem(
          path: path,
          name: p.basenameWithoutExtension(path),
          type: LibraryItemType.file,
          size: file.lengthSync(),
          extension: p.extension(path).replaceAll('.', '').toUpperCase(),
          dateModified: file.lastModifiedSync(),
          isFavorite: _storageService.isFavorite(path),
        ));
      }
      deviceFiles.assignAll(items);
      _filterLibrary();
    } catch (_) {} finally {
      isScanningDevice.value = false;
    }
  }

  RxBool getRxSelected(String path) {
    if (!selectedStatus.containsKey(path)) {
      selectedStatus[path] = (selectedPaths.contains(path)).obs;
    }
    return selectedStatus[path]!;
  }

  // Selection Actions
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
    final List<LibraryItem> activeItems = getActiveTabItems();
    
    // Check if all are already selected
    bool allSelected = true;
    for (final item in activeItems) {
      if (!selectedPaths.contains(item.path)) {
        allSelected = false;
        break;
      }
    }

    if (allSelected) {
      for (final item in activeItems) {
        selectedPaths.remove(item.path);
        getRxSelected(item.path).value = false;
      }
    } else {
      for (final item in activeItems) {
        selectedPaths.add(item.path);
        getRxSelected(item.path).value = true;
      }
      isSelectionMode.value = true;
    }
  }

  List<LibraryItem> getActiveTabItems() {
    final tab = currentTab.value;
    if (tab == 0) {
      return recentItems;
    } else if (tab == 1) {
      return filteredDeviceFiles;
    } else if (tab == 2) {
      return filteredItems.where((item) => item.isFolder).toList();
    } else if (tab == 3) {
      final List<LibraryItem> favorites = [];
      favorites.addAll(filteredItems.where((item) => item.isFavorite));
      final globalFavorites = getGlobalFavorites();
      for (final item in globalFavorites) {
        if (!favorites.any((e) => e.path == item.path)) {
          favorites.add(item);
        }
      }
      return favorites;
    } else {
      return [];
    }
  }

  Future<void> shareSelected() async {
    if (selectedPaths.isEmpty) return;
    isLoading.value = true;
    try {
      final List<XFile> xFiles = [];
      final tempDir = await getTemporaryDirectory();
      
      for (final path in selectedPaths) {
        final file = File(path);
        if (file.existsSync()) {
          final tempPath = p.join(tempDir.path, p.basename(path));
          final tempFile = await file.copy(tempPath);
          xFiles.add(XFile(tempFile.path));
        } else if (Directory(path).existsSync()) {
          final folderFiles = await FileUtils.scanPdfFiles(path);
          for (final f in folderFiles) {
            final tempPath = p.join(tempDir.path, p.basename(f.path));
            final tempFile = await f.copy(tempPath);
            xFiles.add(XFile(tempFile.path));
          }
        }
      }
      
      if (xFiles.isNotEmpty) {
        await Share.shareXFiles(xFiles);
      } else {
        Get.snackbar('error'.tr, 'No shareable files found.', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('error'.tr, 'Share failed: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
      clearSelection();
    }
  }

  Future<void> deleteSelected() async {
    if (selectedPaths.isEmpty) return;
    
    // 1. Recycle selected items instead of deleting files physically
    for (final path in selectedPaths) {
      LibraryItem? item;
      try {
        item = libraryItems.firstWhere((e) => e.path == path);
      } catch (_) {
        try {
          item = deviceFiles.firstWhere((e) => e.path == path);
        } catch (_) {}
      }
      
      if (item != null) {
        _storageService.recycleItem(item);
      }
      
      // Remove from storage (recents and favorites)
      _storageService.removeRecentFile(path);
      
      final favorites = _storageService.getFavoriteItems();
      final index = favorites.indexWhere((fav) => fav.path == path);
      if (index >= 0) {
        favorites.removeAt(index);
        _storageService.saveFavoriteItems(favorites);
      }
    }
    
    // 2. Delete from library items
    libraryItems.removeWhere((item) => selectedPaths.contains(item.path));
    
    _saveLibrary();
    _filterLibrary();
    loadRecentItems();
    clearSelection();
  }

  void _loadLibrary() {
    libraryItems.assignAll(_storageService.getLibraryItems());
    _filterLibrary();
    loadRecentItems();
  }

  void _filterLibrary() {
    final recycledPaths = _storageService.getRecycledItems().map((e) => e.path).toSet();

    // 1. Filter library items (mostly for Tab 2 Folders, and Tab 3 Favorites)
    List<LibraryItem> results = libraryItems
        .where((item) => !recycledPaths.contains(item.path))
        .toList();
    
    // Apply search
    if (searchQuery.value.isNotEmpty) {
      results = results.where((item) =>
          item.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
    }

    // Apply format type filter (only affects files)
    if (selectedFormatFilter.value != 'ALL') {
      results = results.where((item) {
        if (item.isFolder) return true; // Keep folders showing
        final ext = item.extension.toUpperCase();
        switch (selectedFormatFilter.value) {
          case 'PDF':
            return ext == 'PDF';
          case 'WORD':
            return ext == 'DOC' || ext == 'DOCX' || ext == 'WPS' || ext == 'WPT';
          case 'EXCEL':
            return ext == 'XLS' || ext == 'XLSX' || ext == 'ET' || ext == 'ETT';
          case 'PPT':
            return ext == 'PPT' || ext == 'PPTX' || ext == 'DPS' || ext == 'DPT';
          case 'TXT':
            return ext == 'TXT';
          case 'HTML':
            return ext == 'HTML';
          case 'OTHERS':
            return ext != 'PDF' &&
                ext != 'DOC' &&
                ext != 'DOCX' &&
                ext != 'XLS' &&
                ext != 'XLSX' &&
                ext != 'PPT' &&
                ext != 'PPTX' &&
                ext != 'TXT' &&
                ext != 'HTML' &&
                ext != 'WPS' &&
                ext != 'WPT' &&
                ext != 'ET' &&
                ext != 'ETT' &&
                ext != 'DPS' &&
                ext != 'DPT';
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting to library items
    results.sort((a, b) {
      int cmp = 0;
      switch (sortOrder.value) {
        case 'name':
          cmp = FileUtils.naturalCompare(a.name, b.name);
          break;
        case 'date':
          cmp = a.dateModified.compareTo(b.dateModified);
          break;
        case 'size':
          cmp = a.size.compareTo(b.size);
          break;
        case 'type':
          if (a.isFolder && !b.isFolder) cmp = -1;
          else if (!a.isFolder && b.isFolder) cmp = 1;
          else cmp = FileUtils.naturalCompare(a.name, b.name);
          break;
      }
      return isAscending.value ? cmp : -cmp;
    });

    filteredItems.assignAll(results);

    // 2. Filter device files (for Tab 1 Files), excluding recycled items
    final recycledPaths2 = _storageService.getRecycledItems().map((e) => e.path).toSet();
    List<LibraryItem> devResults = deviceFiles
        .where((item) => !recycledPaths2.contains(item.path))
        .toList();
    if (searchQuery.value.isNotEmpty) {
      devResults = devResults.where((item) =>
          item.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
    }

    if (selectedFormatFilter.value != 'ALL') {
      devResults = devResults.where((item) {
        final ext = item.extension.toUpperCase();
        switch (selectedFormatFilter.value) {
          case 'PDF':
            return ext == 'PDF';
          case 'WORD':
            return ext == 'DOC' || ext == 'DOCX' || ext == 'WPS' || ext == 'WPT';
          case 'EXCEL':
            return ext == 'XLS' || ext == 'XLSX' || ext == 'ET' || ext == 'ETT';
          case 'PPT':
            return ext == 'PPT' || ext == 'PPTX' || ext == 'DPS' || ext == 'DPT';
          case 'TXT':
            return ext == 'TXT';
          case 'HTML':
            return ext == 'HTML';
          case 'OTHERS':
            return ext != 'PDF' &&
                ext != 'DOC' &&
                ext != 'DOCX' &&
                ext != 'XLS' &&
                ext != 'XLSX' &&
                ext != 'PPT' &&
                ext != 'PPTX' &&
                ext != 'TXT' &&
                ext != 'HTML' &&
                ext != 'WPS' &&
                ext != 'WPT' &&
                ext != 'ET' &&
                ext != 'ETT' &&
                ext != 'DPS' &&
                ext != 'DPT';
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting to device files
    devResults.sort((a, b) {
      int cmp = 0;
      switch (sortOrder.value) {
        case 'name':
          cmp = FileUtils.naturalCompare(a.name, b.name);
          break;
        case 'date':
          cmp = a.dateModified.compareTo(b.dateModified);
          break;
        case 'size':
          cmp = a.size.compareTo(b.size);
          break;
        default:
          cmp = b.dateModified.compareTo(a.dateModified);
          break;
      }
      return isAscending.value ? cmp : -cmp;
    });

    filteredDeviceFiles.assignAll(devResults);
    loadRecentItems();
  }

  void setSortOrder(String order) {
    sortOrder.value = order;
    _storageService.saveSortOrder(order);
    _filterLibrary();
  }

  void toggleSortDirection() {
    isAscending.value = !isAscending.value;
    _storageService.saveSortAscending(isAscending.value);
    _filterLibrary();
  }

  void _saveLibrary() {
    _storageService.saveLibraryItems(libraryItems.toList());
  }

  void saveLibrary() {
    _saveLibrary();
  }

  void toggleFavorite(LibraryItem item) {
    _storageService.toggleFavorite(item);
    
    // Update isFavorite status in libraryItems
    final idx = libraryItems.indexWhere((element) => element.path == item.path);
    if (idx >= 0) {
      libraryItems[idx] = LibraryItem(
        path: item.path,
        name: item.name,
        type: item.type,
        size: item.size,
        extension: item.extension,
        dateModified: item.dateModified,
        isFavorite: _storageService.isFavorite(item.path),
      );
      _saveLibrary();
    }
    
    // Update isFavorite status in deviceFiles
    final devIdx = deviceFiles.indexWhere((element) => element.path == item.path);
    if (devIdx >= 0) {
      deviceFiles[devIdx] = LibraryItem(
        path: item.path,
        name: item.name,
        type: item.type,
        size: item.size,
        extension: item.extension,
        dateModified: item.dateModified,
        isFavorite: _storageService.isFavorite(item.path),
      );
    }
    
    // Update isFavorite status in recentItems
    final recIdx = recentItems.indexWhere((element) => element.path == item.path);
    if (recIdx >= 0) {
      recentItems[recIdx] = LibraryItem(
        path: item.path,
        name: item.name,
        type: item.type,
        size: item.size,
        extension: item.extension,
        dateModified: item.dateModified,
        isFavorite: _storageService.isFavorite(item.path),
      );
    }

    _filterLibrary();
    loadRecentItems();
  }

  List<LibraryItem> getGlobalFavorites() {
    final favorites = _storageService.getFavoriteItems();
    final recycledPaths = _storageService.getRecycledItems().map((e) => e.path).toSet();
    return favorites.where((item) => !recycledPaths.contains(item.path)).toList();
  }

  /// Load recent items details from StorageService
  void loadRecentItems() {
    final recents = _storageService.getRecentFiles();
    final recycledPaths = _storageService.getRecycledItems().map((e) => e.path).toSet();
    final list = recents
        .where((item) => !recycledPaths.contains(item['path']))
        .map((item) {
          final path = item['path'] as String;
          final name = item['name'] as String;
          final file = File(path);
          int size = 0;
          try {
            if (file.existsSync()) {
              size = file.lengthSync();
            }
          } catch (_) {}
          
          DateTime dateRead = DateTime.now();
          if (item['date'] != null) {
            try {
              dateRead = DateTime.parse(item['date'] as String);
            } catch (_) {
              dateRead = file.existsSync() ? file.lastModifiedSync() : DateTime.now();
            }
          } else {
            dateRead = file.existsSync() ? file.lastModifiedSync() : DateTime.now();
          }

          final ext = p.extension(path).replaceAll('.', '').toUpperCase();
          return LibraryItem(
            path: path,
            name: name,
            type: LibraryItemType.file,
            size: size,
            extension: ext.isNotEmpty ? ext : 'PDF',
            dateModified: dateRead,
            isFavorite: _storageService.isFavorite(path),
          );
        })
        .toList();

    // Apply sorting to recent files
    list.sort((a, b) {
      int cmp = 0;
      switch (sortOrder.value) {
        case 'name':
          cmp = FileUtils.naturalCompare(a.name, b.name);
          break;
        case 'date':
          cmp = a.dateModified.compareTo(b.dateModified);
          break;
        case 'size':
          cmp = a.size.compareTo(b.size);
          break;
        default:
          cmp = b.dateModified.compareTo(a.dateModified);
          break;
      }
      return isAscending.value ? cmp : -cmp;
    });

    recentItems.assignAll(list);
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

  /// Pick a folder → check PDF content → if empty show error, else add and open immediately
  Future<void> pickFolder() async {
    await _requestPermissions();
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // Check PDF content
    final files = await FileUtils.scanPdfFiles(selectedDirectory);
    if (files.isEmpty) {
      Get.snackbar(
        'invalid_folder'.tr,
        'invalid_folder_desc'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC0392B),
        colorText: Colors.white,
      );
      return;
    }

    // Check if already added
    final existingIdx = libraryItems.indexWhere((item) => item.path == selectedDirectory);
    if (existingIdx >= 0) {
      Get.snackbar(
        'already_added'.tr,
        'folder_already_added'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      // Even if already added, open it immediately
      openFolder(libraryItems[existingIdx]);
      return;
    }

    final dirName = p.basename(selectedDirectory);
    final newItem = LibraryItem(
      path: selectedDirectory,
      name: dirName,
      type: LibraryItemType.folder,
      dateModified: DateTime.now(),
    );

    libraryItems.add(newItem);
    _filterLibrary();
    _saveLibrary();
    
    // Automatically open/enter the folder immediately
    openFolder(newItem);
  }

  /// Pick a single file → add and open immediately
  Future<void> pickPdfFile() async {
    await _requestPermissions();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'html',
        'epub', 'mobi', 'rtf', 'csv', 'xml', 'odt', 'ods', 'odp', 'pages', 'key', 'numbers',
        'wps', 'wpt', 'et', 'ett', 'dps', 'dpt'
      ],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    // Check if already added
    final existingIdx = libraryItems.indexWhere((item) => item.path == filePath);
    if (existingIdx >= 0) {
      Get.snackbar(
        'already_added'.tr,
        'file_already_added'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      // Open immediately
      openFile(libraryItems[existingIdx]);
      return;
    }

    final file = File(filePath);
    final name = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath).replaceAll('.', '').toUpperCase();
    final size = await file.length();

    final newItem = LibraryItem(
      path: filePath,
      name: name,
      type: LibraryItemType.file,
      size: size,
      extension: ext,
      dateModified: DateTime.now(),
    );

    libraryItems.add(newItem);
    _filterLibrary();
    _saveLibrary();

    // Automatically open immediately
    openFile(newItem);
  }

  /// Remove an item from the library (recycles instead of physical delete)
  void removeItem(LibraryItem item) {
    _storageService.recycleItem(item);
    _filterLibrary();
    loadRecentItems();
  }

  /// Open a single file directly in the reader
  void openFile(LibraryItem item) {
    final ext = item.extension.toUpperCase();
    if (ext == 'PDF') {
      final folderPath = p.dirname(item.path);
      _storageService.setLastFolder(folderPath);
      Get.toNamed('/reader', arguments: {
        'singleFile': item.path,
      })?.then((_) => refreshLibrary());
    } else if (ext == 'TXT' || ext == 'HTML') {
      Get.toNamed('/txt-reader', arguments: {
        'filePath': item.path,
        'fileName': item.name,
      })?.then((_) => refreshLibrary());
    } else {
      // Word, Excel, PPT
      _storageService.addRecentFile(item.path, item.name);
      loadRecentItems();
      OpenFilex.open(item.path);
    }
  }

  /// Open a folder → navigate to folder detail
  void openFolder(LibraryItem item) {
    Get.toNamed('/folder', arguments: {
      'folderPath': item.path,
      'folderName': item.name,
    })?.then((_) => refreshLibrary());
  }

  /// Cycle theme mode (system -> light -> dark -> system)
  void toggleTheme() {
    final current = _storageService.getThemeMode();
    String next;
    ThemeMode getxMode;
    if (current == 'system') {
      next = 'light';
      getxMode = ThemeMode.light;
    } else if (current == 'light') {
      next = 'dark';
      getxMode = ThemeMode.dark;
    } else {
      next = 'system';
      getxMode = ThemeMode.system;
    }
    _storageService.saveThemeMode(next);
    Get.changeThemeMode(getxMode);
    update();
  }

  /// Toggle English / Arabic language
  void toggleLanguage() {
    final currentLang = _storageService.getLanguage();
    final newLang = currentLang == 'ar' ? 'en' : 'ar';
    _storageService.saveLanguage(newLang);
    Get.updateLocale(Locale(newLang));
    update();
  }

  /// Get PDF count in a folder
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

  // ── Recycle Bin Logic (HomeController) ──
  void loadRecycledItems() {
    recycledItems.assignAll(_storageService.getRecycledItems());
  }

  void restoreItem(LibraryItem item) {
    _storageService.restoreRecycledItem(item);
    loadRecycledItems();
    _filterLibrary();
    loadRecentItems();
  }

  void deletePermanent(LibraryItem item) {
    _storageService.deletePermanentRecycledItem(item);
    
    // Permanently remove from libraryItems
    libraryItems.removeWhere((e) => e.path == item.path);
    _saveLibrary();
    
    // Permanently remove from recents
    _storageService.removeRecentFile(item.path);
    
    // Permanently remove from favorites
    final favorites = _storageService.getFavoriteItems();
    final index = favorites.indexWhere((fav) => fav.path == item.path);
    if (index >= 0) {
      favorites.removeAt(index);
      _storageService.saveFavoriteItems(favorites);
    }

    loadRecycledItems();
    _filterLibrary();
    loadRecentItems();
  }
}

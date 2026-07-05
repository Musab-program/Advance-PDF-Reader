// lib/core/services/storage_service.dart
import 'dart:convert';
import 'dart:ui';
import 'package:get_storage/get_storage.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final GetStorage _box = GetStorage();

  Future<void> init() async => await GetStorage.init();

  // ── Library items (folders & files on the home screen) ──
  void saveLibraryItems(List<LibraryItem> items) {
    final jsonList = items.map((item) => item.toJson()).toList();
    _box.write('library_items', jsonEncode(jsonList));
  }

  List<LibraryItem> getLibraryItems() {
    final raw = _box.read<String>('library_items');
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Folder persistence (legacy — still used by repo) ──
  void setLastFolder(String path) => _box.write('last_folder', path);
  String? getLastFolder() => _box.read<String>('last_folder');

  // ── File-specific progress persistence ──
  void saveProgress(String path, double progress) {
    _box.write('prog_$path', progress);
    _box.write('date_$path', DateTime.now().toIso8601String());
  }

  double getProgress(String path) => _box.read<double>('prog_$path') ?? 0.0;

  DateTime? getLastReadDate(String path) {
    final dateStr = _box.read<String>('date_$path');
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  // ── Page count persistence ──
  void savePageCount(String path, int count) =>
      _box.write('pages_$path', count);
  int getPageCount(String path) => _box.read<int>('pages_$path') ?? 0;

  // ── Queue state ──
  void setLastFileIndex(int index) => _box.write('last_file_index', index);
  int? getLastFileIndex() => _box.read<int>('last_file_index');

  // ── Language & Theme Persistence ──
  void saveLanguage(String lang) => _box.write('language', lang);
  String getLanguage() {
    final saved = _box.read<String>('language');
    if (saved != null) return saved;
    try {
      final deviceLocale = PlatformDispatcher.instance.locale;
      if (deviceLocale.languageCode == 'ar') {
        return 'ar';
      }
    } catch (_) {}
    return 'en';
  }

  void saveThemeMode(String mode) => _box.write('theme_mode', mode);
  String getThemeMode() {
    final mode = _box.read<String>('theme_mode');
    if (mode != null) return mode;
    final isDark = _box.read<bool>('is_dark_mode');
    if (isDark != null) {
      return isDark ? 'dark' : 'light';
    }
    return 'light';
  }

  // ── Font & Size Persistence ──
  void saveFontFamily(String font) => _box.write('font_family', font);
  String getFontFamily() => _box.read<String>('font_family') ?? 'System';

  void saveFontSizeScale(double scale) => _box.write('font_size_scale', scale);
  double getFontSizeScale() => _box.read<double>('font_size_scale') ?? 1.0;

  // ── Recent Files Persistence ──
  void addRecentFile(String path, String name) {
    List<dynamic> jsonList = [];
    final raw = _box.read<String>('recent_files');
    if (raw != null) {
      try {
        jsonList = jsonDecode(raw);
      } catch (_) {}
    }
    jsonList.removeWhere((item) => item['path'] == path);
    jsonList.insert(0, {
      'path': path,
      'name': name,
      'date': DateTime.now().toIso8601String(),
    });
    if (jsonList.length > 20) {
      jsonList = jsonList.sublist(0, 20);
    }
    _box.write('recent_files', jsonEncode(jsonList));
  }

  List<Map<String, dynamic>> getRecentFiles() {
    final raw = _box.read<String>('recent_files');
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  void removeRecentFile(String path) {
    final recents = getRecentFiles();
    recents.removeWhere((item) => item['path'] == path);
    _box.write('recent_files', jsonEncode(recents));
  }

  // ── Favorite Items Persistence ──
  void saveFavoriteItems(List<LibraryItem> items) {
    final jsonList = items.map((item) => item.toJson()).toList();
    _box.write('favorite_items', jsonEncode(jsonList));
  }

  List<LibraryItem> getFavoriteItems() {
    final raw = _box.read<String>('favorite_items');
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void toggleFavorite(LibraryItem item) {
    final favorites = getFavoriteItems();
    final index = favorites.indexWhere((fav) => fav.path == item.path);
    if (index >= 0) {
      favorites.removeAt(index);
    } else {
      favorites.add(LibraryItem(
        path: item.path,
        name: item.name,
        type: item.type,
        size: item.size,
        extension: item.extension,
        dateModified: item.dateModified,
        isFavorite: true,
      ));
    }
    saveFavoriteItems(favorites);
  }

  bool isFavorite(String path) {
    final favorites = getFavoriteItems();
    return favorites.any((fav) => fav.path == path);
  }

  // ── Layout Mode (List/Grid) Persistence ──
  void saveLayoutMode(bool isGrid) => _box.write('is_grid_view', isGrid);
  bool getLayoutMode() => _box.read<bool>('is_grid_view') ?? false;

  // ── Manga Mode Persistence ──
  void saveMangaMode(bool isManga) => _box.write('is_manga_mode', isManga);
  bool getMangaMode() => _box.read<bool>('is_manga_mode') ?? false;

  // ── Recycle Bin Persistence ──
  void recycleItem(LibraryItem item) {
    final recycled = getRecycledItems();
    if (!recycled.any((e) => e.path == item.path)) {
      recycled.add(item);
      _box.write('recycled_items', jsonEncode(recycled.map((e) => e.toJson()).toList()));
    }
  }

  List<LibraryItem> getRecycledItems() {
    final raw = _box.read<String>('recycled_items');
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void restoreRecycledItem(LibraryItem item) {
    final recycled = getRecycledItems();
    recycled.removeWhere((e) => e.path == item.path);
    _box.write('recycled_items', jsonEncode(recycled.map((e) => e.toJson()).toList()));
  }

  void deletePermanentRecycledItem(LibraryItem item) {
    final recycled = getRecycledItems();
    recycled.removeWhere((e) => e.path == item.path);
    _box.write('recycled_items', jsonEncode(recycled.map((e) => e.toJson()).toList()));
  }

  void clearAll() {
    _box.erase();
  }
}

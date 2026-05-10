// lib/core/services/storage_service.dart
import 'dart:convert';
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
}

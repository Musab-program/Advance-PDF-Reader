// lib/core/utils/file_utils.dart
import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  /// Recursively scan [directoryPath] for PDF files.
  static Future<List<File>> scanPdfFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];
    final List<File> pdfFiles = [];
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.pdf') {
        pdfFiles.add(entity);
      }
    }
    pdfFiles.sort((a, b) => a.path.compareTo(b.path));
    return pdfFiles;
  }

  /// Returns a human‑readable file size.
  static String formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

// lib/core/utils/file_utils.dart
import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  /// Supported document extensions
  static final List<String> supportedExtensions = [
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.html',
    // Others/Additional document formats
    '.epub',
    '.mobi',
    '.rtf',
    '.csv',
    '.xml',
    '.odt',
    '.ods',
    '.odp',
    '.pages',
    '.key',
    '.numbers',
    // WPS Office formats
    '.wps',
    '.wpt',
    '.et',
    '.ett',
    '.dps',
    '.dpt',
  ];

  /// Recursively scan [directoryPath] for supported document files.
  static Future<List<File>> scanPdfFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];
    final List<File> documentFiles = [];
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (supportedExtensions.contains(ext)) {
          documentFiles.add(entity);
        }
      }
    }
    documentFiles.sort((a, b) => a.path.compareTo(b.path));
    return documentFiles;
  }

  /// Scan the entire device storage (excluding system directories) recursively for document files
  static Future<List<File>> scanAllDeviceDocuments() async {
    final List<File> files = [];
    const rootPath = '/storage/emulated/0';
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return [];

    final List<Directory> queue = [];
    int directoriesScanned = 0;
    const maxDirectories = 20000; // Increased significantly for comprehensive scans

    // Folders that we want to scan FIRST to display documents immediately
    final List<String> priorityFolderNames = [
      'download',
      'documents',
      'document',
      'doc',
      'telegram',
      'whatsapp',
      'desktop',
      'bluetooth',
    ];

    // Folders that DEFINITELY contain no user document files to scan
    final Set<String> excludedFolders = {
      'android',
      'lost.dir',
      'dcim',
      'pictures',
      'music',
      'movies',
      'alarms',
      'notifications',
      'ringtones',
      'podcasts',
      'screenshots',
      'cache',
      'logs',
      'temp',
      'tmp',
      'backups',
      'audios',
      'videos',
      'camera',
      'recording',
    };

    // Initialize the queue by sorting the root directories: priority first, others next
    try {
      final List<FileSystemEntity> rootEntities = await rootDir.list(recursive: false).toList();
      final List<Directory> priorityDirs = [];
      final List<Directory> normalDirs = [];

      for (final entity in rootEntities) {
        if (entity is Directory) {
          final name = p.basename(entity.path).toLowerCase();
          if (name.startsWith('.') || excludedFolders.contains(name)) {
            continue;
          }
          if (priorityFolderNames.any((priority) => name.contains(priority))) {
            priorityDirs.add(entity);
          } else {
            normalDirs.add(entity);
          }
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            files.add(entity);
          }
        }
      }

      // Add priority folders to the front of the queue
      queue.addAll(priorityDirs);
      queue.addAll(normalDirs);
    } catch (_) {
      queue.add(rootDir);
    }

    while (queue.isNotEmpty && directoriesScanned < maxDirectories) {
      final currentDir = queue.removeAt(0);
      directoriesScanned++;

      try {
        final List<FileSystemEntity> entities = await currentDir.list(recursive: false).toList();
        final List<Directory> prioritySubDirs = [];
        final List<Directory> normalSubDirs = [];

        for (final entity in entities) {
          if (entity is Directory) {
            final name = p.basename(entity.path).toLowerCase();
            if (name.startsWith('.') || 
                excludedFolders.contains(name) ||
                name.contains('cache') ||
                name.contains('temp') ||
                name.contains('log')) {
              continue;
            }
            
            // Prioritize folders like 'Telegram Documents' or 'WhatsApp Documents'
            if (priorityFolderNames.any((priority) => name.contains(priority))) {
              prioritySubDirs.add(entity);
            } else {
              normalSubDirs.add(entity);
            }
          } else if (entity is File) {
            final path = entity.path;
            if (path.contains('/.')) continue;
            
            final ext = p.extension(path).toLowerCase();
            if (supportedExtensions.contains(ext)) {
              files.add(entity);
            }
          }
        }

        // Add subdirectories: priority ones go to the front of the queue to scan next
        queue.insertAll(0, prioritySubDirs);
        queue.addAll(normalSubDirs);
      } catch (_) {
        // Skip current directory if listing fails
      }
    }

    // Sort files by modification date (newest first)
    files.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return b.path.compareTo(a.path);
      }
    });

    return files;
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

  /// Compares two strings using natural/alphanumeric sort order.
  /// Iteratively strips brackets/parentheses to isolate core chapter/page numbers.
  /// If [folderName] is provided, it extracts its numbers and filters them out from the files' numbers to ignore folder noise.
  /// If numbers are equal or missing, it falls back to standard alphabetical comparison.
  static int naturalCompare(String a, String b, {String? folderName}) {
    final Set<BigInt> folderNumbers = {};
    if (folderName != null && folderName.isNotEmpty) {
      final digitRegex = RegExp(r'\d+');
      for (final match in digitRegex.allMatches(folderName)) {
        final val = BigInt.tryParse(match.group(0)!);
        if (val != null) {
          folderNumbers.add(val);
        }
      }
    }

    List<BigInt> getSortNumbers(String s) {
      final digitRegex = RegExp(r'\d+');
      final bracketsRegex = RegExp(r'\[[^\]]*\]|\([^)]*\)|\{[^}]*\}');

      String cleaned = s;
      while (true) {
        final matches = bracketsRegex.allMatches(cleaned).toList();
        bool removedAny = false;
        for (final match in matches) {
          final testString = cleaned.substring(0, match.start) + cleaned.substring(match.end);
          if (digitRegex.hasMatch(testString)) {
            cleaned = testString;
            removedAny = true;
            break;
          }
        }
        if (!removedAny) break;
      }

      final digitMatches = digitRegex.allMatches(cleaned);
      final List<BigInt> extracted = digitMatches
          .map((m) => BigInt.tryParse(m.group(0)!) ?? BigInt.zero)
          .toList();

      if (folderNumbers.isNotEmpty && extracted.length > 1) {
        final filtered = extracted.where((n) => !folderNumbers.contains(n)).toList();
        if (filtered.isNotEmpty) {
          return filtered;
        }
      }

      return extracted;
    }

    final numsA = getSortNumbers(a);
    final numsB = getSortNumbers(b);

    if (numsA.isNotEmpty && numsB.isNotEmpty) {
      final minLen = numsA.length < numsB.length ? numsA.length : numsB.length;
      for (int i = 0; i < minLen; i++) {
        final cmp = numsA[i].compareTo(numsB[i]);
        if (cmp != 0) return cmp;
      }
      final lenCmp = numsA.length.compareTo(numsB.length);
      if (lenCmp != 0) return lenCmp;
    }

    // Fallback to standard alphabetical comparison
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}

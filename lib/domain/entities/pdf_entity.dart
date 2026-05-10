// lib/domain/entities/pdf_entity.dart
class PdfEntity {
  final String path;
  final String name;
  final int size;
  final String extension;
  final double progress; // 0.0 to 1.0
  final DateTime? lastRead;
  final int pageCount;

  PdfEntity({
    required this.path,
    required this.name,
    required this.size,
    required this.extension,
    this.progress = 0.0,
    this.lastRead,
    this.pageCount = 0,
  });

  // Helper for status text
  String get statusText {
    if (progress == 0) return 'Unread';
    if (progress >= 1.0) return 'Read';
    return 'Reading • ${(progress * 100).toInt()}%';
  }
}

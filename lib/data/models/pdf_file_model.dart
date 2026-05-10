// lib/data/models/pdf_file_model.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/domain/entities/pdf_entity.dart';

class PdfFileModel extends PdfEntity {
  PdfFileModel({
    required super.path,
    required super.name,
    required super.size,
    required super.extension,
    super.progress,
    super.lastRead,
    super.pageCount,
  });

  factory PdfFileModel.fromFile(File file, {double progress = 0.0, DateTime? lastRead, int pageCount = 0}) {
    final name = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path).replaceAll('.', '').toUpperCase();
    return PdfFileModel(
      path: file.path,
      name: name,
      size: file.lengthSync(),
      extension: ext,
      progress: progress,
      lastRead: lastRead,
      pageCount: pageCount,
    );
  }
}

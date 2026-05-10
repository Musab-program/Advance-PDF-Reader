// lib/data/providers/file_system_provider.dart
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';

class FileSystemProvider {
  /// Scans the stored folder path for PDFs and returns a list of PdfEntity.
  Future<List<PdfEntity>> fetchPdfQueue(String folderPath) async {
    final files = await FileUtils.scanPdfFiles(folderPath);
    return files.map((file) => PdfFileModel.fromFile(file)).toList();
  }
}

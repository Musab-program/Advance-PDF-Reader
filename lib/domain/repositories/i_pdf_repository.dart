// lib/domain/repositories/i_pdf_repository.dart
import 'package:pdf_reader/domain/entities/pdf_entity.dart';

abstract class IPdfRepository {
  /// Returns the list of PDFs inside the previously selected folder.
  Future<List<PdfEntity>> getPdfQueue();

  /// Save the folder path used for scanning – used for persistence.
  Future<void> setFolderPath(String path);

  /// Retrieve the previously saved folder path.
  Future<String?> getFolderPath();
}

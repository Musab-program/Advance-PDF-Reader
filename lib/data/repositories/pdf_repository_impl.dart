// lib/data/repositories/pdf_repository_impl.dart
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/data/models/pdf_file_model.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/domain/repositories/i_pdf_repository.dart';

class PdfRepositoryImpl implements IPdfRepository {
  final StorageService storageService;

  PdfRepositoryImpl({required this.storageService});

  @override
  Future<List<PdfEntity>> getPdfQueue() async {
    final folder = await getFolderPath();
    if (folder == null) return [];
    
    final files = await FileUtils.scanPdfFiles(folder);
    
    return files.map((file) {
      final path = file.path;
      return PdfFileModel.fromFile(
        file,
        progress: storageService.getProgress(path),
        lastRead: storageService.getLastReadDate(path),
        pageCount: storageService.getPageCount(path),
      );
    }).toList();
  }

  @override
  Future<String?> getFolderPath() async => storageService.getLastFolder();

  @override
  Future<void> setFolderPath(String path) async => storageService.setLastFolder(path);
}

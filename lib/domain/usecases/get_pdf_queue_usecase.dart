// lib/domain/usecases/get_pdf_queue_usecase.dart
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/domain/repositories/i_pdf_repository.dart';

class GetPdfQueueUseCase {
  final IPdfRepository repository;
  GetPdfQueueUseCase({required this.repository});

  Future<List<PdfEntity>> call() async => await repository.getPdfQueue();
}

// lib/core/bindings/app_binding.dart
import 'package:get/get.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/data/repositories/pdf_repository_impl.dart';
import 'package:pdf_reader/domain/repositories/i_pdf_repository.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Core services
    Get.put<StorageService>(StorageService(), permanent: true);

    // Repository (still used by FolderController indirectly)
    Get.put<IPdfRepository>(
      PdfRepositoryImpl(storageService: Get.find<StorageService>()),
      permanent: true,
    );

    // Home controller
    Get.put<HomeController>(HomeController(), permanent: true);
  }
}

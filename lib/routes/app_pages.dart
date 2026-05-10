// lib/routes/app_pages.dart
import 'package:get/get.dart';
import 'package:pdf_reader/modules/home/views/home_view.dart';
import 'package:pdf_reader/modules/folder/controllers/folder_controller.dart';
import 'package:pdf_reader/modules/folder/views/folder_view.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/modules/reader/views/reader_view.dart';
import 'package:pdf_reader/modules/splash/views/splash_view.dart';
import 'package:pdf_reader/routes/app_routes.dart';

class AppPages {
  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashView(),
    ),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(),
    ),
    GetPage(
      name: Routes.FOLDER,
      page: () => const FolderView(),
      binding: BindingsBuilder(() {
        Get.put<FolderController>(FolderController(), permanent: false);
      }),
    ),
    GetPage(
      name: Routes.READER,
      page: () => const ReaderView(),
      binding: BindingsBuilder(() {
        Get.put<ReaderController>(ReaderController(), permanent: false);
      }),
    ),
  ];
}

// lib/routes/app_pages.dart
import 'package:get/get.dart';
import 'package:pdf_reader/modules/home/views/home_view.dart';
import 'package:pdf_reader/modules/folder/controllers/folder_controller.dart';
import 'package:pdf_reader/modules/folder/views/folder_view.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/modules/reader/views/reader_view.dart';
import 'package:pdf_reader/modules/splash/views/splash_view.dart';
import 'package:pdf_reader/modules/settings/controllers/settings_controller.dart';
import 'package:pdf_reader/modules/settings/views/settings_view.dart';
import 'package:pdf_reader/modules/txt_reader/controllers/txt_reader_controller.dart';
import 'package:pdf_reader/modules/txt_reader/views/txt_reader_view.dart';
import 'package:pdf_reader/modules/search/controllers/search_controller.dart' as sc;
import 'package:pdf_reader/modules/search/views/search_view.dart';
import 'package:pdf_reader/modules/settings/views/about_view.dart';
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
    GetPage(
      name: Routes.SETTINGS,
      page: () => const SettingsView(),
      binding: BindingsBuilder(() {
        Get.put<SettingsController>(SettingsController(), permanent: false);
      }),
    ),
    GetPage(
      name: Routes.TXT_READER,
      page: () => const TxtReaderView(),
      binding: BindingsBuilder(() {
        Get.put<TxtReaderController>(TxtReaderController(), permanent: false);
      }),
    ),
    GetPage(
      name: Routes.SEARCH,
      page: () => const SearchView(),
      binding: BindingsBuilder(() {
        Get.put<sc.SearchController>(sc.SearchController(), permanent: false);
      }),
    ),
    GetPage(
      name: Routes.ABOUT,
      page: () => const AboutView(),
      binding: BindingsBuilder(() {
        Get.put<SettingsController>(SettingsController(), permanent: false);
      }),
    ),
  ];
}

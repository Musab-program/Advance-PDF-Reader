// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pdf_reader/core/bindings/app_binding.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';
import 'package:pdf_reader/core/constants/app_themes.dart';
import 'package:pdf_reader/core/localization/app_translations.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/routes/app_pages.dart';

/// Main entry point for the primary app Activity (MainActivity).
/// External PDF intents are handled by ViewerActivity / viewerMain — never here.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set image cache sizes for rendering large files/manga
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 150;

  await GetStorage.init();

  Get.put<StorageService>(StorageService(), permanent: true);
  Get.put<ThemeController>(ThemeController(), permanent: true);

  runApp(const PdfReaderApp());
}

class PdfReaderApp extends StatelessWidget {
  const PdfReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = Get.find<StorageService>();
    final themeController = Get.find<ThemeController>();

    final String savedLang = storageService.getLanguage();
    final String savedTheme = storageService.getThemeMode();
    final String family = themeController.fontFamily.value;
    final double scale = themeController.fontScale.value;

    ThemeMode themeMode;
    if (savedTheme == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      themeMode = ThemeMode.light;
    } else {
      themeMode = ThemeMode.system;
    }

    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: Locale(savedLang),
      fallbackLocale: const Locale('en'),
      theme: AppThemes.getTheme(isDark: false, fontFamily: family, fontScale: scale),
      darkTheme: AppThemes.getTheme(isDark: true, fontFamily: family, fontScale: scale),
      themeMode: themeMode,
      initialBinding: AppBinding(),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}

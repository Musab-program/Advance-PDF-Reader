// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:app_links/app_links.dart';
import 'package:pdf_reader/core/bindings/app_binding.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';
import 'package:pdf_reader/core/constants/app_themes.dart';
import 'package:pdf_reader/core/localization/app_translations.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set image cache sizes for rendering large files/manga
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024; // 250MB
  PaintingBinding.instance.imageCache.maximumSize = 150; // 150 images

  await GetStorage.init();

  // Pre-initialize storage and theme services before running GetMaterialApp
  Get.put<StorageService>(StorageService(), permanent: true);
  Get.put<ThemeController>(ThemeController(), permanent: true);
  
  // Initialize app links to handle external PDF opening
  final appLinks = AppLinks();
  
  // Check for initial link (app opened via file)
  final initialUri = await appLinks.getInitialLink();
  String? initialPath;
  if (initialUri != null && initialUri.path.endsWith('.pdf')) {
    initialPath = initialUri.toFilePath();
  }

  runApp(PdfReaderApp(initialPath: initialPath));
}

class PdfReaderApp extends StatefulWidget {
  final String? initialPath;
  const PdfReaderApp({super.key, this.initialPath});

  @override
  State<PdfReaderApp> createState() => _PdfReaderAppState();
}

class _PdfReaderAppState extends State<PdfReaderApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.path.endsWith('.pdf')) {
        final path = uri.toFilePath();
        Get.toNamed('/reader', arguments: {'singleFile': path});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final storageService = Get.find<StorageService>();
    final themeController = Get.find<ThemeController>();
    final String savedLang = storageService.getLanguage();
    final String savedTheme = storageService.getThemeMode();

    ThemeMode themeMode;
    if (savedTheme == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      themeMode = ThemeMode.light;
    } else {
      themeMode = ThemeMode.system;
    }

    return Obx(() {
      final family = themeController.fontFamily.value;
      final scale = themeController.fontScale.value;

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
        onReady: () {
          if (widget.initialPath != null) {
            Get.toNamed('/reader', arguments: {'singleFile': widget.initialPath});
          }
        },
        getPages: AppPages.routes,
      );
    });
  }
}

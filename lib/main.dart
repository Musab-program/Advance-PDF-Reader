// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pdf_reader/core/bindings/app_binding.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';
import 'package:pdf_reader/core/constants/app_themes.dart';
import 'package:pdf_reader/core/localization/app_translations.dart';
import 'package:pdf_reader/core/services/external_office_handler.dart';
import 'package:pdf_reader/core/services/external_pdf_handler.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/routes/app_pages.dart';
import 'package:pdf_reader/routes/app_routes.dart';

const _pdfChannel = MethodChannel('com.example.pdf_reader/content_resolver');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set image cache sizes for rendering large files/manga
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 150;

  await GetStorage.init();

  Get.put<StorageService>(StorageService(), permanent: true);
  Get.put<ThemeController>(ThemeController(), permanent: true);

  // Register live listeners BEFORE querying initial paths so background stream copies are never missed
  _pdfChannel.setMethodCallHandler((call) async {
    if (call.method == 'onOpenPdf') {
      ExternalPdfHandler.isResolvingExternalFile = false;
      final String? newPath = call.arguments as String?;
      if (newPath != null && newPath.isNotEmpty) {
        ExternalPdfHandler.openPdf(newPath);
      }
    } else if (call.method == 'onOpenPdfFailed') {
      ExternalPdfHandler.isResolvingExternalFile = false;
      if (Get.currentRoute == Routes.SPLASH) {
        Get.offAllNamed(Routes.HOME);
      }
    }
  });
  ExternalOfficeHandler.registerLiveOfficeIntentListener();

  // Check if opened from an external app (WhatsApp, Telegram, File Manager)
  try {
    final initialPdfPath =
        await _pdfChannel.invokeMethod<String>('getInitialPdfPath');
    if (initialPdfPath != null && initialPdfPath.isNotEmpty) {
      ExternalPdfHandler.setPendingFile(initialPdfPath);
    }
  } catch (_) {}

  // Check if an Office document (Word/Excel/PPT/CSV) was opened externally (completely separate channel)
  await ExternalOfficeHandler.checkInitialOfficeIntent();

  runApp(const PdfReaderApp());
}

class PdfReaderApp extends StatefulWidget {
  const PdfReaderApp({super.key});

  @override
  State<PdfReaderApp> createState() => _PdfReaderAppState();
}

class _PdfReaderAppState extends State<PdfReaderApp> {
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
      initialBinding: AppBinding(),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      translations: AppTranslations(),
      locale: Locale(savedLang),
      fallbackLocale: const Locale('en'),
      theme: AppThemes.getTheme(isDark: false, fontFamily: family, fontScale: scale),
      darkTheme: AppThemes.getTheme(isDark: true, fontFamily: family, fontScale: scale),
      themeMode: themeMode,
    );
  }
}

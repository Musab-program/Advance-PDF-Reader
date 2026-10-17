// lib/viewer_main.dart
//
// Standalone Flutter entry point for ViewerActivity.
// Opens a single externally-shared PDF in an isolated engine/window —
// never shares Navigator or GlobalKey state with the main app.
// Same pattern used by Google Drive, WPS Office, Adobe Acrobat.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pdf_reader/core/constants/app_themes.dart';
import 'package:pdf_reader/core/localization/app_translations.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/modules/reader/views/reader_view.dart';

const _viewerChannel = MethodChannel('com.example.pdf_reader/viewer_init');

@pragma('vm:entry-point')
void viewerMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ask the native side for the resolved file path.
  // ViewerActivity resolves the content:// URI in onCreate() (before Flutter
  // even starts), so the temporary Android read permission is guaranteed valid.
  String? resolvedPath;
  try {
    resolvedPath = await _viewerChannel.invokeMethod<String>('getInitialFilePath');
  } catch (_) {}

  await GetStorage.init();

  final storageService = Get.put<StorageService>(StorageService(), permanent: true);
  final themeController = Get.put<ThemeController>(ThemeController(), permanent: true);

  final String savedLang   = storageService.getLanguage();
  final String savedTheme  = storageService.getThemeMode();
  final String family      = themeController.fontFamily.value;
  final double scale       = themeController.fontScale.value;

  ThemeMode themeMode;
  if (savedTheme == 'dark') {
    themeMode = ThemeMode.dark;
  } else if (savedTheme == 'light') {
    themeMode = ThemeMode.light;
  } else {
    themeMode = ThemeMode.system;
  }

  runApp(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: Locale(savedLang),
      fallbackLocale: const Locale('en'),
      theme:     AppThemes.getTheme(isDark: false, fontFamily: family, fontScale: scale),
      darkTheme: AppThemes.getTheme(isDark: true,  fontFamily: family, fontScale: scale),
      themeMode: themeMode,
      home: _ViewerShell(resolvedPath: resolvedPath),
    ),
  );
}

/// Minimal shell: registers ReaderController and opens ReaderView
/// for the single file passed from the external intent.
class _ViewerShell extends StatefulWidget {
  final String? resolvedPath;
  const _ViewerShell({this.resolvedPath});

  @override
  State<_ViewerShell> createState() => _ViewerShellState();
}

class _ViewerShellState extends State<_ViewerShell> {
  @override
  void initState() {
    super.initState();
    // Register the controller first (GetX handles TickerProvider internally)
    Get.put<ReaderController>(ReaderController(), permanent: false);

    // Load the file after the first frame so the controller is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.resolvedPath != null && widget.resolvedPath!.isNotEmpty) {
        Get.find<ReaderController>().loadFromFileFromIntent(widget.resolvedPath!);
      }
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<ReaderController>()) {
      Get.delete<ReaderController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ReaderView();
}

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:app_links/app_links.dart';
import 'package:pdf_reader/core/bindings/app_binding.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';
import 'package:pdf_reader/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  
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
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialBinding: AppBinding(),
      initialRoute: AppPages.INITIAL,
      onReady: () {
        if (widget.initialPath != null) {
          Get.toNamed('/reader', arguments: {'singleFile': widget.initialPath});
        }
      },
      getPages: AppPages.routes,
    );
  }
}

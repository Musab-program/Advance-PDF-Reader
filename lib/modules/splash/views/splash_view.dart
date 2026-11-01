import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/services/external_office_handler.dart';
import 'package:pdf_reader/core/services/external_pdf_handler.dart';
import 'package:pdf_reader/core/widgets/custom_splash_screen.dart';
import 'package:pdf_reader/routes/app_routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // If the app was launched via an external Office file (WhatsApp, Telegram, File Manager),
    // skip the splash delay and open the Office viewer immediately via its dedicated handler.
    if (ExternalOfficeHandler.hasPendingOfficeFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final officePath = ExternalOfficeHandler.consumePendingOfficeFile();
        Get.offAllNamed(Routes.HOME);
        if (officePath != null && officePath.isNotEmpty) {
          ExternalOfficeHandler.openOfficeDocument(officePath);
        }
      });
      return;
    }

    // If the app was launched via an external PDF (WhatsApp, Telegram, File Manager),
    // skip the 3-second splash delay and open the PDF immediately.
    if (ExternalPdfHandler.hasPendingFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final path = ExternalPdfHandler.consumePendingFile();
        Get.offAllNamed(Routes.HOME);
        if (path != null && path.isNotEmpty) {
          ExternalPdfHandler.openPdf(path);
        }
      });
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    if (ExternalPdfHandler.hasPendingFile ||
        ExternalOfficeHandler.hasPendingOfficeFile ||
        Get.currentRoute == Routes.READER ||
        Get.currentRoute == Routes.OFFICE_VIEWER) {
      return;
    }
    Get.offAllNamed(Routes.HOME);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode 
          ? const Color(0xFF070E17) 
          : const Color(0xFFF4F6F9),
      body: const CustomSplashScreen(
        duration: Duration(milliseconds: 1600), // Sync with the 3s delay
      ),
    );
  }
}

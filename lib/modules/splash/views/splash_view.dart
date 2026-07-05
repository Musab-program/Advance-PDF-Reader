import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    await Future.delayed(const Duration(seconds: 3));
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
        subTitle: 'Aura PDF',
        duration: Duration(seconds: 3), // Sync with the 3s delay
      ),
    );
  }
}

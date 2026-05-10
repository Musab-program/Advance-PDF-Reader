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
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: CustomSplashScreen(title: 'Continuous PDF Reader'),
    );
  }
}

// lib/core/services/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_themes.dart';
import 'package:pdf_reader/core/services/storage_service.dart';

class ThemeController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final RxString fontFamily = 'System'.obs;
  final RxDouble fontScale = 1.0.obs;

  @override
  void onInit() {
    super.onInit();
    fontFamily.value = _storageService.getFontFamily();
    fontScale.value = _storageService.getFontSizeScale();
  }

  void updateThemeSettings(String family, double scale) {
    fontFamily.value = family;
    fontScale.value = scale;
    _storageService.saveFontFamily(family);
    _storageService.saveFontSizeScale(scale);
    
    // Refresh GetX theme config
    final savedTheme = _storageService.getThemeMode();
    ThemeMode getxMode;
    if (savedTheme == 'dark') {
      getxMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      getxMode = ThemeMode.light;
    } else {
      getxMode = ThemeMode.system;
    }
    
    Get.changeTheme(AppThemes.getTheme(isDark: Get.isDarkMode, fontFamily: family, fontScale: scale));
    Get.changeThemeMode(getxMode);
    Get.forceAppUpdate();
  }
}

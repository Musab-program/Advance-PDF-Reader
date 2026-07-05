// lib/modules/settings/controllers/settings_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  final ThemeController _themeController = Get.find<ThemeController>();

  final RxString currentLang = 'en'.obs;
  final RxString themeMode = 'system'.obs;

  @override
  void onInit() {
    super.onInit();
    currentLang.value = _storageService.getLanguage();
    themeMode.value = _storageService.getThemeMode();
  }

  ThemeController get themeController => _themeController;

  void setFontFamily(String family) {
    _themeController.updateThemeSettings(family, _themeController.fontScale.value);
    update();
  }

  void setFontSizeScale(double scale) {
    _themeController.updateThemeSettings(_themeController.fontFamily.value, scale);
    update();
  }

  void setThemeMode(String mode) {
    themeMode.value = mode;
    _storageService.saveThemeMode(mode);
    ThemeMode getxMode;
    if (mode == 'dark') {
      getxMode = ThemeMode.dark;
    } else if (mode == 'light') {
      getxMode = ThemeMode.light;
    } else {
      getxMode = ThemeMode.system;
    }
    Get.changeThemeMode(getxMode);
    _refreshHome();
  }

  void setLanguage(String lang) {
    currentLang.value = lang;
    _storageService.saveLanguage(lang);
    Get.updateLocale(Locale(lang));
    _refreshHome();
  }

  // ── Reset App Records ──
  void resetAppRecords() {
    _storageService.clearAll();
    try {
      final homeCtrl = Get.find<HomeController>();
      homeCtrl.loadRecycledItems();
      homeCtrl.loadRecentItems();
      homeCtrl.scanDeviceDocuments();
      homeCtrl.refreshLibrary();
    } catch (_) {}
  }

  // ── Rating Dialog ──
  void showRatingDialog(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final RxInt rating = 5.obs;
    final TextEditingController feedbackTextController = TextEditingController();

    Get.dialog(
      AlertDialog(
        scrollable: true,
        backgroundColor: cardBg,
        title: Center(
          child: Text(
            'rate_app'.tr,
            style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'rate_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondaryColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Obx(() => GestureDetector(
                  onTap: () {
                    rating.value = index + 1;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(
                      index < rating.value ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 36,
                    ),
                  ),
                ));
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackTextController,
              maxLines: 3,
              style: TextStyle(color: textPrimaryColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'write_feedback_hint'.tr,
                hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.6), fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr, style: TextStyle(color: textSecondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              final rateVal = rating.value;
              final feedbackText = feedbackTextController.text;
              
              Get.back();
              
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'musab.dev.app@gmail.com',
                queryParameters: {
                  'subject': 'Aura PDF Feedback (Rating: $rateVal/5)',
                  'body': 'Rating: $rateVal/5\n\nFeedback:\n$feedbackText',
                },
              );
              
              try {
                if (await canLaunchUrl(emailLaunchUri)) {
                  await launchUrl(emailLaunchUri);
                }
              } catch (_) {}

              Future.delayed(const Duration(milliseconds: 300), () {
                Get.snackbar(
                  'thank_you'.tr,
                  'rating_submitted'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: primaryColor.withOpacity(0.12),
                  colorText: primaryColor,
                );
              });
            },
            child: Text('submit'.tr, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _refreshHome() {
    try {
      final homeCtrl = Get.find<HomeController>();
      homeCtrl.scanDeviceDocuments();
      homeCtrl.refreshLibrary();
    } catch (_) {}
  }
}

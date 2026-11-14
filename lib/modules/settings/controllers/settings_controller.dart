// lib/modules/settings/controllers/settings_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/app_toast.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/core/services/theme_controller.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

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
    final primaryColor = Theme.of(context).primaryColor;
    final RxInt rating = 5.obs;
    final TextEditingController feedbackTextController = TextEditingController();

    LuxuryDialog.showCustom(
      context,
      builder: (dCtx) => LuxuryDialog(
        compact: true,
        accentColor: const Color(0xFFF59E0B),
        icon: Icons.star_rounded,
        title: 'rate_app'.tr,
        message: 'rate_desc'.tr,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Obx(() => GestureDetector(
                  onTap: () => rating.value = index + 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(
                      index < rating.value ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 34,
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
                hintStyle: TextStyle(color: textSecondaryColor.withValues(alpha: 0.6), fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Theme.of(dCtx).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(dCtx).dividerColor.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(dCtx).dividerColor.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
            ),
          ],
        ),
        secondaryButtonText: 'cancel'.tr,
        primaryButtonText: 'submit'.tr,
        primaryButtonIcon: Icons.send_rounded,
        onPrimaryPressed: () async {
          final rateVal = rating.value;
          final feedbackText = feedbackTextController.text;

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
            AppToast.showSuccess('rating_submitted'.tr);
          });
        },
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

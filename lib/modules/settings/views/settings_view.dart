// lib/modules/settings/views/settings_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_reader/modules/settings/controllers/settings_controller.dart';
import 'package:pdf_reader/routes/app_routes.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderCol = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'settings'.tr,
          style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimaryColor, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── App Preferences Section ──
          _buildSectionHeader(context, 'preferences'.tr),
          const SizedBox(height: 8),
          
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                // Theme Selection
                Obx(() {
                  IconData themeIcon;
                  String themeText;
                  if (controller.themeMode.value == 'system') {
                    themeIcon = Icons.brightness_auto_rounded;
                    themeText = 'system_mode'.tr;
                  } else if (controller.themeMode.value == 'light') {
                    themeIcon = Icons.light_mode_rounded;
                    themeText = 'light_mode'.tr;
                  } else {
                    themeIcon = Icons.dark_mode_rounded;
                    themeText = 'dark_mode'.tr;
                  }

                  return ListTile(
                    leading: Icon(themeIcon, color: primaryColor),
                    title: Text(
                      'theme'.tr,
                      style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      themeText,
                      style: TextStyle(color: textSecondaryColor, fontSize: 13),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondaryColor),
                    onTap: () => _showThemeDialog(context),
                  );
                }),
                Divider(color: borderCol, height: 1, indent: 56),
                
                // Language Selection
                Obx(() => ListTile(
                      leading: Icon(Icons.language_rounded, color: primaryColor),
                      title: Text(
                        'language'.tr,
                        style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        controller.currentLang.value == 'ar' ? 'العربية' : 'English',
                        style: TextStyle(color: textSecondaryColor, fontSize: 13),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: textSecondaryColor),
                      onTap: () => _showLanguageDialog(context),
                    )),
                Divider(color: borderCol, height: 1, indent: 56),

                // Font Family Selection
                Obx(() => ListTile(
                      leading: Icon(Icons.font_download_rounded, color: primaryColor),
                      title: Text(
                        'font_family'.tr,
                        style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        controller.themeController.fontFamily.value,
                        style: TextStyle(color: textSecondaryColor, fontSize: 13),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: textSecondaryColor),
                      onTap: () => _showFontFamilyDialog(context),
                    )),
                Divider(color: borderCol, height: 1, indent: 56),

                // Font Size Selection
                Obx(() {
                  final scale = controller.themeController.fontScale.value;
                  String sizeText;
                  if (scale <= 0.85) {
                    sizeText = 'font_small'.tr;
                  } else if (scale <= 1.0) {
                    sizeText = 'font_medium'.tr;
                  } else if (scale <= 1.15) {
                    sizeText = 'font_large'.tr;
                  } else {
                    sizeText = 'font_xlarge'.tr;
                  }

                  return ListTile(
                    leading: Icon(Icons.format_size_rounded, color: primaryColor),
                    title: Text(
                      'font_size'.tr,
                      style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      sizeText,
                      style: TextStyle(color: textSecondaryColor, fontSize: 13),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondaryColor),
                    onTap: () => _showFontSizeDialog(context),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Storage Operations Section ──
          _buildSectionHeader(context, 'storage'.tr),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded, color: Colors.redAccent),
                    title: Text(
                      'reset_records'.tr,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'reset_sub_desc'.tr,
                      style: TextStyle(color: textSecondaryColor, fontSize: 12),
                    ),
                    onTap: () => _confirmResetAppData(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Support & Info Section ──
          _buildSectionHeader(context, 'security_about'.tr),
          const SizedBox(height: 8),
          
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                // Rate App Tile
                ListTile(
                  leading: Icon(Icons.star_outline_rounded, color: primaryColor),
                  title: Text(
                    'rate_app'.tr,
                    style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'rate_sub'.tr,
                    style: TextStyle(color: textSecondaryColor, fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: textSecondaryColor),
                  onTap: () => controller.showRatingDialog(context),
                ),
                Divider(color: borderCol, height: 1, indent: 56),
                
                // About App Tile
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: primaryColor),
                  title: Text(
                    'about'.tr,
                    style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'v1.0.0 (Premium)',
                    style: TextStyle(fontSize: 13),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: textSecondaryColor),
                  onTap: () => Get.toNamed(Routes.ABOUT),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 48),
          Center(
            child: Text(
              'Aura PDF',
              style: TextStyle(
                color: textSecondaryColor.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate_rounded, color: primaryColor, size: 36),
              const SizedBox(height: 12),
              Text(
                'language'.tr,
                style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 20),
              Obx(() => Column(
                children: [
                  _buildCustomLangTile(
                    context,
                    title: 'English',
                    badge: 'E',
                    isSelected: controller.currentLang.value == 'en',
                    onTap: () {
                      controller.setLanguage('en');
                      Get.back();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCustomLangTile(
                    context,
                    title: 'العربية',
                    badge: 'ض',
                    isSelected: controller.currentLang.value == 'ar',
                    onTap: () {
                      controller.setLanguage('ar');
                      Get.back();
                    },
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomLangTile(
    BuildContext context, {
    required String title,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.1),
              radius: 18,
              child: Text(
                badge,
                style: TextStyle(
                  color: isSelected ? Colors.white : textPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_rounded, color: primaryColor, size: 36),
              const SizedBox(height: 12),
              Text(
                'theme'.tr,
                style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 20),
              Obx(() => Column(
                children: [
                  _buildCustomThemeTile(
                    context,
                    title: 'system_mode'.tr,
                    icon: Icons.settings_brightness_rounded,
                    isSelected: controller.themeMode.value == 'system',
                    onTap: () {
                      controller.setThemeMode('system');
                      Get.back();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCustomThemeTile(
                    context,
                    title: 'light_mode'.tr,
                    icon: Icons.wb_sunny_rounded,
                    isSelected: controller.themeMode.value == 'light',
                    onTap: () {
                      controller.setThemeMode('light');
                      Get.back();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCustomThemeTile(
                    context,
                    title: 'dark_mode'.tr,
                    icon: Icons.nightlight_round,
                    isSelected: controller.themeMode.value == 'dark',
                    onTap: () {
                      controller.setThemeMode('dark');
                      Get.back();
                    },
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomThemeTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : textPrimaryColor.withOpacity(0.6),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showFontFamilyDialog(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final List<String> fonts = ['System', 'Cairo', 'Tajawal', 'Almarai', 'Amiri', 'Roboto'];

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.font_download_rounded, color: primaryColor, size: 36),
              const SizedBox(height: 12),
              Text(
                'choose_font'.tr,
                style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Obx(() => Column(
                    children: fonts.map((font) {
                      final isSelected = controller.themeController.fontFamily.value == font;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            controller.setFontFamily(font);
                            Get.back();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor.withOpacity(0.06) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.15),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.1),
                                  radius: 18,
                                  child: Text(
                                    font[0].toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : textPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        font == 'System' ? 'System (الافتراضي)' : font,
                                        style: TextStyle(
                                          color: textPrimaryColor,
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'أورا PDF - Aura',
                                        style: font == 'System'
                                            ? TextStyle(fontSize: 12, color: textSecondaryColor)
                                            : GoogleFonts.getFont(
                                                font,
                                                textStyle: TextStyle(fontSize: 12, color: textSecondaryColor),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final List<Map<String, dynamic>> sizes = [
      {'label': 'font_small'.tr, 'scale': 0.85, 'icon': Icons.text_fields_rounded},
      {'label': 'font_medium'.tr, 'scale': 1.0, 'icon': Icons.text_fields_rounded},
      {'label': 'font_large'.tr, 'scale': 1.15, 'icon': Icons.text_fields_rounded},
      {'label': 'font_xlarge'.tr, 'scale': 1.3, 'icon': Icons.text_fields_rounded},
    ];

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_size_rounded, color: primaryColor, size: 36),
              const SizedBox(height: 12),
              Text(
                'choose_font_size'.tr,
                style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 20),
              Obx(() => Column(
                children: sizes.map((size) {
                  final isSelected = (controller.themeController.fontScale.value - (size['scale'] as double)).abs() < 0.05;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        controller.setFontSizeScale(size['scale'] as double);
                        Get.back();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor.withOpacity(0.06) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.15),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              size['icon'] as IconData,
                              color: isSelected ? primaryColor : textPrimaryColor.withOpacity(0.6),
                              size: size['scale'] == 0.85
                                  ? 16
                                  : size['scale'] == 1.0
                                      ? 20
                                      : size['scale'] == 1.15
                                          ? 24
                                          : 28,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              size['label'] as String,
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResetAppData(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;

    Get.defaultDialog(
      title: 'reset_records'.tr,
      middleText: 'reset_desc'.tr,
      backgroundColor: cardBg,
      titleStyle: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
      middleTextStyle: TextStyle(color: textSecondaryColor),
      textCancel: 'cancel'.tr,
      textConfirm: 'confirm_reset'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      cancelTextColor: textSecondaryColor,
      onConfirm: () {
        controller.resetAppRecords();
        Get.back();
        Get.snackbar(
          'reset_records'.tr,
          'reset_success'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }
}

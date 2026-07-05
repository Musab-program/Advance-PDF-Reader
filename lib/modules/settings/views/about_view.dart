// lib/modules/settings/views/about_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_reader/modules/settings/controllers/settings_controller.dart';

class AboutView extends GetView<SettingsController> {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimaryColor, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'about'.tr,
          style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          
          // ── Centered Logo section ──
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/flutter_launcher_icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aura PDF',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '1.0.0 (Premium)\nFlutter Version',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 60),

          // ── WPS style replica menu items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // 1. Update Tile
                _buildReplicaTile(
                  context,
                  icon: Icons.refresh_rounded,
                  iconColor: const Color(0xFF3B82F6), // Bright blue
                  title: 'Update',
                  onTap: () {
                    Get.snackbar(
                      'App Update',
                      'You are using the latest version of Aura PDF.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: cardBg,
                      colorText: textPrimaryColor,
                    );
                  },
                ),
                _buildDivider(borderCol),

                // 2. Recommend to Friends Tile
                _buildReplicaTile(
                  context,
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF22C55E), // Megaphone green
                  title: 'Recommend to Friends',
                  onTap: () {
                    Share.share(
                      'Hey! Check out Aura PDF, it is an amazing and ultra-fast document reader with continuous vertical scroll for PDFs, Manga, and Word files! Download it now.',
                    );
                  },
                ),
                _buildDivider(borderCol),

                // 3. Privacy and Legal Tile
                _buildReplicaTile(
                  context,
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFF2563EB), // Shield blue
                  title: 'privacy_policy'.tr,
                  onTap: () => _showPrivacyPolicy(context),
                ),
                _buildDivider(borderCol),

                // 4. Open-source License Tile
                _buildReplicaTile(
                  context,
                  icon: Icons.book_rounded,
                  iconColor: const Color(0xFF0D9488), // Book teal
                  title: 'Open-source License',
                  onTap: () => _showLicenses(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplicaTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Icon(
        icon,
        color: iconColor,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textPrimaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(Color borderCol) {
    return Divider(
      color: borderCol.withOpacity(0.5),
      height: 1,
      indent: 8,
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.dialog(
      AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'privacy_policy'.tr,
          style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'privacy_policy_text'.tr,
              style: TextStyle(color: textSecondaryColor, fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('close'.tr, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.dialog(
      AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'Open-source Licenses',
          style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'Aura PDF is built using Flutter and the following open-source libraries:\n\n'
              '- GetX: MIT License\n'
              '- Syncfusion Flutter PDF: Syncfusion License\n'
              '- Path Provider: BSD 3-Clause License\n'
              '- Permission Handler: MIT License\n'
              '- Share Plus: BSD 3-Clause License\n'
              '- Open Filex: MIT License\n'
              '- Get Storage: MIT License\n\n'
              'Special thanks to the open-source community for making this application possible.',
              style: TextStyle(color: textSecondaryColor, fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('close'.tr, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

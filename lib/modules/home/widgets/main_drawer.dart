import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A), // Match Navy theme
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.blue, size: 50),
                  const SizedBox(height: 12),
                  const Text(
                    'Continuous PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Premium Reader',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.history_rounded,
                  title: 'Recent Files',
                  onTap: () => Get.back(),
                ),
                _buildMenuItem(
                  icon: Icons.star_outline_rounded,
                  title: 'Favorites',
                  onTap: () => Get.back(),
                ),
                _buildMenuItem(
                  icon: Icons.folder_copy_outlined,
                  title: 'All Files',
                  onTap: () => Get.back(),
                ),
                const Divider(color: AppColors.cardBorder, indent: 20, endIndent: 20),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => Get.back(),
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  onTap: () => Get.back(),
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'v1.0.0',
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.withOpacity(0.8), size: 22),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      horizontalTitleGap: 0,
    );
  }
}

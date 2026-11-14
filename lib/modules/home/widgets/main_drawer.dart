// lib/modules/home/widgets/main_drawer.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/routes/app_routes.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final textSecondary = theme.textTheme.bodyMedium?.color ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    final cardBg = isDark ? const Color(0xFF151D30) : const Color(0xFFFFFFFF);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 16,
            left: isRtl ? 12 : 20,
            right: isRtl ? 20 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Brand Header with Glowing Squircle Icon ──
              GestureDetector(
                onTap: () {
                  controller.zoomDrawerController.close?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/flutter_launcher_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'app_name'.tr,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Aura PDF Reader',
                            style: TextStyle(
                              color: textSecondary.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Live Quick Stats Bar ──
              Obx(() {
                final filesCount = controller.deviceFiles.isNotEmpty
                    ? controller.deviceFiles.length
                    : controller.libraryItems.where((i) => i.type == LibraryItemType.file).length;
                final foldersCount = controller.libraryItems.where((i) => i.type == LibraryItemType.folder).length;
                final favoritesCount = controller.libraryItems.where((i) => i.isFavorite).length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg.withValues(alpha: isDark ? 0.6 : 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF22304D) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatColumn('files'.tr, '$filesCount', const Color(0xFF38BDF8), textPrimary, textSecondary),
                      Container(width: 1, height: 26, color: theme.dividerColor),
                      _buildStatColumn('folders'.tr, '$foldersCount', const Color(0xFFFBBF24), textPrimary, textSecondary),
                      Container(width: 1, height: 26, color: theme.dividerColor),
                      _buildStatColumn('favorites'.tr, '$favoritesCount', const Color(0xFFF43F5E), textPrimary, textSecondary),
                    ],
                  ),
                );
              }),

              // ── Menu Navigation Items ──
              Expanded(
                child: Obx(() {
                  final activeTab = controller.currentTab.value;
                  final recycledCount = controller.recycledItems.length;

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      _buildNavTile(
                        context: context,
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'files'.tr,
                        iconColor: const Color(0xFF38BDF8),
                        iconBg: const Color(0xFF0284C7),
                        isSelected: activeTab == 1,
                        onTap: () {
                          controller.currentTab.value = 1;
                          controller.pageController.jumpToPage(1);
                          controller.zoomDrawerController.close?.call();
                        },
                      ),
                      _buildNavTile(
                        context: context,
                        icon: Icons.folder_rounded,
                        title: 'folders'.tr,
                        iconColor: const Color(0xFFFBBF24),
                        iconBg: const Color(0xFFD97706),
                        isSelected: activeTab == 2,
                        onTap: () {
                          controller.currentTab.value = 2;
                          controller.pageController.jumpToPage(2);
                          controller.zoomDrawerController.close?.call();
                        },
                      ),
                      _buildNavTile(
                        context: context,
                        icon: Icons.star_rounded,
                        title: 'favorites'.tr,
                        iconColor: const Color(0xFFF43F5E),
                        iconBg: const Color(0xFFE11D48),
                        isSelected: activeTab == 3,
                        onTap: () {
                          controller.currentTab.value = 3;
                          controller.pageController.jumpToPage(3);
                          controller.zoomDrawerController.close?.call();
                        },
                      ),
                      _buildNavTile(
                        context: context,
                        icon: Icons.history_rounded,
                        title: 'recents'.tr,
                        iconColor: const Color(0xFF2DD4BF),
                        iconBg: const Color(0xFF0D9488),
                        isSelected: activeTab == 0,
                        onTap: () {
                          controller.currentTab.value = 0;
                          controller.pageController.jumpToPage(0);
                          controller.loadRecentItems();
                          controller.zoomDrawerController.close?.call();
                        },
                      ),
                      _buildNavTile(
                        context: context,
                        icon: Icons.handyman_rounded,
                        title: 'tools'.tr,
                        iconColor: const Color(0xFFA855F7),
                        iconBg: const Color(0xFF7E22CE),
                        isSelected: activeTab == 4,
                        onTap: () {
                          controller.currentTab.value = 4;
                          controller.pageController.jumpToPage(4);
                          controller.zoomDrawerController.close?.call();
                        },
                      ),
                      _buildNavTile(
                        context: context,
                        icon: Icons.delete_outline_rounded,
                        title: 'recycle_bin'.tr,
                        iconColor: const Color(0xFFFB923C),
                        iconBg: const Color(0xFFEA580C),
                        badgeText: recycledCount > 0 ? '$recycledCount' : null,
                        isSelected: false,
                        onTap: () {
                          controller.zoomDrawerController.close?.call();
                          controller.loadRecycledItems();
                          _showRecycleBin(context, controller);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Divider(
                          color: isDark ? const Color(0xFF22304D) : const Color(0xFFE2E8F0),
                          height: 1,
                        ),
                      ),
                      _buildNavTile(
                        context: context,
                        icon: Icons.settings_rounded,
                        title: 'settings'.tr,
                        iconColor: const Color(0xFF94A3B8),
                        iconBg: const Color(0xFF475569),
                        isSelected: false,
                        onTap: () {
                          controller.zoomDrawerController.close?.call();
                          Get.toNamed(Routes.SETTINGS);
                        },
                      ),
                    ],
                  );
                }),
              ),

              // ── Theme Switcher Pill Card ──
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: isDark ? 0.6 : 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF22304D) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFFF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDark ? 'dark_mode'.tr : 'theme_light'.tr,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: isDark,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        final storage = Get.find<StorageService>();
                        final newMode = val ? 'dark' : 'light';
                        storage.saveThemeMode(newMode);
                        Get.changeThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                      },
                    ),
                  ],
                ),
              ),

              // ── Footer ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'v3.0.0',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'PDF Reader Pro',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color accent, Color textPrimary, Color textSecondary) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color iconBg,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                      color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Squircle icon container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : iconBg.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : iconColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? primaryColor : textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Color(0xFFFB923C),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isSelected)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecycleBin(BuildContext context, HomeController controller) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'recycle_bin'.tr,
              style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                final items = controller.recycledItems;
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_sweep_rounded, size: 64, color: textSecondaryColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'recycle_empty'.tr,
                          style: TextStyle(color: textSecondaryColor, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isFolder ? Icons.folder_rounded : Icons.picture_as_pdf_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.isFolder ? 'FOLDER'.tr : item.extension,
                        style: TextStyle(color: textSecondaryColor, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore_rounded, color: Colors.green),
                            onPressed: () => controller.restoreItem(item),
                            tooltip: 'restore'.tr,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                            onPressed: () => controller.deletePermanent(item),
                            tooltip: 'delete_permanent'.tr,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

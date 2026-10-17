import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final dividerCol = Theme.of(context).dividerColor;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/flutter_launcher_icon.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'app_name'.tr,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Premium Reader',
                    style: TextStyle(
                      color: textSecondaryColor,
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
                  context,
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'files'.tr,
                  onTap: () {
                    controller.currentTab.value = 1;
                    controller.pageController.jumpToPage(1);
                    Get.back();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.folder_rounded,
                  title: 'folders'.tr,
                  onTap: () {
                    controller.currentTab.value = 2;
                    controller.pageController.jumpToPage(2);
                    Get.back();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.star_rounded,
                  title: 'favorites'.tr,
                  onTap: () {
                    controller.currentTab.value = 3;
                    controller.pageController.jumpToPage(3);
                    Get.back();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.history_rounded,
                  title: 'recents'.tr,
                  onTap: () {
                    controller.currentTab.value = 0;
                    controller.pageController.jumpToPage(0);
                    controller.loadRecentItems();
                    Get.back();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.delete_outline_rounded,
                  title: 'recycle_bin'.tr,
                  onTap: () {
                    Get.back();
                    controller.loadRecycledItems();
                    _showRecycleBin(context, controller);
                  },
                ),
                Divider(color: dividerCol, indent: 20, endIndent: 20),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: 'settings'.tr,
                  onTap: () {
                    Get.back();
                    Get.toNamed('/settings');
                  },
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'v2.0.0',
              style: TextStyle(color: textSecondaryColor.withOpacity(0.5), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = Theme.of(context).primaryColor;

    return ListTile(
      leading: Icon(icon, color: primaryColor.withOpacity(0.8), size: 22),
      title: Text(
        title,
        style: TextStyle(color: textPrimaryColor, fontSize: 15),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      horizontalTitleGap: 0,
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
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: textSecondaryColor.withOpacity(0.3),
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
                        Icon(Icons.delete_sweep_rounded, size: 64, color: textSecondaryColor.withOpacity(0.3)),
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
                          color: primaryColor.withOpacity(0.08),
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

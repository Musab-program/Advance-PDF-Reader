// lib/modules/home/views/home_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/modules/home/widgets/main_drawer.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const MainDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(scaffoldKey),
            _buildSearchBar(),
            Expanded(
              child: Obx(() {
                if (controller.filteredItems.isEmpty) {
                  return _buildEmptyLibrary();
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: controller.filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = controller.filteredItems[index];
                    return _LibraryCard(
                      item: item,
                      onTap: () {
                        if (item.isFolder) {
                          controller.openFolder(item);
                        } else {
                          controller.openFile(item);
                        }
                      },
                      onDelete: () => _confirmDelete(context, index),
                      progress: item.isFile
                          ? controller.getFileProgress(item.path)
                          : null,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPickOptions(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int index) {
    Get.defaultDialog(
      title: 'Remove',
      middleText: 'Remove this item from your library?',
      backgroundColor: AppColors.surface,
      titleStyle: const TextStyle(color: AppColors.textPrimary),
      middleTextStyle: const TextStyle(color: AppColors.textSecondary),
      textCancel: 'Cancel',
      textConfirm: 'Remove',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: AppColors.textSecondary,
      onConfirm: () {
        controller.removeItem(index);
        Get.back();
      },
    );
  }

  void _showPickOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Add to Library',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Pick a PDF file
              _PickOption(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Add PDF File',
                subtitle: 'Pick a single PDF to add to your library',
                onTap: () { Get.back(); controller.pickPdfFile(); },
              ),
              const SizedBox(height: 12),

              // Pick a folder
              _PickOption(
                icon: Icons.folder_rounded,
                title: 'Add Folder',
                subtitle: 'Add a folder containing PDFs',
                highlight: true,
                onTap: () { Get.back(); controller.pickFolder(); },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(GlobalKey<ScaffoldState> key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textSecondary),
            onPressed: () => key.currentState?.openDrawer(),
          ),
          const Text('Files',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          IconButton(
            icon: const Icon(Icons.sort_rounded,
                color: AppColors.textSecondary),
            onPressed: () => _showSortOptions(Get.context!),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort By',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  // Direction Toggle Button
                  Obx(() => IconButton(
                    icon: Icon(
                      controller.isAscending.value 
                        ? Icons.arrow_upward_rounded 
                        : Icons.arrow_downward_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () => controller.toggleSortDirection(),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              
              Obx(() => _SortOption(
                title: 'Name',
                icon: Icons.sort_by_alpha_rounded,
                isSelected: controller.sortOrder.value == 'name',
                onTap: () { controller.setSortOrder('name'); },
              )),
              Obx(() => _SortOption(
                title: 'Date Modified',
                icon: Icons.calendar_today_rounded,
                isSelected: controller.sortOrder.value == 'date',
                onTap: () { controller.setSortOrder('date'); },
              )),
              Obx(() => _SortOption(
                title: 'Size',
                icon: Icons.data_usage_rounded,
                isSelected: controller.sortOrder.value == 'size',
                onTap: () { controller.setSortOrder('size'); },
              )),
              Obx(() => _SortOption(
                title: 'Type',
                icon: Icons.category_rounded,
                isSelected: controller.sortOrder.value == 'type',
                onTap: () { controller.setSortOrder('type'); },
              )),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        onChanged: (value) => controller.searchQuery.value = value,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Search within collection...',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined,
              size: 80, color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text('Your Library is Empty',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + to add PDF files or folders',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Library Card: shows folder or file
// ────────────────────────────────────────────────────────────────────────
class _LibraryCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final double? progress;

  const _LibraryCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            // ── Icon area ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: Container(
                width: 72,
                height: 90,
                color: item.isFolder
                    ? const Color(0xFF1E2A3A)
                    : AppColors.surfaceLight,
                child: Center(
                  child: Icon(
                    item.isFolder
                        ? Icons.folder_rounded
                        : Icons.picture_as_pdf_rounded,
                    color: item.isFolder
                        ? const Color(0xFF4FC3F7)
                        : AppColors.primary,
                    size: 36,
                  ),
                ),
              ),
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (item.isFolder
                                    ? const Color(0xFF4FC3F7)
                                    : AppColors.primary)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isFolder ? 'FOLDER' : item.extension,
                            style: TextStyle(
                                color: item.isFolder
                                    ? const Color(0xFF4FC3F7)
                                    : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.isFile && item.size > 0) ...[
                          const SizedBox(width: 8),
                          Text(FileUtils.formatSize(item.size),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                        if (progress != null && progress! > 0) ...[
                          const SizedBox(width: 8),
                          Text('${(progress! * 100).toInt()}%',
                              style: const TextStyle(
                                  color: AppColors.primary, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                    // Progress bar for files
                    if (progress != null && progress! > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.cardBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Chevron ──
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                item.isFolder
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
class _PickOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  const _PickOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: highlight
              ? Border.all(color: AppColors.primary.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: highlight
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color:
                      highlight ? AppColors.primary : AppColors.textSecondary,
                  size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
class _SortOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, 
          color: isSelected ? AppColors.primary : AppColors.textSecondary, 
          size: 22),
      title: Text(title,
          style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.05),
    );
  }
}

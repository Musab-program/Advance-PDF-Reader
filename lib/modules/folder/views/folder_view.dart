// lib/modules/folder/views/folder_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/modules/folder/controllers/folder_controller.dart';

class FolderView extends GetView<FolderController> {
  const FolderView({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: Obx(() {
        final lastFile = controller.lastReadFile.value;
        if (lastFile == null) return const SizedBox.shrink();
        
        return FloatingActionButton.extended(
          onPressed: controller.resumeReading,
          backgroundColor: primaryColor,
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: Text(
            'continue_reading'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }),
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──
            _buildAppBar(context),

            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  color: primaryColor,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                    children: [
                      // ── File count ──
                      Text(
                        '${controller.pdfFiles.length} ${"pdf_files".tr.toUpperCase()}',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── PDF List ──
                      ...List.generate(controller.pdfFiles.length, (index) {
                        return _FolderPdfCard(
                          pdf: controller.pdfFiles[index],
                          index: index,
                          onTap: () => controller.openPdf(index),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: textPrimaryColor, size: 20),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(
                      controller.folderName.value,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                const SizedBox(height: 2),
                Text('folders'.tr,
                    style: TextStyle(
                        color: textSecondaryColor, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.sort_rounded, color: textPrimaryColor),
            onPressed: () => _showSortOptions(context),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'sort_by'.tr,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(() => IconButton(
                    icon: Icon(
                      controller.isAscending.value 
                        ? Icons.arrow_upward_rounded 
                        : Icons.arrow_downward_rounded,
                      color: primaryColor,
                    ),
                    onPressed: controller.toggleSortDirection,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              _buildSortItem(context, 'name', Icons.sort_by_alpha_rounded, 'name'.tr),
              _buildSortItem(context, 'date', Icons.calendar_today_rounded, 'date_modified'.tr),
              _buildSortItem(context, 'size', Icons.data_usage_rounded, 'size'.tr),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortItem(BuildContext context, String value, IconData icon, String label) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final primaryColor = Theme.of(context).primaryColor;

    return Obx(() {
      final isSelected = controller.sortOrder.value == value;
      return ListTile(
        leading: Icon(icon, color: isSelected ? primaryColor : textSecondaryColor),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? textPrimaryColor : textSecondaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check_circle, color: primaryColor) : null,
        onTap: () {
          controller.setSortOrder(value);
          Get.back();
        },
      );
    });
  }
}

// ────────────────────────────────────────────────────────────────────────
class _FolderPdfCard extends StatelessWidget {
  final PdfEntity pdf;
  final int index;
  final VoidCallback onTap;

  const _FolderPdfCard({
    required this.pdf,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pdf.progress > 0
                ? primaryColor.withOpacity(0.25)
                : borderCol.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            // Number
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pdf.progress >= 1.0
                    ? primaryColor.withOpacity(0.15)
                    : borderCol.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: pdf.progress >= 1.0
                    ? Icon(Icons.check_rounded,
                        color: primaryColor, size: 18)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: pdf.progress > 0
                              ? primaryColor
                              : textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pdf.name,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(FileUtils.formatSize(pdf.size),
                          style: TextStyle(
                              color: textSecondaryColor, fontSize: 11)),
                      if (pdf.pageCount > 0) ...[
                        const SizedBox(width: 6),
                        Text('• ${pdf.pageCount} ${"pages".tr}',
                            style: TextStyle(
                                color: textSecondaryColor, fontSize: 11)),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '• ${pdf.statusText}',
                        style: TextStyle(
                          color: pdf.progress > 0
                              ? primaryColor
                              : textSecondaryColor,
                          fontSize: 11,
                          fontWeight: pdf.progress > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (pdf.progress > 0 && pdf.progress < 1.0) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pdf.progress,
                      backgroundColor: borderCol,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Favorite button
            GetBuilder<FolderController>(
              builder: (ctrl) {
                final isFav = ctrl.isFavorite(pdf.path);
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav ? Colors.amber : textSecondaryColor.withOpacity(0.4),
                    size: 22,
                  ),
                  onPressed: () => ctrl.toggleFavorite(pdf),
                );
              },
            ),

            Icon(Icons.chevron_right,
                color: textSecondaryColor, size: 18),
          ],
        ),
      ),
    );
  }
}

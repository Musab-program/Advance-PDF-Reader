// lib/modules/folder/views/folder_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/modules/folder/controllers/folder_controller.dart';

class FolderView extends GetView<FolderController> {
  const FolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Obx(() {
        final lastFile = controller.lastReadFile.value;
        if (lastFile == null) return const SizedBox.shrink();
        
        return FloatingActionButton.extended(
          onPressed: controller.resumeReading,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: const Text(
            'Continue Reading',
            style: TextStyle(
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
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                    children: [
                      // ── File count ──
                      Text(
                        '${controller.pdfFiles.length} PDF FILES',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(
                      controller.folderName.value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                const SizedBox(height: 2),
                const Text('Folder',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textPrimary),
            onPressed: () => _showSortOptions(context),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
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
                  const Text(
                    'Sort Files',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(() => IconButton(
                    icon: Icon(
                      controller.isAscending.value 
                        ? Icons.arrow_upward_rounded 
                        : Icons.arrow_downward_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: controller.toggleSortDirection,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              _buildSortItem('name', Icons.sort_by_alpha_rounded, 'Name'),
              _buildSortItem('date', Icons.calendar_today_rounded, 'Date Modified'),
              _buildSortItem('size', Icons.data_usage_rounded, 'Size'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortItem(String value, IconData icon, String label) {
    return Obx(() {
      final isSelected = controller.sortOrder.value == value;
      return ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pdf.progress > 0
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.cardBorder.withOpacity(0.4),
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
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: pdf.progress >= 1.0
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: pdf.progress > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(FileUtils.formatSize(pdf.size),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                      if (pdf.pageCount > 0) ...[
                        const SizedBox(width: 6),
                        Text('• ${pdf.pageCount} pages',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '• ${pdf.statusText}',
                        style: TextStyle(
                          color: pdf.progress > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
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
                      backgroundColor: AppColors.cardBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

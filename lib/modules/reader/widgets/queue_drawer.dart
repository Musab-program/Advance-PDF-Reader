// lib/modules/reader/widgets/queue_drawer.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';

class QueueDrawer extends GetView<ReaderController> {
  const QueueDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 52, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.playlist_play, color: AppColors.primary, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Reading Queue',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() => Text(
                      '${controller.pdfQueue.length} documents',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    )),
              ],
            ),
          ),

          // List
          Expanded(
            child: Obx(() {
              if (controller.pdfQueue.isEmpty) {
                return const Center(
                  child: Text('No documents', style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: controller.pdfQueue.length,
                itemBuilder: (context, index) {
                  final pdf = controller.pdfQueue[index];
                  final isCurrent = index == controller.currentIndex.value;

                  return InkWell(
                    onTap: () {
                      controller.jumpToFile(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary.withOpacity(0.12)
                            : Colors.transparent,
                        border: isCurrent
                            ? const Border(
                                left: BorderSide(color: AppColors.primary, width: 3),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCurrent
                                ? Icons.play_circle_filled
                                : Icons.picture_as_pdf_outlined,
                            color: isCurrent
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pdf.name,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: isCurrent
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (pdf.progress > 0) ...[
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: pdf.progress,
                                    backgroundColor: AppColors.cardBorder,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isCurrent
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    minHeight: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

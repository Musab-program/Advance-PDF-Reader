// lib/modules/reader/widgets/queue_drawer.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';

class QueueDrawer extends GetView<ReaderController> {
  const QueueDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 52, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.playlist_play, color: theme.primaryColor, size: 32),
                const SizedBox(height: 10),
                Text(
                  'reading_queue'.tr,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() => Text(
                      '${controller.pdfQueue.length} ${'documents'.tr}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                return Center(
                  child: Text(
                    'no_documents'.tr,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
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
                            ? theme.primaryColor.withOpacity(0.12)
                            : Colors.transparent,
                        border: isCurrent
                            ? Border(
                                left: BorderSide(color: theme.primaryColor, width: 3),
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
                                ? theme.primaryColor
                                : theme.colorScheme.onSurface.withOpacity(0.5),
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
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface.withOpacity(0.7),
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
                                    backgroundColor: theme.dividerColor,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isCurrent
                                          ? theme.primaryColor
                                          : theme.colorScheme.onSurface.withOpacity(0.4),
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

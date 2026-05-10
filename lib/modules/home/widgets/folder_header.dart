// lib/modules/home/widgets/folder_header.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_text_styles.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';

class FolderHeader extends GetView<HomeController> {
  const FolderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Folder',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: Colors.grey),
                ),
                Obx(() => Text(
                  controller.isLoading.value ? 'Loading...' : 'Folder View',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

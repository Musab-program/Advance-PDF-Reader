// lib/modules/reader/widgets/progress_bar.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';

class ProgressBar extends GetView<ReaderController> {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = controller.totalPages.value;
      final current = controller.currentPage.value;
      
      if (total == 0) return const SizedBox.shrink();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current page
          SizedBox(
            width: 30,
            child: Text(
              '$current',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          
          // Vertical divider
          Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          
          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: current.toDouble().clamp(1.0, total.toDouble()),
                min: 1.0,
                max: total.toDouble(),
                onChanged: (value) {
                  controller.jumpToPage(value.toInt());
                },
              ),
            ),
          ),

          // Total pages
          SizedBox(
            width: 30,
            child: Text(
              '$total',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      );
    });
  }
}

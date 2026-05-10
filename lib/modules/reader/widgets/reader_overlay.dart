// lib/modules/reader/widgets/reader_overlay.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/modules/reader/widgets/progress_bar.dart';

class ReaderOverlay extends GetView<ReaderController> {
  const ReaderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => AnimatedOpacity(
          opacity: controller.showOverlay.value ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !controller.showOverlay.value,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ─── Top Bar ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.only(top: 36, left: 4, right: 4, bottom: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      Expanded(
                        child: Obx(() {
                          final pdf = controller.currentPdf;
                          if (pdf == null) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pdf.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Obx(() {
                                final cur = controller.currentIndex.value + 1;
                                final total = controller.pdfQueue.length;
                                return Text(
                                  'Document $cur of $total',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ),
                      Obx(() => IconButton(
                        icon: Icon(
                          controller.isSinglePageMode.value 
                            ? Icons.grid_view_rounded 
                            : Icons.description_rounded, 
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: controller.isSinglePageMode.value 
                          ? 'Switch to Continuous Mode' 
                          : 'Switch to Single Page Mode (Fast)',
                        onPressed: controller.toggleLayoutMode,
                      )),
                      IconButton(
                        icon: const Icon(Icons.playlist_play, color: Colors.white),
                        tooltip: 'Queue',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ],
                  ),
                ),

                // ─── Bottom Controls ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous file/page
                      _ControlButton(
                        icon: Icons.skip_previous_rounded,
                        onTap: controller.handlePreviousAction,
                      ),
                      
                      const SizedBox(width: 8),

                      // Progress bar pill
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2B36),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const ProgressBar(),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Next file
                      _ControlButton(
                        icon: Icons.skip_next_rounded,
                        onTap: controller.goToNextFile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFF2B2B36),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}

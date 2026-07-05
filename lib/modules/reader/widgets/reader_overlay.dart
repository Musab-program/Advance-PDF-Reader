// lib/modules/reader/widgets/reader_overlay.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/modules/reader/widgets/progress_bar.dart';
import 'package:pdf_reader/modules/reader/widgets/smart_bottom_sheet.dart';

class ReaderOverlay extends GetView<ReaderController> {
  const ReaderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() => AnimatedOpacity(
          opacity: controller.showOverlay.value ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !controller.showOverlay.value,
            child: Stack(
              children: [
                // ── Column Layout for Top Bar and Bottom Controls ──
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ─── Top Bar ───────────────────────────────────────────────
                    Obx(() {
                      final isSearch = controller.isSearchMode.value;
                      return Container(
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
                            if (!isSearch) ...[
                              // Standard View Left: Back Button
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
                                          'document_index'.trParams({'current': '$cur', 'total': '$total'}),
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
                              // Standard View Right: Drawer, Search, Orientation, Three-Dots
                              IconButton(
                                icon: const Icon(Icons.menu, color: Colors.white),
                                tooltip: 'reading_queue'.tr,
                                onPressed: () => Scaffold.of(context).openDrawer(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.search_rounded, color: Colors.white),
                                tooltip: 'search_text_hint'.tr,
                                onPressed: controller.toggleSearchMode,
                              ),
                              IconButton(
                                icon: const Icon(Icons.screen_rotation_rounded, color: Colors.white),
                                tooltip: 'rotate_screen'.tr,
                                onPressed: controller.toggleOrientation,
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                                tooltip: 'tools'.tr,
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => const SmartBottomSheet(),
                                  );
                                },
                              ),
                            ] else ...[
                              // Search View Mode
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: controller.toggleSearchMode,
                              ),
                              Expanded(
                                child: TextField(
                                  focusNode: controller.searchFocusNode,
                                  controller: controller.searchTextController,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  onChanged: controller.startSearch,
                                  onSubmitted: (val) => controller.goToNextMatch(),
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'search_text_hint'.tr,
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              Obx(() {
                                final query = controller.searchQuery.value;
                                final count = controller.totalMatchesCount.value;
                                if (query.isEmpty) return const SizedBox.shrink();
                                if (count == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'not_found'.tr,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                final index = controller.currentMatchIndex.value + 1;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$index / $count',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }),
                              Obx(() => controller.totalMatchesCount.value > 0
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
                                          onPressed: controller.goToPrevMatch,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                          onPressed: controller.goToNextMatch,
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink()),
                            ],
                          ],
                        ),
                      );
                    }),

                    // ─── Bottom Controls (Untouched) ─────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Builder(
                        builder: (context) {
                          final bool isRtl = Directionality.of(context) == TextDirection.rtl;

                          // Dynamic settings based on language direction
                          final IconData firstIcon = isRtl ? Icons.skip_next_rounded : Icons.skip_previous_rounded;
                          final VoidCallback firstTap = controller.handlePreviousAction;

                          final IconData secondIcon = isRtl ? Icons.skip_previous_rounded : Icons.skip_next_rounded;
                          final VoidCallback secondTap = controller.goToNextFile;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // First button (Left in LTR [Prev], Right in RTL [Next])
                              _ControlButton(
                                icon: firstIcon,
                                onTap: firstTap,
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

                              // Second button (Right in LTR [Next], Left in RTL [Prev])
                              _ControlButton(
                                icon: secondIcon,
                                onTap: secondTap,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // ─── Floating Kindle-style Page Indicator ────────────────────
                Positioned(
                  bottom: 105,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Obx(() {
                      final current = controller.currentPage.value;
                      final total = controller.totalPages.value;
                      if (total == 0) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: controller.showGoToPageDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.find_in_page_outlined, color: theme.primaryColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$current / $total',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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

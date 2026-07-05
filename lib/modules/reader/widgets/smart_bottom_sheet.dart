// lib/modules/reader/widgets/smart_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';

class SmartBottomSheet extends GetView<ReaderController> {
  const SmartBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final pdf = controller.currentPdf;
    if (pdf == null) return const SizedBox.shrink();

    final sizeStr = FileUtils.formatSize(pdf.size);
    final extName = pdf.extension.toUpperCase().replaceAll('.', '');
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag Handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PDF format badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      extName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pdf.name,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sizeStr,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Quick Actions Grid ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickActionButton(
                    icon: Icons.print_outlined,
                    label: 'print'.tr,
                    onTap: () {
                      Get.back();
                      controller.printCurrentPdf();
                    },
                  ),
                  _QuickActionButton(
                    icon: Icons.share_outlined,
                    label: 'share'.tr,
                    onTap: () {
                      Get.back();
                      controller.shareCurrentPdf();
                    },
                  ),
                  _QuickActionButton(
                    icon: Icons.save_alt_outlined,
                    label: 'save_as'.tr,
                    onTap: () {
                      Get.back();
                      controller.saveAsCurrentPdf();
                    },
                  ),
                  _QuickActionButton(
                    icon: Icons.info_outline,
                    label: 'details'.tr,
                    onTap: () {
                      Get.back();
                      controller.showFileDetailsDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: 16),

              // ── Progress Control ──
              Obx(() {
                final total = controller.totalPages.value;
                final current = controller.currentPage.value;
                if (total == 0) return const SizedBox.shrink();

                final percent = ((current / total) * 100).toInt();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'reading_progress'.tr,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'page_of_total_param'.trParams({
                            'current': '$current',
                            'total': '$total',
                            'percent': '$percent'
                          }),
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        activeTrackColor: theme.primaryColor,
                        inactiveTrackColor: theme.cardColor,
                        thumbColor: theme.primaryColor,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        overlayColor: theme.primaryColor.withOpacity(0.15),
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
                  ],
                );
              }),
              const SizedBox(height: 16),

              // ── Tab Bar controls ──
              Obx(() {
                final activeTab = controller.activeBottomSheetTab.value;
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TabButton(
                        label: 'view_tab'.tr,
                        active: activeTab == 0,
                        onTap: () => controller.activeBottomSheetTab.value = 0,
                      ),
                      _TabButton(
                        label: 'convert_tab'.tr,
                        active: activeTab == 1,
                        onTap: () => controller.activeBottomSheetTab.value = 1,
                      ),
                      _TabButton(
                        label: 'more_tools_tab'.tr,
                        active: activeTab == 2,
                        onTap: () => controller.activeBottomSheetTab.value = 2,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // ── Tab Content Switcher ──
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: Obx(() {
                  switch (controller.activeBottomSheetTab.value) {
                    case 0:
                      return _buildViewTab(context);
                    case 1:
                      return _buildConvertTab(context);
                    case 2:
                      return _buildMoreToolsTab(context);
                    default:
                      return const SizedBox.shrink();
                  }
                }),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ── Tab 1: View Tab Content ──
  Widget _buildViewTab(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Theme Selection
        Text('reading_background'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 8),
        Obx(() {
          final currentTheme = controller.readingTheme.value;
          return Row(
            children: [
              Expanded(
                child: _ThemeSelectorPill(
                  theme: ReadingTheme.white,
                  label: 'theme_light'.tr,
                  bgColor: const Color(0xFFFAF8F5),
                  textColor: Colors.black,
                  active: currentTheme == ReadingTheme.white,
                  onTap: () => controller.setReadingTheme(ReadingTheme.white),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ThemeSelectorPill(
                  theme: ReadingTheme.dark,
                  label: 'theme_night'.tr,
                  bgColor: const Color(0xFF16161C),
                  textColor: Colors.white,
                  active: currentTheme == ReadingTheme.dark,
                  onTap: () => controller.setReadingTheme(ReadingTheme.dark),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ThemeSelectorPill(
                  theme: ReadingTheme.sepia,
                  label: 'theme_sepia'.tr,
                  bgColor: const Color(0xFFF4ECD8),
                  textColor: const Color(0xFF5B4636),
                  active: currentTheme == ReadingTheme.sepia,
                  onTap: () => controller.setReadingTheme(ReadingTheme.sepia),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ThemeSelectorPill(
                  theme: ReadingTheme.gray,
                  label: 'theme_dim'.tr,
                  bgColor: const Color(0xFF3A3A3C),
                  textColor: Colors.white70,
                  active: currentTheme == ReadingTheme.gray,
                  onTap: () => controller.setReadingTheme(ReadingTheme.gray),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 16),

        // Scroll Direction and Margins
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('scroll_orientation'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                  const SizedBox(height: 8),
                  Obx(() {
                    final isSingle = controller.isSinglePageMode.value;
                    return Row(
                      children: [
                        _ModeSelectionButton(
                          icon: Icons.unfold_more,
                          label: 'scroll_vertical'.tr,
                          active: !isSingle,
                          onTap: () {
                            if (isSingle) controller.toggleLayoutMode();
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModeSelectionButton(
                          icon: Icons.unfold_less,
                          label: 'scroll_horizontal'.tr,
                          active: isSingle,
                          onTap: () {
                            if (!isSingle) controller.toggleLayoutMode();
                          },
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('page_crop_margins'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                  const SizedBox(height: 4),
                  Obx(() => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'crop_margins'.tr,
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                        ),
                        value: controller.isCropMargins.value,
                        activeColor: theme.primaryColor,
                        onChanged: (val) {
                          controller.toggleCropMargins(val);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Manga Mode Switch
        Obx(() => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'manga_mode'.tr,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'manga_mode_desc'.tr,
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
              ),
              value: controller.isMangaMode.value,
              activeColor: theme.primaryColor,
              onChanged: (val) {
                controller.toggleMangaMode(val);
              },
            )),
        const SizedBox(height: 12),

        // Brightness Slider
        Text('brightness_overlay'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
        Obx(() => Row(
              children: [
                Icon(Icons.brightness_low, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 20),
                Expanded(
                  child: Slider(
                    value: controller.brightness.value,
                    min: 0.2,
                    max: 1.0,
                    activeColor: theme.primaryColor,
                    inactiveColor: theme.cardColor,
                    onChanged: (val) {
                      controller.brightness.value = val;
                    },
                  ),
                ),
                Icon(Icons.brightness_high, color: theme.colorScheme.onSurface, size: 20),
              ],
            )),
      ],
    );
  }

  // ── Tab 2: Convert Tab Content ──
  Widget _buildConvertTab(BuildContext context) {
    return Column(
      children: [
        _ToolTile(
          icon: Icons.image_outlined,
          title: 'convert_to_png'.tr,
          subtitle: 'convert_to_png_desc'.tr,
          onTap: () {
            Get.back();
            controller.convertPdfToImages();
          },
        ),
        const SizedBox(height: 8),
        _ToolTile(
          icon: Icons.text_snippet_outlined,
          title: 'extract_text'.tr,
          subtitle: 'extract_text_desc'.tr,
          onTap: () {
            Get.back();
            controller.extractTextToTxt();
          },
        ),
        const SizedBox(height: 8),
        _ToolTile(
          icon: Icons.compress_outlined,
          title: 'compress_pdf'.tr,
          subtitle: 'compress_pdf_desc'.tr,
          onTap: () {
            Get.back();
            controller.compressPdf();
          },
        ),
      ],
    );
  }

  // ── Tab 3: More Tools Tab Content ──
  Widget _buildMoreToolsTab(BuildContext context) {
    return Column(
      children: [
        _ToolTile(
          icon: Icons.merge_type,
          title: 'merge_documents'.tr,
          subtitle: 'merge_documents_desc'.tr,
          onTap: () {
            Get.back();
            controller.mergeDocumentsDialog();
          },
        ),
        const SizedBox(height: 8),
        _ToolTile(
          icon: Icons.call_split,
          title: 'split_pdf_pages'.tr,
          subtitle: 'split_pdf_pages_desc'.tr,
          onTap: () {
            Get.back();
            controller.splitPagesDialog();
          },
        ),
        const SizedBox(height: 8),
        _ToolTile(
          icon: Icons.branding_watermark_outlined,
          title: 'add_rotated_watermark'.tr,
          subtitle: 'add_rotated_watermark_desc'.tr,
          onTap: () {
            Get.back();
            controller.addWatermarkDialog();
          },
        ),
      ],
    );
  }
}

// ── Custom Helper Widgets ──

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor, width: 0.5),
                ),
                child: Icon(
                  icon,
                  color: theme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? theme.scaffoldBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSelectorPill extends StatelessWidget {
  final ReadingTheme theme;
  final String label;
  final Color bgColor;
  final Color textColor;
  final bool active;
  final VoidCallback onTap;

  const _ThemeSelectorPill({
    required this.theme,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? theme.primaryColor : theme.dividerColor,
            width: active ? 2.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ModeSelectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeSelectionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? theme.primaryColor.withOpacity(0.15) : theme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? theme.primaryColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.6),
                size: 16,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final double systemBottom = MediaQuery.of(context).padding.bottom;
    final double dynamicBottom = systemBottom > 24 ? systemBottom : 16.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => Get.back(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 550 : double.infinity,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: dynamicBottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag Handle ──
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Header (File Name & Size + Aura PDF Badge) ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1B4B)
                                : const Color(0xFFEEF2FF),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            extName,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFA5B4FC)
                                  : const Color(0xFF4F46E5),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
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
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                sizeStr,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Quick Actions Grid (4 Icons: Print, Share, Save As, Info) ──
                    Row(
                      children: [
                        _CleanActionCard(
                          icon: Icons.print_rounded,
                          label: 'print'.tr,
                          onTap: () {
                            Get.back();
                            controller.printCurrentPdf();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _CleanActionCard(
                          icon: Icons.share_rounded,
                          label: 'share'.tr,
                          onTap: () {
                            Get.back();
                            controller.shareCurrentPdf();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _CleanActionCard(
                          icon: Icons.save_alt_rounded,
                          label: 'save_as'.tr,
                          onTap: () {
                            Get.back();
                            controller.saveAsCurrentPdf();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _CleanActionCard(
                          icon: Icons.info_outline_rounded,
                          label: 'details'.tr,
                          onTap: () {
                            Get.back();
                            controller.showFileDetailsDialog();
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Reading Progress Box ──
                    Obx(() {
                      final total = controller.totalPages.value;
                      final current = controller.currentPage.value;
                      if (total == 0) return const SizedBox.shrink();

                      final percent = ((current / total) * 100).toInt();

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : const Color(0xFFF8FAFC),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'reading_progress'.tr,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'page_of_total_param'.trParams({
                                    'current': '$current',
                                    'total': '$total',
                                    'percent': '$percent'
                                  }),
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFA5B4FC)
                                        : primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                activeTrackColor: primaryColor,
                                inactiveTrackColor: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                                thumbColor: primaryColor,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                overlayColor: primaryColor.withValues(alpha: 0.15),
                              ),
                              child: Slider(
                                value: current
                                    .toDouble()
                                    .clamp(1.0, total.toDouble()),
                                min: 1.0,
                                max: total.toDouble(),
                                onChanged: (value) {
                                  controller.jumpToPage(value.toInt());
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // ── Reading Background Section ──
                    Text(
                      'reading_background'.tr,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final currentTheme = controller.readingTheme.value;
                      return Row(
                        children: [
                          Expanded(
                            child: _ThemeSelectorPill(
                              label: 'theme_light'.tr,
                              bgColor: const Color(0xFFFAF8F5),
                              textColor: Colors.black,
                              active: currentTheme == ReadingTheme.white,
                              onTap: () =>
                                  controller.setReadingTheme(ReadingTheme.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _ThemeSelectorPill(
                              label: 'theme_night'.tr,
                              bgColor: const Color(0xFF16161C),
                              textColor: Colors.white,
                              active: currentTheme == ReadingTheme.dark,
                              onTap: () =>
                                  controller.setReadingTheme(ReadingTheme.dark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _ThemeSelectorPill(
                              label: 'theme_sepia'.tr,
                              bgColor: const Color(0xFFF4ECD8),
                              textColor: const Color(0xFF5B4636),
                              active: currentTheme == ReadingTheme.sepia,
                              onTap: () =>
                                  controller.setReadingTheme(ReadingTheme.sepia),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _ThemeSelectorPill(
                              label: 'theme_dim'.tr,
                              bgColor: const Color(0xFF3A3A3C),
                              textColor: Colors.white70,
                              active: currentTheme == ReadingTheme.gray,
                              onTap: () =>
                                  controller.setReadingTheme(ReadingTheme.gray),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    // ── Manga Mode Switch ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Obx(() => SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'manga_mode'.tr,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'manga_mode_desc'.tr,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            value: controller.isMangaMode.value,
                            activeThumbColor: primaryColor,
                            onChanged: (val) {
                              controller.toggleMangaMode(val);
                            },
                          )),
                    ),
                    const SizedBox(height: 12),

                    // ── Brightness Slider ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'brightness_overlay'.tr,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Obx(() => Row(
                                children: [
                                  Icon(
                                    Icons.brightness_low_rounded,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                    size: 18,
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        activeTrackColor: primaryColor,
                                        inactiveTrackColor: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : const Color(0xFFCBD5E1),
                                        thumbColor: primaryColor,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                                overlayRadius: 12),
                                      ),
                                      child: Slider(
                                        value: controller.brightness.value,
                                        min: 0.2,
                                        max: 1.0,
                                        onChanged: (val) {
                                          controller.brightness.value = val;
                                        },
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.brightness_high_rounded,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    size: 18,
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Clean Custom Helpers ──

class _CleanActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _CleanActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark
                      ? const Color(0xFFA5B4FC)
                      : const Color(0xFF4F46E5),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSelectorPill extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final bool active;
  final VoidCallback onTap;

  const _ThemeSelectorPill({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? primaryColor : Colors.transparent,
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

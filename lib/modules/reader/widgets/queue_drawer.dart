// lib/modules/reader/widgets/queue_drawer.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';

class QueueDrawer extends GetView<ReaderController> {
  const QueueDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final cardBg = isDark ? const Color(0xFF151D30) : const Color(0xFFFFFFFF);

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // ── Modern Glassmorphism Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101726) : const Color(0xFFFFFFFF),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF4F46E5), const Color(0xFF818CF8)]
                            : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'reading_queue'.tr,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Obx(() => Text(
                              '${controller.pdfQueue.length} ${'documents'.tr}',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF6366F1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    onPressed: () => Scaffold.of(context).closeDrawer(),
                  ),
                ],
              ),
            ),

            // ── Document Cards List ──
            Expanded(
              child: Obx(() {
                if (controller.pdfQueue.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 48,
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'no_documents'.tr,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  itemCount: controller.pdfQueue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final pdf = controller.pdfQueue[index];
                    final isCurrent = index == controller.currentIndex.value;

                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Scaffold.of(context).closeDrawer();
                          controller.jumpToFile(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (isDark
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.16)
                                    : const Color(0xFF6366F1).withValues(alpha: 0.10))
                                : (isDark
                                    ? cardBg.withValues(alpha: 0.5)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent
                                  ? (isDark
                                      ? const Color(0xFF818CF8).withValues(alpha: 0.6)
                                      : const Color(0xFF6366F1).withValues(alpha: 0.5))
                                  : (isDark
                                      ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                                      : const Color(0xFFE2E8F0)),
                              width: isCurrent ? 1.5 : 1,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              // Icon or Indicator
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? primaryColor
                                      : (isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isCurrent
                                      ? Icons.play_arrow_rounded
                                      : Icons.picture_as_pdf_rounded,
                                  color: isCurrent
                                      ? Colors.white
                                      : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B)),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // File Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pdf.name,
                                      style: TextStyle(
                                        color: isCurrent
                                            ? (isDark ? Colors.white : primaryColor)
                                            : (isDark
                                                ? const Color(0xFFE2E8F0)
                                                : const Color(0xFF1E293B)),
                                        fontWeight: isCurrent
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (isCurrent) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'جاري القراءة',
                                              style: TextStyle(
                                                color: isDark
                                                    ? const Color(0xFFA5B4FC)
                                                    : primaryColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          FileUtils.formatSize(pdf.size),
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFF64748B)
                                                : const Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                _PlayingWaveIndicator(color: primaryColor),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayingWaveIndicator extends StatefulWidget {
  final Color color;
  const _PlayingWaveIndicator({required this.color});

  @override
  State<_PlayingWaveIndicator> createState() => _PlayingWaveIndicatorState();
}

class _PlayingWaveIndicatorState extends State<_PlayingWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final val = _anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(8 + (8 * val)),
            const SizedBox(width: 2.5),
            _bar(16 - (10 * val)),
            const SizedBox(width: 2.5),
            _bar(6 + (10 * val)),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(4.0, 16.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

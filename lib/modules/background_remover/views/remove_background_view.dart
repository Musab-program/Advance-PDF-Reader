import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/remove_background_controller.dart';

class RemoveBackgroundView extends StatelessWidget {
  const RemoveBackgroundView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RemoveBackgroundController());
    final primaryColor = Theme.of(context).primaryColor;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: Text('remove_background'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'pick_image'.tr,
            onPressed: controller.pickImage,
          ),
          Obx(() {
            if (controller.processedBytes.value != null) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded),
                    tooltip: 'share'.tr,
                    onPressed: controller.shareResult,
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'save_png'.tr,
                    onPressed: controller.savePng,
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    controller.statusMessage.value.isNotEmpty
                        ? controller.statusMessage.value
                        : 'processing_image'.tr,
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'offline_guarantee'.tr,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: controller.cancelOperation,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text('cancel'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: controller.pickImage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('retry'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.originalBytes.value == null) {
          return _buildEmptyState(context, controller, primaryColor, cardBg, textPrimary, textSecondary);
        }

        return Column(
          children: [
            // Informative offline & disclaimer banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: primaryColor.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'disclaimer_hint'.tr,
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ),
                  if (controller.isProcessing.value) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),

            // Main Canvas with Checkerboard
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Checkerboard background for transparency
                  const _Checkerboard(),

                  // Interactive image viewer with touch listener
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final displayBytes = controller.showOriginal.value
                          ? controller.originalBytes.value
                          : controller.processedBytes.value;

                      if (displayBytes == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 6.0,
                        panEnabled: controller.currentTool.value == TouchTool.none,
                        scaleEnabled: controller.currentTool.value == TouchTool.none,
                        child: Center(
                          child: GestureDetector(
                            onTapUp: (details) {
                              final renderBox = context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final local = details.localPosition;
                                final rx = (local.dx / renderBox.size.width).clamp(0.0, 1.0);
                                final ry = (local.dy / renderBox.size.height).clamp(0.0, 1.0);
                                controller.handleCanvasTap(rx, ry);
                              }
                            },
                            onPanUpdate: (details) {
                              final renderBox = context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final local = details.localPosition;
                                final rx = (local.dx / renderBox.size.width).clamp(0.0, 1.0);
                                final ry = (local.dy / renderBox.size.height).clamp(0.0, 1.0);
                                controller.handleCanvasPan(rx, ry);
                              }
                            },
                            child: Image.memory(
                              displayBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Floating Before/After toggle button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(20),
                      color: cardBg.withValues(alpha: 0.9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          controller.showOriginal.value = !controller.showOriginal.value;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                controller.showOriginal.value
                                    ? Icons.visibility_rounded
                                    : Icons.compare_rounded,
                                size: 16,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                controller.showOriginal.value ? 'original'.tr : 'preview_result'.tr,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Controls Panel
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sensitivity / Tolerance Slider
                    Row(
                      children: [
                        Text('tolerance'.tr, style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${controller.tolerance.value.toInt()}', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: controller.tolerance.value,
                        min: 5.0,
                        max: 100.0,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          controller.tolerance.value = val;
                        },
                      ),
                    ),

                    // Brush radius slider (only if eraser or restore selected)
                    if (controller.currentTool.value == TouchTool.eraser ||
                        controller.currentTool.value == TouchTool.restore) ...[
                      Row(
                        children: [
                          Text('brush_size'.tr, style: TextStyle(color: textPrimary, fontSize: 12)),
                          const Spacer(),
                          Text('${controller.brushRadius.value.toInt()}px', style: TextStyle(color: primaryColor, fontSize: 12)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: controller.brushRadius.value,
                          min: 5.0,
                          max: 60.0,
                          activeColor: primaryColor,
                          onChanged: (val) {
                            controller.brushRadius.value = val;
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Tool selector row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildToolButton(
                          context,
                          tool: TouchTool.none,
                          icon: Icons.pan_tool_rounded,
                          label: 'pan_zoom'.tr,
                          isSelected: controller.currentTool.value == TouchTool.none,
                          onTap: () => controller.currentTool.value = TouchTool.none,
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                        ),
                        _buildToolButton(
                          context,
                          tool: TouchTool.wand,
                          icon: Icons.auto_fix_high_rounded,
                          label: 'magic_wand'.tr,
                          isSelected: controller.currentTool.value == TouchTool.wand,
                          onTap: () => controller.currentTool.value = TouchTool.wand,
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                        ),
                        _buildToolButton(
                          context,
                          tool: TouchTool.eraser,
                          icon: Icons.cleaning_services_rounded,
                          label: 'eraser'.tr,
                          isSelected: controller.currentTool.value == TouchTool.eraser,
                          onTap: () => controller.currentTool.value = TouchTool.eraser,
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                        ),
                        _buildToolButton(
                          context,
                          tool: TouchTool.restore,
                          icon: Icons.brush_rounded,
                          label: 'restore_brush'.tr,
                          isSelected: controller.currentTool.value == TouchTool.restore,
                          onTap: () => controller.currentTool.value = TouchTool.restore,
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required TouchTool tool,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color textPrimary,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? primaryColor : textPrimary.withValues(alpha: 0.7)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    RemoveBackgroundController controller,
    Color primaryColor,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_fix_high_rounded, size: 64, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              'remove_background'.tr,
              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'remove_bg_hero_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: controller.pickImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              icon: const Icon(Icons.photo_library_rounded),
              label: Text('pick_image'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'offline_guarantee'.tr,
                    style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Checkerboard Painter for Transparency ──
class _Checkerboard extends StatelessWidget {
  const _Checkerboard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _CheckerboardPainter(isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  final bool isDark;
  _CheckerboardPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 14.0;
    final color1 = isDark ? const Color(0xFF1E222B) : const Color(0xFFF2F4F8);
    final color2 = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);

    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    int cols = (size.width / squareSize).ceil();
    int rows = (size.height / squareSize).ceil();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final paint = (r + c) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(c * squareSize, r * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

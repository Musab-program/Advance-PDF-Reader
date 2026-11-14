import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/remove_background_controller.dart';
import '../widgets/image_scanner_view.dart';
import '../widgets/preview_background_selector.dart';
import 'manual_brush_editor_view.dart';
import '../../pdf_tools/widgets/tool_empty_view.dart';

class RemoveBackgroundView extends StatelessWidget {
  const RemoveBackgroundView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RemoveBackgroundController());
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final cardBg = theme.cardColor;
    final textPrimary = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final textSecondary = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72) ?? Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'remove_background'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Obx(() {
            if (controller.processedBytes.value != null) {
              return PreviewBgMenuButton(
                currentMode: controller.previewBgMode.value,
                onSelected: (mode) => controller.previewBgMode.value = mode,
              );
            }
            return const SizedBox.shrink();
          }),
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
        // 1. Offline Guard Screen with Pull-to-Refresh & offline.png vector (No extra buttons)
        if (controller.isOffline.value) {
          return RefreshIndicator(
            onRefresh: () async {
              final ok = await controller.checkConnectivity(showSnackbarIfOffline: false);
              if (ok && controller.originalBytes.value != null && controller.processedBytes.value == null) {
                controller.applyAiMatting();
              }
            },
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - kToolbarHeight - 80,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 230,
                            maxWidth: 290,
                          ),
                          child: Image.asset(
                            'assets/vector/offline.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.wifi_off_rounded,
                              size: 72,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            'غير متصل بالإنترنت\nهذه الأداة تحتاج إلى اتصال بالإنترنت\nاسحب الشاشة للأسفل للتحديث بعد الاتصال',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.6,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // 2. Loading / AI Processing State with Live Scanner Animation
        if (controller.isLoading.value) {
          if (controller.originalBytes.value != null) {
            return ImageScannerView(
              imageBytes: controller.originalBytes.value!,
              onCancel: controller.cancelOperation,
            );
          }
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        // 3. Error State
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 52),
                  const SizedBox(height: 14),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: controller.originalBytes.value != null
                            ? controller.applyAiMatting
                            : controller.pickImage,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('retry'.tr),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: controller.pickImage,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: Text('pick_image'.tr),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // 4. Empty State with remove_background.png vector
        if (controller.originalBytes.value == null) {
          return ToolEmptyView(
            imagePath: 'assets/vector/remove_background.png',
            title: 'remove_background'.tr,
            description: 'عزل خلفيات الصور بدقة فائقة باستخدام الذكاء الاصطناعي وبصيغة PNG شفافة بدون أي علامة مائية.',
            actionLabel: 'pick_image'.tr,
            actionIcon: Icons.add_photo_alternate_rounded,
            onAction: controller.pickImage,
          );
        }

        // 5. Processed Result Canvas
        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PreviewBackgroundCanvas(mode: controller.previewBgMode.value),
                  Builder(
                    builder: (context) {
                      final displayBytes = controller.showOriginal.value
                          ? controller.originalBytes.value
                          : (controller.processedBytes.value ?? controller.originalBytes.value);

                      if (displayBytes == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 6.0,
                        child: Center(
                          child: Image.memory(
                            displayBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),

                  // Floating Before/After toggle button
                  Positioned(
                    top: 12,
                    right: 12,
                    left: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(20),
                          color: cardBg.withValues(alpha: 0.92),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              controller.showOriginal.value = !controller.showOriginal.value;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(20),
                          color: primaryColor,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final orig = controller.originalBytes.value;
                              final cutout = controller.processedBytes.value;
                              if (orig == null || cutout == null) return;
                              final updated = await ManualBrushEditorView.open(
                                context: context,
                                originalBytes: orig,
                                cutoutBytes: cutout,
                                initialPreviewBg: controller.previewBgMode.value,
                              );
                              if (updated != null) {
                                controller.processedBytes.value = updated;
                                AppToast.showSuccess('تم تطبيق التعديلات بنجاح ✨');
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'تعديل متناهي الدقة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: controller.pickImage,
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                        label: Text(
                          'pick_image'.tr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: controller.savePng,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          'save_png'.tr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
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
}

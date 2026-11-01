import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf_reader/modules/html_reader/controllers/html_reader_controller.dart';

class HtmlReaderView extends GetView<HtmlReaderController> {
  const HtmlReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = theme.cardColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimaryColor, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Obx(() => Text(
              controller.fileName.value,
              style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
        actions: [
          // Toggle between Code & Preview / Run
          Obx(() {
            final isPreview = controller.isPreview.value;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: FilledButton.tonalIcon(
                onPressed: controller.isLoading.value ? null : controller.togglePreview,
                icon: Icon(
                  isPreview ? Icons.code_rounded : Icons.play_arrow_rounded,
                  size: 18,
                  color: isPreview ? primaryColor : Colors.white,
                ),
                label: Text(
                  isPreview ? 'view_code'.tr : 'html_preview'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPreview ? primaryColor : Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isPreview
                      ? primaryColor.withValues(alpha: 0.15)
                      : const Color(0xFF2E7D32), // Green run button
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            );
          }),
          Obx(() {
            if (controller.isPreview.value) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.text_decrease_rounded, color: textPrimaryColor, size: 20),
                  onPressed: controller.decreaseFontSize,
                  tooltip: 'Decrease font size',
                ),
                IconButton(
                  icon: Icon(Icons.text_increase_rounded, color: textPrimaryColor, size: 20),
                  onPressed: controller.increaseFontSize,
                  tooltip: 'Increase font size',
                ),
              ],
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (controller.isPreview.value) {
            if (controller.hasPreviewError.value) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        controller.previewErrorMessage.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textPrimaryColor, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: controller.loadPreview,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Stack(
              children: [
                if (controller.webViewController != null)
                  WebViewWidget(controller: controller.webViewController!),
                if (controller.isLoadingPreview.value)
                  Container(
                    color: cardBg.withValues(alpha: 0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryColor),
                          const SizedBox(height: 12),
                          Text(
                            'جاري تحميل المعاينة...',
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }

          // Source code view
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: SelectableText(
                controller.htmlContent.value,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: controller.fontSize.value,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

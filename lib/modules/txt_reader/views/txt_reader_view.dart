// lib/modules/txt_reader/views/txt_reader_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_reader/core/utils/app_toast.dart';
import 'package:pdf_reader/core/utils/pdf_text_layout.dart';
import 'package:pdf_reader/modules/txt_reader/controllers/txt_reader_controller.dart';

class TxtReaderView extends GetView<TxtReaderController> {
  const TxtReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          IconButton(
            icon: Icon(Icons.text_decrease_rounded, color: textPrimaryColor),
            onPressed: controller.decreaseFontSize,
            tooltip: 'txt_decrease_font'.tr,
          ),
          Obx(() => Center(
                child: Text(
                  '${controller.fontSize.value.toInt()}',
                  style: TextStyle(color: textSecondaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              )),
          IconButton(
            icon: Icon(Icons.text_increase_rounded, color: textPrimaryColor),
            onPressed: controller.increaseFontSize,
            tooltip: 'txt_increase_font'.tr,
          ),
          IconButton(
            icon: Icon(Icons.copy_all_rounded, color: textPrimaryColor, size: 20),
            onPressed: () async {
              final text = controller.textContent.value;
              if (text.trim().isEmpty) return;
              await Clipboard.setData(ClipboardData(text: text));
              AppToast.showSuccess('txt_copied_all'.tr);
            },
            tooltip: 'txt_copy_all'.tr,
          ),
          IconButton(
            icon: Icon(Icons.share_rounded, color: textPrimaryColor, size: 20),
            onPressed: () async {
              final path = controller.filePath.value;
              if (path.isNotEmpty) {
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(path)],
                    sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
              }
            },
            tooltip: 'txt_share_file'.tr,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final content = controller.textContent.value;
              if (content.trim().isEmpty) {
                return Center(
                  child: Text(
                    'txt_empty_file'.tr,
                    style: TextStyle(color: textSecondaryColor, fontSize: 15),
                  ),
                );
              }

              final lines = content.split('\n');
              final currentFont = controller.fontSize.value;

              return SelectionArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in lines)
                        if (line.trim().isEmpty)
                          const SizedBox(height: 10)
                        else if (_isPageHeaderLine(line.trim()))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    line.replaceAll('-', '').trim(),
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: (currentFont - 2).clamp(11.0, 22.0),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                              ],
                            ),
                          )
                        else
                          Directionality(
                            textDirection: PdfTextLayout.isRtlDominantText(line)
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                line,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: currentFont,
                                  height: 1.72,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  static bool _isPageHeaderLine(String trimmed) =>
      trimmed.startsWith('---') && trimmed.endsWith('---') && trimmed.length >= 6;
}

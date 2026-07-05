// lib/modules/txt_reader/views/txt_reader_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
            tooltip: 'Decrease font size',
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
            tooltip: 'Increase font size',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SelectableText(
              controller.textContent.value,
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: controller.fontSize.value,
                height: 1.6,
                fontFamily: 'Roboto', // Simple clean readable sans-serif
              ),
            ),
          );
        }),
      ),
    );
  }
}

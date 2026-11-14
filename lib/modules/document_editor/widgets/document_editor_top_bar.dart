import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/document_editor_controller.dart';
import '../models/editor_models.dart';

class DocumentEditorTopBar extends StatelessWidget {
  final DocumentEditorController controller;

  const DocumentEditorTopBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final dividerCol = theme.dividerColor;
    final primary = theme.primaryColor;

    return Obx(() {
      final isDrawing = controller.isDrawingModeActive.value;

      if (isDrawing) {
        // Active Drawing Mode Top Bar
        return Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 14,
            right: 14,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: dividerCol.withValues(alpha: 0.5))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: controller.exitActiveTool,
                child: Text(
                  'wps_cancel'.tr,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      tooltip: 'wps_undo'.tr,
                      onPressed: controller.undo,
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo_rounded, size: 20),
                      tooltip: 'wps_redo'.tr,
                      onPressed: controller.redo,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Obx(() {
                        String title = 'wps_tab_annotate'.tr;
                        if (controller.activeAnnotateTool.value == AnnotateTool.pen) {
                          title = 'wps_tool_pen'.tr;
                        } else if (controller.activeAnnotateTool.value == AnnotateTool.highlighter) {
                          title = 'wps_tool_highlighter'.tr;
                        } else if (controller.activeAnnotateTool.value == AnnotateTool.underline) {
                          title = 'wps_tool_underline'.tr;
                        } else if (controller.activeAnnotateTool.value == AnnotateTool.strikeout) {
                          title = 'wps_tool_strikeout'.tr;
                        } else if (controller.activeAnnotateTool.value == AnnotateTool.eraser) {
                          title = 'wps_tool_eraser'.tr;
                        }
                        return Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: controller.exitActiveTool,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('wps_done'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      }

      // Standard Reading Mode Top Bar
      return Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6,
          left: 6,
          right: 6,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.96),
          border: Border(bottom: BorderSide(color: dividerCol.withValues(alpha: 0.5))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => controller.requestExit(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() => Text(
                        controller.fileName.value.isEmpty ? 'tool_document_editor'.tr : controller.fileName.value,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )),
                  Obx(() => Text(
                        '${'wps_page'.tr} ${controller.currentPage.value} / ${controller.totalPages.value}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      )),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.undo_rounded, size: 20),
              tooltip: 'wps_undo'.tr,
              onPressed: controller.undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded, size: 20),
              tooltip: 'wps_redo'.tr,
              onPressed: controller.redo,
            ),
            IconButton(
              icon: Icon(Icons.save_rounded, color: primary),
              tooltip: 'حفظ المستند المعدل',
              onPressed: () => controller.showSaveOptionsSheet(context),
            ),
          ],
        ),
      );
    });
  }
}

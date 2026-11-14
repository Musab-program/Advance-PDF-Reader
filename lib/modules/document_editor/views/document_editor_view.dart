import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';
import '../controllers/document_editor_controller.dart';
import '../models/editor_models.dart';
import '../widgets/document_editor_top_bar.dart';
import '../widgets/document_editor_toolbar.dart';
import '../widgets/page_annotation_overlay.dart';
import '../../pdf_tools/widgets/tool_empty_view.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

class DocumentEditorView extends StatefulWidget {
  final String? initialFilePath;

  const DocumentEditorView({super.key, this.initialFilePath});

  @override
  State<DocumentEditorView> createState() => _DocumentEditorViewState();
}

class _DocumentEditorViewState extends State<DocumentEditorView> {
  late final DocumentEditorController controller;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<DocumentEditorController>()) {
      Get.delete<DocumentEditorController>(force: true);
    }
    controller = Get.put(
      DocumentEditorController(initialFilePath: widget.initialFilePath),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<DocumentEditorController>()) {
      Get.delete<DocumentEditorController>(force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    return Obx(() {
      // 1. Loading State when launching directly with an initial file (Prevents empty illustration flash!)
      final bool isLoadingInitialFile = controller.filePath.value.isEmpty &&
          ((widget.initialFilePath != null &&
                  widget.initialFilePath!.isNotEmpty &&
                  !controller.loadFailed.value) ||
              controller.isLoading.value);

      if (isLoadingInitialFile) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('tool_document_editor'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Get.back(),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primary),
                const SizedBox(height: 16),
                Text(
                  'wps_opening_document'.tr,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 2. Empty State (No file selected yet)
      if (controller.filePath.value.isEmpty) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('tool_document_editor'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Get.back(),
            ),
          ),
          body: ToolEmptyView(
            imagePath: 'assets/vector/document_editor.png',
            title: 'tool_document_editor'.tr,
            description: 'desc_document_editor'.tr,
            actionLabel: 'open_file'.tr,
            actionIcon: Icons.file_open_rounded,
            onAction: controller.pickAndLoadFile,
          ),
        );
      }

      // 3. Editor State (File loaded) with Unsaved Changes PopScope Guard
      return PopScope(
        canPop: !controller.hasUnsavedChanges.value,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await controller.requestExit(context);
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFE2E8F0),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ─── Top Bar ───
                DocumentEditorTopBar(controller: controller),

                // ─── Main Viewer Stack ───
                Expanded(
                  child: Stack(
                    children: [
                      // PDF Canvas Viewer
                      PdfViewer.file(
                        controller.filePath.value,
                        controller: controller.pdfViewerController,
                        params: PdfViewerParams(
                          backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFE2E8F0),
                          margin: 10.0,
                          scrollPhysics: const BouncingScrollPhysics(),
                          sizeDelegateProvider: const PdfViewerSizeDelegateProviderSmart(
                            minScale: 0.1,
                            maxScale: 15.0,
                            smartMaxScale: 2.5,
                            maxPagesVisible: 4.0,
                          ),
                          panAxis: PanAxis.free,
                          pageAnchor: PdfPageAnchor.top,
                          boundaryMargin: const EdgeInsets.all(40.0),
                          verticalCacheExtent: 2.0,
                          horizontalCacheExtent: 1.0,
                          customizeContextMenuItems: (params, items) {
                            if (!controller.isDrawingModeActive.value &&
                                params.textSelectionDelegate.hasSelectedText) {
                              items.addAll([
                                ContextMenuButtonItem(
                                  label: 'wps_markup_highlight'.tr,
                                  onPressed: () {
                                    controller.addMarkupFromTextSelection(
                                      params.textSelectionDelegate,
                                      StampType.highlightRect,
                                    );
                                    params.dismissContextMenu();
                                  },
                                ),
                                ContextMenuButtonItem(
                                  label: 'wps_markup_underline'.tr,
                                  onPressed: () {
                                    controller.addMarkupFromTextSelection(
                                      params.textSelectionDelegate,
                                      StampType.underlineRect,
                                    );
                                    params.dismissContextMenu();
                                  },
                                ),
                                ContextMenuButtonItem(
                                  label: 'wps_markup_strikeout'.tr,
                                  onPressed: () {
                                    controller.addMarkupFromTextSelection(
                                      params.textSelectionDelegate,
                                      StampType.strikeoutRect,
                                    );
                                    params.dismissContextMenu();
                                  },
                                ),
                              ]);
                            }
                          },
                          onPageChanged: (page) {
                            if (page != null) {
                              controller.onPageChanged(page);
                            }
                          },
                          onGeneralTap: (context, vController, details) {
                            if (details.type == PdfViewerGeneralTapType.tap) {
                              if (!controller.isDrawingModeActive.value &&
                                  controller.eyedropperTargetStampId.value == null) {
                                controller.selectStamp(null);
                              }
                            }
                            return false;
                          },
                          pageOverlaysBuilder: (context, pageRect, page) {
                            return [
                              Positioned.fill(
                                child: PageAnnotationOverlay(
                                  pageIndex: page.pageNumber - 1,
                                  pageSize: Size(pageRect.width, pageRect.height),
                                  controller: controller,
                                  pdfPage: page,
                                ),
                              ),
                            ];
                          },
                        ),
                      ),

                      // ─── Eyedropper Instruction Banner ───
                      if (controller.isEyedropperActive)
                        Positioned(
                          top: 12,
                          left: 20,
                          right: 20,
                          child: Center(
                            child: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(24),
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.colorize_rounded, size: 18, color: primary),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'wps_eyedropper_hint'.tr,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: controller.cancelEyedropper,
                                      child: Text('cancel'.tr, style: const TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ─── Fast Dynamic Scroller on the Right Edge ───
                      Positioned(
                        right: 4,
                        top: 40,
                        bottom: 40,
                        child: _FastScrollerWidget(controller: controller),
                      ),

                      // ─── Floating Page Indicator Badge & Zoom Controls ───
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Page Badge
                              GestureDetector(
                                onTap: () => _showGoToPageDialog(context, controller),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: theme.dividerColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.find_in_page_outlined, size: 14, color: primary),
                                      const SizedBox(width: 6),
                                      Obx(() => Text(
                                            '${controller.currentPage.value} / ${controller.totalPages.value}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Zoom Pill [- 100% +]
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.cardColor.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: theme.dividerColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_rounded, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      tooltip: 'wps_shrink'.tr,
                                      onPressed: controller.zoomOut,
                                    ),
                                    GestureDetector(
                                      onTap: controller.resetZoom,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Obx(() => Text(
                                              '${(controller.currentZoom.value * 100).toInt()}%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            )),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_rounded, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      tooltip: 'wps_enlarge'.tr,
                                      onPressed: controller.zoomIn,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ─── Saving Progress Overlay ───
                      if (controller.isSaving.value)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: primary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'wps_saving_changes'.tr,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Obx(() => Text(
                                        '${(controller.saveProgress.value * 100).toInt()}%',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── Bottom Toolbar (WPS Architecture) ───
                DocumentEditorToolbar(controller: controller),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showGoToPageDialog(BuildContext context, DocumentEditorController controller) {
    final textController = TextEditingController(text: '${controller.currentPage.value}');
    LuxuryDialog.showCustom(
      context,
      builder: (ctx) => LuxuryDialog(
        compact: true,
        icon: Icons.find_in_page_rounded,
        title: 'go_to_page'.tr,
        body: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '${'page_number'.tr} (1 - ${controller.totalPages.value})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        secondaryButtonText: 'cancel'.tr,
        onSecondaryPressed: () {},
        primaryButtonText: 'confirm'.tr,
        primaryButtonIcon: Icons.arrow_forward_rounded,
        closeOnPrimary: false,
        onPrimaryPressed: () {
          final target = int.tryParse(textController.text.trim());
          if (target != null && target >= 1 && target <= controller.totalPages.value) {
            controller.jumpToPage(target);
            Navigator.of(ctx).pop();
          }
        },
      ),
    );
  }
}

class _FastScrollerWidget extends StatelessWidget {
  final DocumentEditorController controller;

  const _FastScrollerWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            final double height = constraints.maxHeight;
            if (height <= 0 || controller.totalPages.value <= 1) return;
            final double fraction = (details.localPosition.dy / height).clamp(0.0, 1.0);
            final targetPage = (fraction * (controller.totalPages.value - 1) + 1).round();
            controller.jumpToPage(targetPage);
          },
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Obx(() {
              final total = controller.totalPages.value;
              final current = controller.currentPage.value;
              final fraction = total > 1 ? (current - 1) / (total - 1) : 0.0;
              final alignmentY = (fraction * 2.0 - 1.0).clamp(-1.0, 1.0);

              return Align(
                alignment: Alignment(0, alignmentY),
                child: Container(
                  width: 14,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.unfold_more_rounded, size: 12, color: Colors.white),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

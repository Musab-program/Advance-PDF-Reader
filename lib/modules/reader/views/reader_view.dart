// lib/modules/reader/views/reader_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';
import 'package:pdf_reader/modules/reader/widgets/reader_overlay.dart';
import 'package:pdf_reader/modules/reader/widgets/queue_drawer.dart';
import 'package:pdf_reader/core/widgets/custom_splash_screen.dart';

class ReaderView extends GetView<ReaderController> {
  const ReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      drawer: const QueueDrawer(),
      body: GetBuilder<ReaderController>(
        builder: (ctrl) {
          if (ctrl.isLoading.value && ctrl.pdfQueue.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3F8CFF)),
            );
          }
          if (ctrl.pdfQueue.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open,
                      color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text('No PDFs found',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Go Back')),
                ],
              ),
            );
          }

          final pdf = ctrl.currentPdf!;

          return Stack(
            children: [
              // ── PDF Viewer ──
              // GestureDetector handles tap-for-overlay.
              GestureDetector(
                onTap: ctrl.toggleOverlay,
                behavior: HitTestBehavior.translucent,
                  child: Obx(() {
                  // Fallback to identity matrix filter to ensure ColorFiltered wrapper is ALWAYS present.
                  // This keeps the widget tree type structure identical and prevents Flutter from destroying
                  // the PdfViewer state and resetting the page position when switching themes.
                  final filter = ctrl.themeColorFilter ?? const ColorFilter.matrix(<double>[
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    0, 0, 0, 1, 0,
                  ]);

                  return ColorFiltered(
                    colorFilter: filter,
                    child: PdfViewer.file(
                      pdf.path,
                      key: ValueKey('${pdf.path}_${ctrl.isSinglePageMode.value}'),
                      controller: ctrl.pdfViewerController,
                      params: PdfViewerParams(
                        // ── Background color ──
                        backgroundColor: ctrl.themeBackgroundColor,

                        // ── Side margins ──
                        margin: ctrl.isMangaMode.value ? 0.0 : 8.0,

                        // ── Viewer single tap overlay toggler ──
                        viewerOverlayBuilder: (context, size, handleLinkTap) => [
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              handleLinkTap(details.localPosition);
                              ctrl.toggleOverlay();
                            },
                            child: IgnorePointer(
                              child: SizedBox(
                                width: size.width,
                                height: size.height,
                              ),
                            ),
                          ),
                        ],

                        // ── Continuous vertical / Horizontal page layout ──
                        layoutPages: ctrl.isSinglePageMode.value
                            ? _buildHorizontalLayout
                            : _buildVerticalLayout,

                        // ── Page change callback ──
                        onPageChanged: (int? pageNumber) {
                          if (pageNumber != null) {
                            ctrl.onPageChanged(pageNumber);
                          }
                        },

                        // ── Document ready callback ──
                        onViewerReady: (document, viewerController) {
                          ctrl.onDocumentReady(document);
                        },

                        // ── Memory cap ──
                        maxImageBytesCachedOnMemory: 512 * 1024 * 1024,

                        // ── Disable aggressive cache limits to allow text PDFs to be fully cached ──
                        limitRenderingCache: false,

                        // ── Rendering scale ──
                        getPageRenderingScale: (context, page, controller, estimatedScale) {
                          final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
                          // If it is a small file (likely text-heavy), render it at a slightly lower scale
                          // (capped between 1.5 and 2.5) to make page loading and flipping instantaneous.
                          // For large files (images/manga), use higher resolution cap (3.3x) for maximum crispness.
                          if (!ctrl.isLargeFile.value) {
                            return estimatedScale.clamp(0.5, (devicePixelRatio * 0.75).clamp(1.5, 2.5));
                          }
                          return estimatedScale.clamp(0.5, devicePixelRatio * 1.1);
                        },

                        // ── Zoom limits ──
                        minScale: 0.5,
                        maxScale: 4.0,

                        // ── Loading placeholder ──
                        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
                            Container(
                              color: ctrl.themeBackgroundColor,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF3F8CFF), strokeWidth: 2),
                              ),
                            ),

                        // ── Error placeholder ──
                        errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
                          child: Text(
                            'Error loading page',
                            style: TextStyle(color: Colors.red.shade300),
                          ),
                        ),

                        // ── Custom Paint Callbacks for Text Search Highlights ──
                        pagePaintCallbacks: ctrl.textSearcher != null 
                            ? [ctrl.textSearcher!.pageTextMatchPaintCallback]
                            : null,

                        // ── Page Overlays (Watermark) ──
                        pageOverlaysBuilder: (context, pageRect, page) {
                          return [
                            Positioned.fill(
                              child: Obx(() {
                                final watermark = ctrl.watermarkText.value;
                                if (watermark.isEmpty) return const SizedBox.shrink();
                                return IgnorePointer(
                                  child: Center(
                                    child: RotationTransition(
                                      turns: const AlwaysStoppedAnimation(-45 / 360),
                                      child: Opacity(
                                        opacity: 0.12,
                                        child: Text(
                                          watermark,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                              );
                            }),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              }),
            ),

              // ── Brightness overlay dimmer ──
              Obx(() {
                final opacity = 1.0 - ctrl.brightness.value;
                if (opacity <= 0.0) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(opacity * 0.75),
                    ),
                  ),
                );
              }),

              // ── Overlay (toggle on tap) ──
              const ReaderOverlay(),

              // ── Loading Splash Screen ──
              Obx(() {
                if (ctrl.isDocumentLoading.value) {
                  return CustomSplashScreen(title: pdf.name);
                }
                return const SizedBox.shrink();
              }),
            ],
          );
        },
      ),
    );
  }
}

// ── Vertical layout with custom margins and cropping support ──
PdfPageLayout _buildVerticalLayout(
    List<PdfPage> pages, PdfViewerParams params) {
  final ctrl = Get.find<ReaderController>();
  final isCrop = ctrl.isCropMargins.value;
  final isManga = ctrl.isMangaMode.value;

  final double sidePadding = isManga ? 0.0 : (isCrop ? -16.0 : 4.0);
  final double pageGap = isManga ? 0.0 : 8.0;

  final pageLayouts = <Rect>[];
  double y = isManga ? 0.0 : 4.0;

  final refWidth = pages.isNotEmpty ? pages.first.width : 1.0;
  final displayWidth = isCrop ? refWidth * 1.18 : refWidth;

  for (final page in pages) {
    final pageHeight = page.height / page.width * displayWidth;
    final pageRect = Rect.fromLTWH(
      isCrop ? - (displayWidth - refWidth) / 2 : sidePadding,
      y,
      displayWidth,
      pageHeight,
    );
    pageLayouts.add(pageRect);
    y += pageHeight + pageGap;
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(refWidth + (isCrop ? 0 : sidePadding * 2), y + (isManga ? 0.0 : 4.0)),
  );
}

// ── Horizontal layout with cropping support ──
PdfPageLayout _buildHorizontalLayout(
    List<PdfPage> pages, PdfViewerParams params) {
  final ctrl = Get.find<ReaderController>();
  final isCrop = ctrl.isCropMargins.value;
  final isManga = ctrl.isMangaMode.value;

  final pageLayouts = <Rect>[];
  double x = isManga ? 0.0 : 8.0;
  final double pageGap = isManga ? 0.0 : 16.0;

  // Find max page height to size the document height
  final maxHeight = pages.isNotEmpty 
      ? pages.fold(0.0, (maxVal, page) => max(maxVal, page.height)) 
      : 1.0;

  for (final page in pages) {
    final displayWidth = isCrop ? page.width * 1.18 : page.width;
    final displayHeight = isCrop ? page.height * 1.18 : page.height;

    final pageRect = Rect.fromLTWH(
      x + (isCrop ? - (displayWidth - page.width) / 2 : 0),
      (maxHeight - displayHeight) / 2 + (isCrop ? - (displayHeight - page.height) / 2 : 0),
      displayWidth,
      displayHeight,
    );
    pageLayouts.add(pageRect);
    x += page.width + pageGap;
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(x, maxHeight + (isManga ? 0.0 : 16.0)),
  );
}

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

          final view = View.of(context);
          final double screenWidth = view.physicalSize.width > 0
              ? view.physicalSize.width / view.devicePixelRatio
              : MediaQuery.of(context).size.width;
          final double screenHeight = view.physicalSize.height > 0
              ? view.physicalSize.height / view.devicePixelRatio
              : MediaQuery.of(context).size.height;

          return Stack(
            children: [
              // ── PDF Viewer ──
              // GestureDetector handles tap-for-overlay.
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: ctrl.toggleOverlay,
                onDoubleTapDown: (details) {
                  ctrl.handleDoubleTapZoom(details.localPosition, Size(screenWidth, screenHeight));
                },
                onDoubleTap: () {},
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

                  return OverflowBox(
                    minWidth: screenWidth,
                    maxWidth: screenWidth,
                    minHeight: screenHeight,
                    maxHeight: screenHeight,
                    alignment: Alignment.topCenter,
                    child: ColorFiltered(
                      colorFilter: filter,
                      child: PdfViewer.file(
                      pdf.path,
                      key: ValueKey(pdf.path),
                      controller: ctrl.pdfViewerController,
                      initialPageNumber: ctrl.getInitialPage(pdf.path),
                      params: PdfViewerParams(
                        interactionEndFrictionCoefficient: 0.001,
                        verticalCacheExtent: 3.5,
                        horizontalCacheExtent: 3.5,
                        onInteractionStart: ctrl.handleInteractionStart,
                        onInteractionEnd: ctrl.handleInteractionEnd,
                        // ── Custom Matrix Normalization / Position Preservation ──
                        normalizeMatrix: (newValue, viewSize, layout, controller) {
                          if (ctrl.isRestoringPosition) {
                            final corrected = ctrl.getCorrectedMatrixForLayout(layout, viewSize);
                            if (corrected != null) {
                              return corrected;
                            }
                          }
                          
                          // Restrict matrix to safe range to prevent horizontal/vertical panning drift
                          final position = newValue.calcPosition(viewSize);
                          final newZoom = max(newValue.zoom, 0.1);
                          final hw = viewSize.width / 2 / newZoom;
                          final hh = viewSize.height / 2 / newZoom;
                          
                          final minX = hw;
                          final maxX = layout.documentSize.width - hw;
                          final double x = minX < maxX ? position.dx.clamp(minX, maxX) : (minX + maxX) / 2;
                          
                          final minY = hh;
                          final maxY = layout.documentSize.height - hh;
                          final double doubleY = minY < maxY ? position.dy.clamp(minY, maxY) : (minY + maxY) / 2;

                          return controller!.calcMatrixFor(
                            Offset(x, doubleY),
                            zoom: newZoom,
                            viewSize: viewSize,
                          );
                        },

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
                        layoutPages: _buildVerticalLayout, //
//
//

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
                          try {
                            final media = MediaQuery.of(context);
                            final screenWidth = media.size.width;
                            final screenHeight = media.size.height;
                            final devicePixelRatio = media.devicePixelRatio;

                            // Calculate the scale to fit the page to the viewport
                            final double fitWidthScale = (screenWidth - 16) / page.width;
                            final double fitHeightScale = (screenHeight - 32) / page.height;
                            final double fitScale = fitWidthScale; //
//
//

                            // Multiply by devicePixelRatio to render at physical pixels.
                            // Add 15% extra scale (1.15) to guarantee sharpness and prevent pdfrx
                            // from triggering secondary partial rendering during normal view.
                            final double targetScale = fitScale * devicePixelRatio * 1.15;

                            return targetScale.clamp(0.05, 2.0);
                          } catch (_) {
                            return estimatedScale.clamp(0.05, 1.2);
                          }
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
      ? pages.fold(0.0, (maxVal, page) => max(maxVal, isCrop ? page.height * 1.18 : page.height)) 
      : 1.0;

  for (final page in pages) {
    final displayWidth = isCrop ? page.width * 1.18 : page.width;
    final displayHeight = isCrop ? page.height * 1.18 : page.height;

    final pageRect = Rect.fromLTWH(
      x,
      (maxHeight - displayHeight) / 2,
      displayWidth,
      displayHeight,
    );
    pageLayouts.add(pageRect);
    x += displayWidth + pageGap;
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(x + (isManga ? 0.0 : 8.0), maxHeight + (isManga ? 0.0 : 16.0)),
  );
}

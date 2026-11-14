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
            return const CustomSplashScreen(animateEntrance: false);
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

          final mediaSize = MediaQuery.sizeOf(context);
          final view = View.of(context);
          final double screenWidth = mediaSize.width > 0
              ? mediaSize.width
              : (view.physicalSize.width / view.devicePixelRatio);
          final double screenHeight = mediaSize.height > 0
              ? mediaSize.height
              : (view.physicalSize.height / view.devicePixelRatio);

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
                        useProgressiveLoading: false,
                        key: ValueKey('${pdf.path}_manga_${ctrl.isMangaMode.value}_single_${ctrl.isSinglePageMode.value}'),
                        controller: ctrl.pdfViewerController,
                        initialPageNumber: ctrl.getInitialPage(pdf.path),
                        params: PdfViewerParams(
                          // ── Native Android Fling Physics (Google Drive / Samsung Notes momentum) ──
                          scrollPhysics: const FixedOverscrollPhysics(maxOverscroll: 60.0),
                          panAxis: PanAxis.free,
                          pageAnchor: PdfPageAnchor.top,
                          boundaryMargin: EdgeInsets.zero,
                          pageDropShadow: const BoxShadow(color: Colors.transparent),
                          verticalCacheExtent: 2.0, // Pre-cache 2 viewports so upcoming pages are ready instantly
                          horizontalCacheExtent: 1.0,
                          onInteractionStart: ctrl.handleInteractionStart,
                          onInteractionEnd: ctrl.handleInteractionEnd,

                          // ── Progressive Two-Phase Rendering (Google Drive / Samsung Notes: No White Screens) ──
                          behaviorControlParams: const PdfViewerBehaviorControlParams(
                            enableLowResolutionPagePreview: true, // Instant thumbnail preview (<4ms) eliminates blank white gaps
                            trailingPageLoadingDelay: Duration(milliseconds: 20), // Near-instant preloading of upcoming pages
                            partialImageLoadingDelay: Duration(milliseconds: 60),  // Quickly render high-res tiles once settling
                            pageImageCachingDelay: Duration.zero,
                          ),

                          // ── High Performance Smart Sizing Delegate: 100% Fit-to-Width + Dynamic Zoom Range ──
                          sizeDelegateProvider: const _AdaptivePdfSizeDelegateProvider(
                            minScale: 0.02,
                            maxScale: 40.0,
                            smartMaxScale: double.infinity,
                            maxPagesVisible: double.infinity, // Ensures Fit-Width is always applied on open without Fit-Page clamping
                            onePassRenderingScaleThreshold: 200 / 72, // Single-pass rendering: silky smooth 60/120 FPS
                          ),

                          // ── Custom Matrix Normalization / Position Preservation with Zero-Allocation Fast-Path ──
                          normalizeMatrix: (newValue, viewSize, layout, controller) {
                            if (ctrl.isRestoringPosition) {
                              final corrected = ctrl.getCorrectedMatrixForLayout(layout, viewSize);
                              if (corrected != null) {
                                return corrected;
                              }
                            }
                            
                            // Restrict matrix to safe range to prevent horizontal/vertical panning drift
                            final position = newValue.calcPosition(viewSize);
                            final minAllowedZoom = controller?.minScale ?? 0.02;
                            final newZoom = max(newValue.zoom, minAllowedZoom);
                            final hw = viewSize.width / 2 / newZoom;
                            final hh = viewSize.height / 2 / newZoom;
                            
                            final minX = hw;
                            final maxX = layout.documentSize.width - hw;
                            final double x = minX < maxX ? position.dx.clamp(minX, maxX) : (minX + maxX) / 2;
                            
                            final minY = hh;
                            final maxY = layout.documentSize.height - hh;
                            final double doubleY = minY < maxY ? position.dy.clamp(minY, maxY) : (minY + maxY) / 2;

                            // Fast path: avoid allocating new Matrix4 120 times/sec if position is within bounds
                            if ((x - position.dx).abs() < 0.01 && (doubleY - position.dy).abs() < 0.01 && (newZoom - newValue.zoom).abs() < 0.001) {
                              return newValue;
                            }

                            return controller!.calcMatrixFor(
                              Offset(x, doubleY),
                              zoom: newZoom,
                              viewSize: viewSize,
                            );
                          },

                          // ── Background color ──
                          backgroundColor: ctrl.themeBackgroundColor,

                          // ── Side margins ──
                          margin: 0.0, // Zero margin: edge-to-edge display like Google Drive

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
                          layoutPages: ctrl.isSinglePageMode.value ? _buildHorizontalLayout : _buildVerticalLayout,

                          // ── Page change callback ──
                          onPageChanged: (int? pageNumber) {
                            if (pageNumber != null) {
                              ctrl.onPageChanged(pageNumber);
                            }
                          },

                          // ── Document ready callback ──
                          onViewerReady: (document, viewerController) {
                            ctrl.onDocumentReady(document, viewerController);
                          },

                          // ── Memory cap ──
                          maxImageBytesCachedOnMemory: 128 * 1024 * 1024,

                          // ── Disable aggressive cache limits to allow text PDFs to be fully cached ──
                          limitRenderingCache: true,

                          // ── Progressive Rendering Scale (Phase 2) ──
                          getPageRenderingScale: (context, page, controller, estimatedScale) {
                            // Normalize preview scale relative to standard A4 width (595 pt) so PDFs with small
                            // internal point dimensions still render crisp previews while staying within <3MB/page.
                            final double widthNorm = page.width > 0 ? (595.0 / page.width).clamp(0.25, 12.0) : 1.0;
                            final double baseCap = ctrl.isLargeFile.value ? 1.25 : 1.5;
                            return (estimatedScale * widthNorm).clamp(0.2 * widthNorm, baseCap * widthNorm);
                          },

                          // ── Loading placeholder: same animated Splash Screen (no spinner) ──
                          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
                              CustomSplashScreen(title: pdf.name, animateEntrance: false),

                          // ── Error placeholder ──
                          errorBannerBuilder: (context, error, stackTrace, documentRef) {
                            // Hide the loading splash so the error is visible
                            WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dismissLoading());
                            return Center(
                              child: Text(
                                'Error loading page',
                                style: TextStyle(color: Colors.red.shade300),
                              ),
                            );
                          },

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
                      color: Colors.black.withValues(alpha: opacity * 0.75),
                    ),
                  ),
                );
              }),

              // ── Floating Auto-Scroll HUD Control Bar (Minimizable & Auto-Fading Bubble) ──
              Obx(() {
                if (!ctrl.isAutoScrolling.value) return const SizedBox.shrink();
                final isPaused = ctrl.isAutoScrollPaused.value;
                final speed = ctrl.autoScrollSpeed.value;
                final isMinimized = ctrl.isAutoScrollHudMinimized.value;
                final isFaded = ctrl.isAutoScrollHudFaded.value;

                final String speedLabel = (speed % 1 == 0 && speed >= 10.0)
                    ? '${speed.toInt()}x'
                    : '${speed.toStringAsFixed(speed % 1 == 0 ? 1 : (speed * 10 % 1 == 0 ? 1 : 2))}x';

                // Lifts safely above the page slider and jump-to-page controls when bottom overlay is shown
                final bottomPos = ctrl.showOverlay.value ? 148.0 : 28.0;

                if (isMinimized) {
                  final bubblePos = ctrl.autoScrollBubblePosition.value;
                  final mq = MediaQuery.of(context);
                  final screenSize = mq.size;
                  final padding = mq.padding;

                  final Widget bubbleContent = AnimatedOpacity(
                    duration: const Duration(milliseconds: 350),
                    opacity: isFaded ? 0.28 : 1.0,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xEB1A1A1A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Independent Play / Pause button in brand violet
                            InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: ctrl.toggleAutoScrollPause,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C4DFF),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Expand area (Speed badge + open in full icon)
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: ctrl.expandAutoScrollHud,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      speedLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.open_in_full_rounded,
                                      color: Colors.white70,
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final Widget draggableBubble = GestureDetector(
                    onPanStart: (_) {
                      ctrl.resetBubbleFadeTimer();
                    },
                    onPanUpdate: (details) {
                      final currentPos = ctrl.autoScrollBubblePosition.value ?? Offset(
                        (screenSize.width - 120) / 2,
                        screenSize.height - bottomPos - 50,
                      );
                      final newX = (currentPos.dx + details.delta.dx)
                          .clamp(12.0, screenSize.width - 130.0);
                      final newY = (currentPos.dy + details.delta.dy)
                          .clamp(padding.top + 10.0, screenSize.height - padding.bottom - 60.0);
                      ctrl.autoScrollBubblePosition.value = Offset(newX, newY);
                      ctrl.isAutoScrollHudFaded.value = false;
                    },
                    onPanEnd: (_) {
                      ctrl.resetBubbleFadeTimer();
                    },
                    child: bubbleContent,
                  );

                  if (bubblePos != null) {
                    return Positioned(
                      left: bubblePos.dx,
                      top: bubblePos.dy,
                      child: draggableBubble,
                    );
                  } else {
                    return Positioned(
                      bottom: bottomPos,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: draggableBubble,
                      ),
                    );
                  }
                }

                // Expanded Bar State (Always 100% Solid Opacity, Never Fades)
                return Positioned(
                  bottom: bottomPos,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: ctrl.resetAutoMinimizeTimer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xEB1A1A1A),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Play / Pause button in brand violet
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: ctrl.toggleAutoScrollPause,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7C4DFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Decrease speed (-)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 20),
                                onPressed: ctrl.decreaseAutoScrollSpeed,
                              ),
                              // Speed badge (tap to open speed picker)
                              Tooltip(
                                message: 'scroll_speed'.tr,
                                child: InkWell(
                                  onTap: () {
                                    ctrl.resetAutoMinimizeTimer();
                                    ctrl.showSpeedPickerDialog();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 58),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          speedLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Increase speed (+)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                onPressed: ctrl.increaseAutoScrollSpeed,
                              ),
                              Container(
                                width: 1,
                                height: 20,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                color: Colors.white24,
                              ),
                              // Minimize button (down arrow)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                                tooltip: 'تصغير',
                                onPressed: ctrl.minimizeAutoScrollHud,
                              ),
                              // Close Auto-Scroll (X)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 19),
                                onPressed: ctrl.stopAutoScroll,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ── Overlay (toggle on tap) ──
              const ReaderOverlay(),

              // ── Document Loading Splash Screen (Matching App Splash) ──
              Obx(() {
                return IgnorePointer(
                  ignoring: !ctrl.isDocumentLoading.value,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: ctrl.isDocumentLoading.value ? 1.0 : 0.0,
                    child: CustomSplashScreen(title: pdf.name, animateEntrance: false),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ── Adaptive Sizing Delegate: Guarantees generous zoom range regardless of PDF internal point dimensions ──
class _AdaptivePdfSizeDelegateProvider extends PdfViewerSizeDelegateProviderSmart {
  const _AdaptivePdfSizeDelegateProvider({
    super.minScale,
    super.maxScale,
    super.smartMaxScale,
    super.maxPagesVisible,
    super.onePassRenderingScaleThreshold,
  });

  @override
  PdfViewerSizeDelegate create() => _AdaptivePdfSizeDelegate(
        smartMaxScale: smartMaxScale,
        maxScale: maxScale,
        minScale: minScale,
        maxPagesVisible: maxPagesVisible,
        onePassRenderingScaleThreshold: onePassRenderingScaleThreshold,
      );
}

class _AdaptivePdfSizeDelegate extends PdfViewerSizeDelegateSmart {
  _AdaptivePdfSizeDelegate({
    required super.smartMaxScale,
    required super.maxScale,
    required super.minScale,
    required super.maxPagesVisible,
    required super.onePassRenderingScaleThreshold,
  }) : _baseMaxScale = maxScale,
       _baseMinScale = minScale;

  final double _baseMaxScale;
  final double _baseMinScale;

  @override
  PdfViewerLayoutMetrics calculateMetrics({
    required Size viewSize,
    required PdfPageLayout? layout,
    required int? pageNumber,
    required double pageMargin,
    required EdgeInsets? boundaryMargin,
  }) {
    final baseMetrics = super.calculateMetrics(
      viewSize: viewSize,
      layout: layout,
      pageNumber: pageNumber,
      pageMargin: pageMargin,
      boundaryMargin: boundaryMargin,
    );

    if (layout == null || viewSize.width <= 0) {
      return baseMetrics;
    }

    double refWidth = layout.documentSize.width;
    if (pageNumber != null && pageNumber >= 1 && pageNumber <= layout.pageLayouts.length) {
      refWidth = layout.pageLayouts[pageNumber - 1].width;
    }
    final double fitWidthScale = refWidth > 0 ? viewSize.width / refWidth : 1.0;

    // Always allow zooming up to at least 10x (1000%) of the 100% Fit-to-Width scale
    final double effectiveMaxScale = max(_baseMaxScale, fitWidthScale * 10.0);
    final double effectiveMinScale = min(
      max(_baseMinScale, fitWidthScale * 0.25),
      effectiveMaxScale,
    );

    return PdfViewerLayoutMetrics(
      minScale: effectiveMinScale,
      maxScale: effectiveMaxScale,
      coverScale: baseMetrics.coverScale,
      alternativeFitScale: baseMetrics.alternativeFitScale,
    );
  }

  @override
  void onLayoutUpdate({
    required PdfViewerLayoutSnapshot oldState,
    required PdfViewerLayoutSnapshot newState,
    required double currentZoom,
    required Rect oldVisibleRect,
    required int? anchorPageNumber,
    required bool isLayoutChanged,
    required bool isViewSizeChanged,
  }) {
    double adjustedZoom = currentZoom;
    if (isLayoutChanged &&
        oldState.layout != null &&
        newState.layout != null &&
        oldState.layout!.documentSize.width > 0 &&
        newState.layout!.documentSize.width > 0) {
      final oldDocWidth = oldState.layout!.documentSize.width;
      final newDocWidth = newState.layout!.documentSize.width;
      if ((oldDocWidth - newDocWidth).abs() > 0.5) {
        adjustedZoom = currentZoom * (oldDocWidth / newDocWidth);
      }
    } else if (isViewSizeChanged &&
        oldState.viewSize.width > 0 &&
        newState.viewSize.width > 0 &&
        (oldState.viewSize.width - newState.viewSize.width).abs() > 1.0) {
      // Scale zoom proportionally when rotating between Portrait and Landscape
      // so the PDF always fills 100% of the new screen width!
      final widthRatio = newState.viewSize.width / oldState.viewSize.width;
      final docWidth = newState.layout?.documentSize.width ?? 0.0;
      final newFitScale = docWidth > 0
          ? (newState.viewSize.width / docWidth)
          : (currentZoom * widthRatio);
      adjustedZoom = max(currentZoom * widthRatio, newFitScale);
    }
    super.onLayoutUpdate(
      oldState: oldState,
      newState: newState,
      currentZoom: adjustedZoom,
      oldVisibleRect: oldVisibleRect,
      anchorPageNumber: anchorPageNumber,
      isLayoutChanged: isLayoutChanged,
      isViewSizeChanged: isViewSizeChanged,
    );
  }
}

// ── Vertical layout with automatic edge-to-edge width normalization ──
PdfPageLayout _buildVerticalLayout(
    List<PdfPage> pages, PdfViewerParams params) {
  final ctrl = Get.find<ReaderController>();
  final isManga = ctrl.isMangaMode.value;

  if (pages.isEmpty) {
    return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
  }

  // ── Base Document Width Determination (Smallest Page Width + Standard Coordinate Normalization) ──
  final sortedWidths = pages.map((p) => p.width).where((w) => w > 0).toList()..sort();
  final double minWidth = sortedWidths.isNotEmpty
      ? sortedWidths.first
      : 595.0;
  // Normalize PDFs created with tiny internal point dimensions (e.g. 72 pt) up to standard 595 pt (A4)
  final double docCoordScale = minWidth < 595.0 ? (595.0 / minWidth) : 1.0;
  final double baseWidth = minWidth * docCoordScale;

  final pageLayouts = <Rect>[];
  double y = 0.0;
  // In Manga Mode: ZERO gap (0.0) between pages, forming a continuous seamless strip.
  // In Normal Mode: 10.0 pt clean separation gap.
  final double pageGap = isManga ? 0.0 : 10.0;

  for (final page in pages) {
    double pageWidth = page.width * docCoordScale;
    double pageHeight = page.height * docCoordScale;

    if (isManga) {
      // In Manga Mode: Normalize width to baseWidth so adjacent pages flow seamlessly with no horizontal steps
      final double scale = baseWidth / pageWidth;
      pageWidth = baseWidth;
      pageHeight = pageHeight * scale;
    } else {
      // In Normal Mode (Samsung Notes): Scale down oversized pages to fit within baseWidth
      if (pageWidth > baseWidth) {
        final double scale = baseWidth / pageWidth;
        pageWidth = baseWidth;
        pageHeight = pageHeight * scale;
      }
    }

    // Center page horizontally within baseWidth
    final double x = (baseWidth - pageWidth) / 2.0;

    final pageRect = Rect.fromLTWH(
      x,
      y,
      pageWidth,
      pageHeight,
    );
    pageLayouts.add(pageRect);
    y += pageHeight + pageGap;
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(baseWidth, y),
  );
}

PdfPageLayout _buildHorizontalLayout(
    List<PdfPage> pages, PdfViewerParams params) {
  final ctrl = Get.find<ReaderController>();
  final isManga = ctrl.isMangaMode.value;

  final sortedWidths = pages.map((p) => p.width).where((w) => w > 0).toList()..sort();
  final double medianWidth = sortedWidths.isNotEmpty
      ? sortedWidths[sortedWidths.length ~/ 2]
      : 595.0;
  final double docCoordScale = medianWidth < 595.0 ? (595.0 / medianWidth) : 1.0;

  final pageLayouts = <Rect>[];
  double x = isManga ? 0.0 : 8.0;
  final double pageGap = isManga ? 0.0 : 16.0;

  // Find max page height to size the document height
  final maxHeight = pages.isNotEmpty 
      ? pages.fold(0.0, (maxVal, page) => max(maxVal, page.height * docCoordScale)) 
      : 1.0;

  for (final page in pages) {
    final displayWidth = page.width * docCoordScale;
    final displayHeight = page.height * docCoordScale;

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

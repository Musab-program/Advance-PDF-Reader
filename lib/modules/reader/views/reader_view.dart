// lib/modules/reader/views/reader_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
                  const Icon(Icons.folder_open, color: Colors.white54, size: 64),
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
              GestureDetector(
                // Tap anywhere to toggle overlay
                onTap: ctrl.toggleOverlay,
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    // ── PDF Viewer (optimized for speed) ──
                    SfPdfViewer.file(
                      File(pdf.path),
                      key: ctrl.pdfViewerKey,
                      controller: ctrl.pdfViewerController,
                      onPageChanged: ctrl.onPageChanged,
                      onDocumentLoaded: ctrl.onDocumentLoaded,
                      onTap: (details) => ctrl.toggleOverlay(),
                      onDocumentLoadFailed: (details) {
                        Get.snackbar('Error', details.error,
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red.shade900,
                            colorText: Colors.white);
                      },
                      pageLayoutMode: ctrl.isSinglePageMode.value
                          ? PdfPageLayoutMode.single
                          : PdfPageLayoutMode.continuous,
                      scrollDirection: ctrl.isSinglePageMode.value
                          ? PdfScrollDirection.horizontal
                          : PdfScrollDirection.vertical,
                      pageSpacing: ctrl.isSinglePageMode.value ? 0 : 4,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      interactionMode: PdfInteractionMode.pan,
                      enableTextSelection: false, // Much faster scrolling
                      canShowPageLoadingIndicator: false,
                      enableDocumentLinkAnnotation: false, // Disable extra processing
                      maxZoomLevel: 2.5, // Limit memory for zooming
                      canShowPaginationDialog: false, // Cleaner experience
                    ),

                    // ── Overlay (toggle on tap) ──
                    const ReaderOverlay(),

                    // Loading Splash Screen Overlay (Ensuring it's on top)
                    Obx(() {
                      if (ctrl.isDocumentLoading.value) {
                        return CustomSplashScreen(title: pdf.name);
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

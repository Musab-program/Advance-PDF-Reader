import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';
import '../controllers/document_editor_controller.dart';
import '../models/editor_models.dart';

class PageAnnotationOverlay extends StatefulWidget {
  final int pageIndex;
  final Size pageSize;
  final DocumentEditorController controller;
  final PdfPage? pdfPage;

  const PageAnnotationOverlay({
    super.key,
    required this.pageIndex,
    required this.pageSize,
    required this.controller,
    this.pdfPage,
  });

  @override
  State<PageAnnotationOverlay> createState() => _PageAnnotationOverlayState();
}

class _PageAnnotationOverlayState extends State<PageAnnotationOverlay> {
  Offset? _eyedropperTouchPos;
  Color? _eyedropperLiveColor;

  @override
  void initState() {
    super.initState();
    widget.controller.registerPageMetrics(widget.pageIndex, widget.pageSize, widget.pdfPage);
  }

  @override
  void didUpdateWidget(covariant PageAnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.pageSize != widget.pageSize ||
        oldWidget.pdfPage != widget.pdfPage) {
      widget.controller.registerPageMetrics(widget.pageIndex, widget.pageSize, widget.pdfPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pageIndex = widget.pageIndex;
    final pageSize = widget.pageSize;

    return Obx(() {
      final isDrawingActive = controller.isDrawingModeActive.value;
      final isEyedropper = controller.eyedropperTargetStampId.value != null;
      final isCurrentDrawingPage = controller.activeDrawingPageIndex.value == pageIndex;
      final pageStrokes = controller.strokes.where((s) => s.pageIndex == pageIndex).toList();
      final pageStamps = controller.stamps.where((s) => s.pageIndex == pageIndex).toList();
      final activePoints = isCurrentDrawingPage ? controller.activePathPoints.toList() : const <Offset>[];
      final activeSnapped = isCurrentDrawingPage ? controller.activeSnappedRects.toList() : const <Rect>[];
      final selectedId = controller.selectedStampId.value;
      final selectedStamp = pageStamps.firstWhereOrNull((s) => s.id == selectedId);

      // If user is neither drawing, eyedropping, nor interacting with stamps, ignore touch pointer events
      // so scrolling and gestures pass directly to the PDF viewer with 0 latency.
      if (!isDrawingActive && !isEyedropper && pageStamps.isEmpty) {
        return IgnorePointer(
          child: CustomPaint(
            painter: _StrokesPainter(
              strokes: pageStrokes,
              activePoints: const [],
              activeSnappedRects: const [],
              activeTool: controller.activeAnnotateTool.value,
              activeColor: controller.selectedColor.value,
              activeWidth: controller.strokeWidth.value,
            ),
          ),
        );
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
            // ─── 1. Persistent Drawn Strokes & Live Snapped Markup Painter ───
            Positioned.fill(
              child: CustomPaint(
                painter: _StrokesPainter(
                  strokes: pageStrokes,
                  activePoints: (isDrawingActive && isCurrentDrawingPage) ? activePoints : const [],
                  activeSnappedRects: (isDrawingActive && isCurrentDrawingPage) ? activeSnapped : const [],
                  activeTool: controller.activeAnnotateTool.value,
                  activeColor: controller.selectedColor.value,
                  activeWidth: controller.strokeWidth.value,
                ),
              ),
            ),

            // ─── 2. Placed Stamps / Signatures / Shapes / Text ───
            for (final stamp in pageStamps)
              Builder(
                builder: (context) {
                  final scaleX = stamp.pageViewSize.width > 0
                      ? pageSize.width / stamp.pageViewSize.width
                      : 1.0;
                  final scaleY = stamp.pageViewSize.height > 0
                      ? pageSize.height / stamp.pageViewSize.height
                      : 1.0;
                  final displayPos = Offset(stamp.position.dx * scaleX, stamp.position.dy * scaleY);
                  final displaySize = Size(stamp.size.width * scaleX, stamp.size.height * scaleY);

                  return Positioned(
                    left: displayPos.dx - 18,
                    top: displayPos.dy - 18,
                    child: _DraggableStampItem(
                      stamp: stamp,
                      displaySize: displaySize,
                      scaleY: scaleY,
                      isSelected: selectedId == stamp.id && !isDrawingActive && !isEyedropper,
                      onSelect: () => controller.selectStamp(stamp.id),
                      onPositionDelta: (delta) {
                        controller.updateStampPosition(
                          stamp.id,
                          stamp.position + Offset(delta.dx / scaleX, delta.dy / scaleY),
                        );
                      },
                      onSizeDelta: (deltaSize) {
                        controller.updateStampSize(
                          stamp.id,
                          Size(
                            stamp.size.width + deltaSize.width / scaleX,
                            stamp.size.height + deltaSize.height / scaleY,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

            // ─── 3. Floating Action Toolbar (At Page Level to Guarantee Hit-Testing) ───
            if (selectedStamp != null && !isDrawingActive && !isEyedropper)
              Builder(
                builder: (context) {
                  final scaleX = selectedStamp.pageViewSize.width > 0
                      ? pageSize.width / selectedStamp.pageViewSize.width
                      : 1.0;
                  final scaleY = selectedStamp.pageViewSize.height > 0
                      ? pageSize.height / selectedStamp.pageViewSize.height
                      : 1.0;
                  final dispX = selectedStamp.position.dx * scaleX;
                  final dispY = selectedStamp.position.dy * scaleY;
                  final dispH = selectedStamp.size.height * scaleY;
                  final maxLeft = (pageSize.width - 260.0).clamp(8.0, double.infinity);

                  return Positioned(
                    left: dispX.clamp(8.0, maxLeft),
                    top: dispY > 52 ? dispY - 46 : dispY + dispH + 10,
                    child: _FloatingStampToolbar(
                      stamp: selectedStamp,
                      controller: controller,
                      onDelete: () => controller.removeStamp(selectedStamp.id),
                      onDuplicate: () => controller.duplicateStamp(selectedStamp.id),
                    ),
                  );
                },
              ),

            // ─── 4. Drawing Input Interceptor (1-finger draws, 2-finger pinches to zoom & pan) ───
            if (isDrawingActive && !isEyedropper)
              Positioned.fill(
                child: _DrawingTouchInterceptor(
                  pageIndex: pageIndex,
                  pageSize: pageSize,
                  controller: controller,
                  pdfPage: widget.pdfPage,
                ),
              ),

            // ─── 5. Eyedropper Input Interceptor with Live Magnifying Loupe & Commit on Release ───
            if (isEyedropper)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    _eyedropperTouchPos = e.localPosition;
                    _eyedropperLiveColor = controller.sampleEyedropperColorSync(
                      e.localPosition,
                      pageSize,
                      widget.pdfPage?.pageNumber ?? (pageIndex + 1),
                    );
                    setState(() {});
                  },
                  onPointerMove: (e) {
                    _eyedropperTouchPos = e.localPosition;
                    _eyedropperLiveColor = controller.sampleEyedropperColorSync(
                      e.localPosition,
                      pageSize,
                      widget.pdfPage?.pageNumber ?? (pageIndex + 1),
                    );
                    setState(() {});
                  },
                  onPointerUp: (e) {
                    final pos = e.localPosition;
                    setState(() {
                      _eyedropperTouchPos = null;
                      _eyedropperLiveColor = null;
                    });
                    controller.pickPageColorAt(pos, pageSize, widget.pdfPage);
                  },
                  onPointerCancel: (_) {
                    setState(() {
                      _eyedropperTouchPos = null;
                      _eyedropperLiveColor = null;
                    });
                  },
                ),
              ),

            // ─── 6. Live Eyedropper Magnifying Loupe Reticle ───
            if (isEyedropper && _eyedropperTouchPos != null)
              Positioned(
                left: (_eyedropperTouchPos!.dx - 40).clamp(6.0, (pageSize.width - 86.0).clamp(6.0, double.infinity)),
                top: (_eyedropperTouchPos!.dy - 90).clamp(10.0, (pageSize.height - 90.0).clamp(10.0, double.infinity)),
                child: _EyedropperLoupe(
                  color: _eyedropperLiveColor ?? Colors.white,
                ),
              ),
          ],
        );
      });
    }
  }

/// Smart Touch Interceptor:
/// - 1 finger: Draws or erases freehand strokes smoothly.
/// - 2 fingers (Pinch): Immediately cancels drawing and scales/pans the document via [PdfViewerController].
class _DrawingTouchInterceptor extends StatefulWidget {
  final int pageIndex;
  final Size pageSize;
  final DocumentEditorController controller;
  final PdfPage? pdfPage;

  const _DrawingTouchInterceptor({
    required this.pageIndex,
    required this.pageSize,
    required this.controller,
    this.pdfPage,
  });

  @override
  State<_DrawingTouchInterceptor> createState() => _DrawingTouchInterceptorState();
}

class _DrawingTouchInterceptorState extends State<_DrawingTouchInterceptor> {
  bool _isDrawing = false;
  Matrix4? _baseMatrix;
  Offset? _initialFocal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        if (details.pointerCount == 1) {
          _isDrawing = true;
          _baseMatrix = null;
          _initialFocal = null;
          widget.controller.startDrawing(
            details.localFocalPoint,
            widget.pageIndex,
            pdfPage: widget.pdfPage,
          );
        } else {
          _isDrawing = false;
          widget.controller.cancelActiveDrawing();
          if (widget.controller.pdfViewerController.isReady) {
            _baseMatrix = widget.controller.pdfViewerController.value.clone();
            _initialFocal = details.focalPoint;
          }
        }
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 1 && _isDrawing) {
          widget.controller.updateDrawing(
            details.localFocalPoint,
            pageIndex: widget.pageIndex,
            pageViewSize: widget.pageSize,
            pdfPage: widget.pdfPage,
          );
        } else if (details.pointerCount >= 2) {
          if (_isDrawing) {
            widget.controller.cancelActiveDrawing();
            _isDrawing = false;
            if (widget.controller.pdfViewerController.isReady) {
              _baseMatrix = widget.controller.pdfViewerController.value.clone();
              _initialFocal = details.focalPoint;
            }
          }
          if (_baseMatrix != null &&
              _initialFocal != null &&
              widget.controller.pdfViewerController.isReady) {
            final focal = details.focalPoint;
            final scale = details.scale;

            final transform = Matrix4.identity()
              ..multiply(Matrix4.translationValues(focal.dx, focal.dy, 0.0))
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0))
              ..multiply(Matrix4.translationValues(-_initialFocal!.dx, -_initialFocal!.dy, 0.0))
              ..multiply(_baseMatrix!);

            widget.controller.pdfViewerController.value = transform;
          }
        }
      },
      onScaleEnd: (details) {
        if (_isDrawing) {
          widget.controller.endDrawing(
            widget.pageIndex,
            widget.pageSize,
            pdfPage: widget.pdfPage,
          );
          _isDrawing = false;
        }
        _baseMatrix = null;
        _initialFocal = null;
      },
      child: Container(color: Colors.transparent),
    );
  }
}

/// High-precision Eyedropper Magnifying Loupe with reticle crosshair
class _EyedropperLoupe extends StatelessWidget {
  final Color color;

  const _EyedropperLoupe({required this.color});

  @override
  Widget build(BuildContext context) {
    final hexString = '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Reticle Crosshairs (thin black line with white highlight)
              CustomPaint(
                size: const Size(76, 76),
                painter: _ReticlePainter(),
              ),
              // Center sample dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Hex Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Text(
            hexString,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final paintWhite = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    final paintBlack = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.0;

    // Horizontal
    canvas.drawLine(Offset(cx - 16, cy), Offset(cx - 5, cy), paintWhite);
    canvas.drawLine(Offset(cx + 5, cy), Offset(cx + 16, cy), paintWhite);
    canvas.drawLine(Offset(cx - 16, cy), Offset(cx - 5, cy), paintBlack);
    canvas.drawLine(Offset(cx + 5, cy), Offset(cx + 16, cy), paintBlack);

    // Vertical
    canvas.drawLine(Offset(cx, cy - 16), Offset(cx, cy - 5), paintWhite);
    canvas.drawLine(Offset(cx, cy + 5), Offset(cx, cy + 16), paintWhite);
    canvas.drawLine(Offset(cx, cy - 16), Offset(cx, cy - 5), paintBlack);
    canvas.drawLine(Offset(cx, cy + 5), Offset(cx, cy + 16), paintBlack);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DraggableStampItem extends StatelessWidget {
  final PlacedStamp stamp;
  final Size displaySize;
  final double scaleY;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onPositionDelta;
  final ValueChanged<Size> onSizeDelta;

  const _DraggableStampItem({
    required this.stamp,
    required this.displaySize,
    required this.scaleY,
    required this.isSelected,
    required this.onSelect,
    required this.onPositionDelta,
    required this.onSizeDelta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final width = displaySize.width;
    final height = displaySize.height;

    // Fixed text markups (highlight/underline/strikeout) CANNOT be moved or resized.
    // They are permanently anchored to the underlying text lines.
    final isFixedMarkup = stamp.type == StampType.highlightRect ||
        stamp.type == StampType.underlineRect ||
        stamp.type == StampType.strikeoutRect;

    final isResizableIn2D = !isFixedMarkup &&
        (stamp.type == StampType.whiteout ||
            stamp.type == StampType.formattedTextBox ||
            stamp.type == StampType.rectShape ||
            stamp.type == StampType.circleShape ||
            stamp.type == StampType.lineShape ||
            stamp.type == StampType.arrowShape);

    return SizedBox(
      width: width + 36,
      height: height + 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main Stamp Body (Positioned at offset 18, 18) ──
          Positioned(
            left: 18,
            top: 18,
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelect,
              onPanUpdate: isFixedMarkup ? null : (details) => onPositionDelta(details.delta),
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(
                          color: isFixedMarkup ? primary.withValues(alpha: 0.6) : primary,
                          width: isFixedMarkup ? 1.5 : 2.0,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildStampContent(),
              ),
            ),
          ),

          // ── Corner Resize Handles (Hidden for fixed markups) ──
          if (isSelected && !isFixedMarkup) ...[
            // Top-Left Corner
            Positioned(
              left: 0,
              top: 0,
              child: _resizeHandle(
                primary: primary,
                onPanUpdate: (delta) {
                  onPositionDelta(delta);
                  onSizeDelta(Size(-delta.dx, -delta.dy));
                },
              ),
            ),
            // Top-Right Corner
            Positioned(
              left: width,
              top: 0,
              child: _resizeHandle(
                primary: primary,
                onPanUpdate: (delta) {
                  onPositionDelta(Offset(0, delta.dy));
                  onSizeDelta(Size(delta.dx, -delta.dy));
                },
              ),
            ),
            // Bottom-Left Corner
            Positioned(
              left: 0,
              top: height,
              child: _resizeHandle(
                primary: primary,
                onPanUpdate: (delta) {
                  onPositionDelta(Offset(delta.dx, 0));
                  onSizeDelta(Size(-delta.dx, delta.dy));
                },
              ),
            ),
            // Bottom-Right Corner
            Positioned(
              left: width,
              top: height,
              child: _resizeHandle(
                primary: primary,
                onPanUpdate: (delta) => onSizeDelta(Size(delta.dx, delta.dy)),
              ),
            ),
          ],

          // ── Edge Resize Handles (For Whiteout, Boxes & Shapes) ──
          if (isSelected && isResizableIn2D) ...[
            // Middle-Left (Width only)
            Positioned(
              left: 0,
              top: 18 + (height / 2) - 18,
              child: _resizeHandle(
                primary: primary,
                isEdge: true,
                onPanUpdate: (delta) {
                  onPositionDelta(Offset(delta.dx, 0));
                  onSizeDelta(Size(-delta.dx, 0));
                },
              ),
            ),
            // Middle-Right (Width only)
            Positioned(
              left: width,
              top: 18 + (height / 2) - 18,
              child: _resizeHandle(
                primary: primary,
                isEdge: true,
                onPanUpdate: (delta) => onSizeDelta(Size(delta.dx, 0)),
              ),
            ),
            // Middle-Top (Height only)
            Positioned(
              left: 18 + (width / 2) - 18,
              top: 0,
              child: _resizeHandle(
                primary: primary,
                isEdge: true,
                onPanUpdate: (delta) {
                  onPositionDelta(Offset(0, delta.dy));
                  onSizeDelta(Size(0, -delta.dy));
                },
              ),
            ),
            // Middle-Bottom (Height only)
            Positioned(
              left: 18 + (width / 2) - 18,
              top: height,
              child: _resizeHandle(
                primary: primary,
                isEdge: true,
                onPanUpdate: (delta) => onSizeDelta(Size(0, delta.dy)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resizeHandle({
    required Color primary,
    bool isEdge = false,
    required ValueChanged<Offset> onPanUpdate,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onPanUpdate(details.delta),
      child: Container(
        width: 36,
        height: 36,
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: isEdge ? 16 : 14,
            height: isEdge ? 10 : 14,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: isEdge ? BorderRadius.circular(4) : null,
              shape: isEdge ? BoxShape.rectangle : BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStampContent() {
    // 1. Smart Whiteout (Borderless by default; border only if user opted in or selected)
    if (stamp.type == StampType.whiteout) {
      return Container(
        width: displaySize.width,
        height: displaySize.height,
        decoration: BoxDecoration(
          color: stamp.backgroundColor ?? Colors.white,
          border: stamp.borderColor != null
              ? Border.all(color: stamp.borderColor!, width: 1.0)
              : (isSelected
                  ? Border.all(color: Colors.grey.withValues(alpha: 0.35), width: 0.8)
                  : null),
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }

    // 2. Snapped Text Markup (Highlight / Underline / Strikeout)
    if (stamp.type == StampType.highlightRect ||
        stamp.type == StampType.underlineRect ||
        stamp.type == StampType.strikeoutRect) {
      return CustomPaint(
        size: displaySize,
        painter: _TextMarkupPainter(
          stamp: stamp,
          displaySize: displaySize,
        ),
      );
    }

    // 3. Dynamic Vector Signature
    if (stamp.type == StampType.signature) {
      if (stamp.rawSignatureLines != null && stamp.rawSignatureLines!.isNotEmpty) {
        return CustomPaint(
          size: displaySize,
          painter: _SignatureVectorPainter(stamp.rawSignatureLines!, stamp.color),
        );
      } else if (stamp.imageBytes != null) {
        return Image.memory(
          stamp.imageBytes!,
          width: displaySize.width,
          height: displaySize.height,
          fit: BoxFit.contain,
        );
      }
    }

    // 4. Vector Symbols (Avoids Android NotoColorEmoji override so color changes work!)
    if (stamp.type == StampType.check) {
      return CustomPaint(
        size: displaySize,
        painter: _CheckMarkPainter(stamp.color, stamp.strokeWidth),
      );
    }

    if (stamp.type == StampType.cross) {
      return CustomPaint(
        size: displaySize,
        painter: _CrossMarkPainter(stamp.color, stamp.strokeWidth),
      );
    }

    if (stamp.type == StampType.dot) {
      return SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: Center(
          child: Container(
            width: displaySize.width * 0.7,
            height: displaySize.height * 0.7,
            decoration: BoxDecoration(
              color: stamp.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    // 5. Shapes
    if (stamp.type == StampType.rectShape) {
      return Container(
        width: displaySize.width,
        height: displaySize.height,
        decoration: BoxDecoration(
          border: Border.all(color: stamp.color, width: stamp.strokeWidth),
        ),
      );
    }

    if (stamp.type == StampType.circleShape) {
      return CustomPaint(
        size: displaySize,
        painter: _EllipseShapePainter(stamp.color, stamp.strokeWidth),
      );
    }

    if (stamp.type == StampType.lineShape) {
      return CustomPaint(
        size: displaySize,
        painter: _LineShapePainter(stamp.color, stamp.strokeWidth),
      );
    }

    if (stamp.type == StampType.arrowShape) {
      return CustomPaint(
        size: displaySize,
        painter: _ArrowShapePainter(stamp.color, stamp.strokeWidth),
      );
    }

    // 6. Formatted Text Box (Edit Tab - Font scaled by scaleY for crisp high-zoom rendering)
    if (stamp.type == StampType.formattedTextBox) {
      return Container(
        width: displaySize.width,
        height: displaySize.height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: stamp.backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: stamp.borderColor != null ? Border.all(color: stamp.borderColor!, width: 1.5) : null,
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            stamp.text ?? '',
            textAlign: stamp.alignment,
            style: TextStyle(
              fontSize: stamp.fontSize * scaleY,
              fontWeight: stamp.isBold ? FontWeight.bold : FontWeight.normal,
              color: stamp.color,
            ),
          ),
        ),
      );
    }

    // 7. Quick Text (Fill & Sign)
    if (stamp.type == StampType.quickText) {
      return SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            stamp.text ?? '',
            style: TextStyle(
              fontSize: stamp.fontSize * scaleY,
              fontWeight: stamp.isBold ? FontWeight.bold : FontWeight.normal,
              color: stamp.color,
            ),
          ),
        ),
      );
    }

    // 8. Date Stamp
    if (stamp.type == StampType.dateStamp) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF93C5FD), width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            stamp.text ?? '',
            style: TextStyle(
              fontSize: stamp.fontSize * scaleY,
              fontWeight: FontWeight.bold,
              color: stamp.color,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Floating Action Toolbar above Selected Stamp (Positioned in Page Root Stack) ──
class _FloatingStampToolbar extends StatelessWidget {
  final PlacedStamp stamp;
  final DocumentEditorController controller;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _FloatingStampToolbar({
    required this.stamp,
    required this.controller,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isFixedMarkup = stamp.type == StampType.highlightRect ||
        stamp.type == StampType.underlineRect ||
        stamp.type == StampType.strikeoutRect;
    final isText = stamp.type == StampType.formattedTextBox || stamp.type == StampType.quickText;
    final isWhiteout = stamp.type == StampType.whiteout;
    final isBox = stamp.type == StampType.formattedTextBox;

    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete button (Always available)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              tooltip: 'wps_delete'.tr,
              onPressed: onDelete,
            ),

            // Duplicate button (Hidden for fixed text markups)
            if (!isFixedMarkup)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.copy_rounded, size: 16, color: theme.colorScheme.onSurface),
                tooltip: 'wps_duplicate'.tr,
                onPressed: onDuplicate,
              ),

            // Edit content button (for text)
            if (isText && !isFixedMarkup)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.edit_note_rounded, size: 19, color: Color(0xFF2563EB)),
                tooltip: 'wps_edit'.tr,
                onPressed: () => controller.editStampContent(stamp.id, context),
              ),

            // Size - button (Hidden for fixed text markups)
            if (!isFixedMarkup)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 17),
                tooltip: 'wps_shrink'.tr,
                onPressed: () => controller.changeStampScale(stamp.id, 0.85),
              ),

            // Size + button (Hidden for fixed text markups)
            if (!isFixedMarkup)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                tooltip: 'wps_enlarge'.tr,
                onPressed: () => controller.changeStampScale(stamp.id, 1.18),
              ),

            // Whiteout specific controls: Eyedropper + Color + Border toggle
            if (isWhiteout) ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.colorize_rounded, size: 18, color: theme.primaryColor),
                tooltip: 'wps_pick_page_color'.tr,
                onPressed: () => controller.startEyedropperForStamp(stamp.id),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  stamp.borderColor != null ? Icons.border_outer_rounded : Icons.border_clear_rounded,
                  size: 18,
                  color: stamp.borderColor != null ? theme.primaryColor : Colors.grey,
                ),
                tooltip: stamp.borderColor != null ? 'wps_remove_border'.tr : 'wps_add_border'.tr,
                onPressed: () => controller.toggleStampBorder(stamp.id),
              ),
              _buildWhiteoutColorPicker(context),
            ] else if (isBox) ...[
              // Formatted text box controls: Eyedropper + Border toggle + Color
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.colorize_rounded, size: 18, color: theme.primaryColor),
                tooltip: 'wps_pick_bg_color'.tr,
                onPressed: () => controller.startEyedropperForStamp(stamp.id),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  stamp.borderColor != null ? Icons.border_outer_rounded : Icons.border_clear_rounded,
                  size: 18,
                  color: stamp.borderColor != null ? theme.primaryColor : Colors.grey,
                ),
                tooltip: stamp.borderColor != null ? 'wps_remove_border'.tr : 'wps_add_border'.tr,
                onPressed: () => controller.toggleStampBorder(stamp.id),
              ),
              _buildColorPickerMenu(context),
            ] else
              _buildColorPickerMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteoutColorPicker(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const whiteoutColors = [
      Color(0xFFFFFFFF), // Pure white
      Color(0xFFFFFDF7), // Warm paper
      Color(0xFFF3F4F6), // Soft gray
      Color(0xFFFEF9C3), // Light cream
      Color(0xFF1E293B), // Dark slate
    ];

    return PopupMenuButton<Color>(
      padding: EdgeInsets.zero,
      tooltip: 'wps_whiteout_color'.tr,
      icon: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: stamp.backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: (stamp.backgroundColor?.computeLuminance() ?? 1.0) < 0.25 ? Colors.white70 : Colors.grey.shade500,
            width: 2.0,
          ),
        ),
      ),
      onSelected: (color) => controller.changeStampBackgroundColor(stamp.id, color),
      itemBuilder: (ctx) => [
        for (final c in whiteoutColors)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (c.computeLuminance() < 0.25 && isDark) ? Colors.white70 : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  c == const Color(0xFFFFFFFF)
                      ? 'wps_pure_white'.tr
                      : c == const Color(0xFFFFFDF7)
                          ? 'wps_warm_paper'.tr
                          : c == const Color(0xFFF3F4F6)
                              ? 'wps_soft_gray'.tr
                              : c == const Color(0xFFFEF9C3)
                                  ? 'wps_light_cream'.tr
                                  : 'wps_dark_slate'.tr,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildColorPickerMenu(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const stampColors = [
      Color(0xFF0F172A), // Slate / Black
      Color(0xFF1D4ED8), // Blue
      Color(0xFFDC2626), // Red
      Color(0xFF16A34A), // Green
      Color(0xFFEAB308), // Yellow
    ];

    return PopupMenuButton<Color>(
      padding: EdgeInsets.zero,
      tooltip: 'wps_color'.tr,
      icon: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: stamp.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: stamp.color.computeLuminance() < 0.25 ? Colors.white70 : Colors.white,
            width: 2.0,
          ),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
        ),
      ),
      onSelected: (color) => controller.changeStampColor(stamp.id, color),
      itemBuilder: (ctx) => [
        for (final c in stampColors)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (c.computeLuminance() < 0.25 && isDark) ? Colors.white70 : Colors.black12,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  c == const Color(0xFF0F172A)
                      ? 'color_black'.tr
                      : c == const Color(0xFF1D4ED8)
                          ? 'color_blue'.tr
                          : c == const Color(0xFFDC2626)
                              ? 'color_red'.tr
                              : c == const Color(0xFF16A34A)
                                  ? 'color_green'.tr
                                  : 'color_yellow'.tr,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Vector Signature Painter ──
class _SignatureVectorPainter extends CustomPainter {
  final List<List<Offset>> normalizedLines;
  final Color color;

  _SignatureVectorPainter(this.normalizedLines, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final line in normalizedLines) {
      if (line.isEmpty) continue;
      final path = Path()..moveTo(line.first.dx * size.width, line.first.dy * size.height);
      for (int i = 1; i < line.length; i++) {
        path.lineTo(line[i].dx * size.width, line[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureVectorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.normalizedLines != normalizedLines;
}

class _TextMarkupPainter extends CustomPainter {
  final PlacedStamp stamp;
  final Size displaySize;

  _TextMarkupPainter({required this.stamp, required this.displaySize});

  @override
  void paint(Canvas canvas, Size size) {
    final baseW = stamp.size.width > 0 ? stamp.size.width : 1.0;
    final baseH = stamp.size.height > 0 ? stamp.size.height : 1.0;
    final sx = displaySize.width / baseW;
    final sy = displaySize.height / baseH;

    final rects = (stamp.lineRects != null && stamp.lineRects!.isNotEmpty)
        ? stamp.lineRects!
            .map((lr) => Rect.fromLTWH(
                  (lr.left - stamp.position.dx) * sx,
                  (lr.top - stamp.position.dy) * sy,
                  lr.width * sx,
                  lr.height * sy,
                ))
            .toList()
        : <Rect>[Offset.zero & size];

    if (stamp.type == StampType.highlightRect) {
      final paint = Paint()..color = stamp.color.withValues(alpha: 0.35);
      for (final r in rects) {
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), paint);
      }
    } else if (stamp.type == StampType.underlineRect) {
      for (final r in rects) {
        final strokeThickness = (r.height * 0.065).clamp(0.8 * sy, 2.0 * sy);
        final paint = Paint()
          ..color = stamp.color
          ..strokeWidth = strokeThickness
          ..strokeCap = StrokeCap.round;
        final y = r.bottom - (strokeThickness * 0.5);
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
      }
    } else if (stamp.type == StampType.strikeoutRect) {
      for (final r in rects) {
        final strokeThickness = (r.height * 0.065).clamp(0.8 * sy, 2.0 * sy);
        final paint = Paint()
          ..color = stamp.color
          ..strokeWidth = strokeThickness
          ..strokeCap = StrokeCap.round;
        final y = r.top + r.height * 0.52;
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TextMarkupPainter oldDelegate) => true;
}

class _CheckMarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CheckMarkPainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth.clamp(2.5, 8.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.80)
      ..lineTo(size.width * 0.84, size.height * 0.22);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _CrossMarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CrossMarkPainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth.clamp(2.5, 8.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.22),
      Offset(size.width * 0.78, size.height * 0.78),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.22),
      Offset(size.width * 0.22, size.height * 0.78),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _LineShapePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _LineShapePainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _LineShapePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _ArrowShapePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _ArrowShapePainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final end = Offset(size.width, size.height);
    canvas.drawLine(Offset.zero, end, paint);
    canvas.drawLine(end, Offset(end.dx - 12, end.dy - 3), paint);
    canvas.drawLine(end, Offset(end.dx - 3, end.dy - 12), paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowShapePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _EllipseShapePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _EllipseShapePainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2.0;
    final rect = Rect.fromLTWH(half, half, size.width - strokeWidth, size.height - strokeWidth);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _EllipseShapePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _StrokesPainter extends CustomPainter {
  final List<DrawnStroke> strokes;
  final List<Offset> activePoints;
  final List<Rect> activeSnappedRects;
  final AnnotateTool activeTool;
  final Color activeColor;
  final double activeWidth;

  _StrokesPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeSnappedRects,
    required this.activeTool,
    required this.activeColor,
    required this.activeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint saved freehand strokes (scaled cleanly to current page viewer size)
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final sx = stroke.pageViewSize.width > 0 ? size.width / stroke.pageViewSize.width : 1.0;
      final sy = stroke.pageViewSize.height > 0 ? size.height / stroke.pageViewSize.height : 1.0;
      final avgS = (sx + sy) / 2.0;

      final paint = Paint()
        ..color = stroke.isHighlighter ? stroke.color.withValues(alpha: 0.35) : stroke.color
        ..strokeWidth = stroke.strokeWidth * avgS
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(stroke.points[0].dx * sx, stroke.points[0].dy * sy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx * sx, stroke.points[i].dy * sy);
      }
      canvas.drawPath(path, paint);
    }

    // 2. Paint live snapped markup rects while dragging over text!
    if (activeSnappedRects.isNotEmpty) {
      if (activeTool == AnnotateTool.underline) {
        for (final r in activeSnappedRects) {
          final strokeThickness = (r.height * 0.065).clamp(1.2, 2.5);
          final paint = Paint()
            ..color = activeColor
            ..strokeWidth = strokeThickness
            ..strokeCap = StrokeCap.round;
          final y = r.bottom - (strokeThickness * 0.5);
          canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
        }
      } else if (activeTool == AnnotateTool.strikeout) {
        for (final r in activeSnappedRects) {
          final strokeThickness = (r.height * 0.065).clamp(1.2, 2.5);
          final paint = Paint()
            ..color = activeColor
            ..strokeWidth = strokeThickness
            ..strokeCap = StrokeCap.round;
          final y = r.top + r.height * 0.52;
          canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
        }
      } else {
        final paint = Paint()..color = activeColor.withValues(alpha: 0.35);
        for (final r in activeSnappedRects) {
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), paint);
        }
      }
      return;
    }

    // 3. Paint freehand active stroke fallback
    if (activePoints.length >= 2 && activeTool != AnnotateTool.eraser && activeTool != AnnotateTool.select) {
      final isHighlighter = activeTool == AnnotateTool.highlighter;
      final paint = Paint()
        ..color = isHighlighter ? activeColor.withValues(alpha: 0.35) : activeColor
        ..strokeWidth = activeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(activePoints[0].dx, activePoints[0].dy);
      for (int i = 1; i < activePoints.length; i++) {
        path.lineTo(activePoints[i].dx, activePoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}

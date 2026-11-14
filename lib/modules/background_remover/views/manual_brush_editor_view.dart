import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/app_toast.dart';
import '../services/scribble_matting_engine.dart';
import '../widgets/preview_background_selector.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

enum EditorToolMode {
  aiGuided,
  erase,
  restore,
  panZoom,
}

class ManualBrushEditorView extends StatefulWidget {
  final Uint8List originalBytes;
  final Uint8List cutoutBytes;
  final PreviewBgMode initialPreviewBg;

  const ManualBrushEditorView({
    super.key,
    required this.originalBytes,
    required this.cutoutBytes,
    this.initialPreviewBg = PreviewBgMode.checkerboard,
  });

  static Future<Uint8List?> open({
    required BuildContext context,
    required Uint8List originalBytes,
    required Uint8List cutoutBytes,
    PreviewBgMode initialPreviewBg = PreviewBgMode.checkerboard,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ManualBrushEditorView(
          originalBytes: originalBytes,
          cutoutBytes: cutoutBytes,
          initialPreviewBg: initialPreviewBg,
        ),
      ),
    );
  }

  @override
  State<ManualBrushEditorView> createState() => _ManualBrushEditorViewState();
}

class _ManualBrushEditorViewState extends State<ManualBrushEditorView> {
  ui.Image? _originalImage;
  ui.Image? _cutoutImage;

  int _imgW = 0;
  int _imgH = 0;

  /// Unpremultiplied original RGB(A) pixels at exact (_imgW x _imgH) resolution.
  Uint8List? _origPixels;

  /// Premultiplied working cutout RGBA pixels at exact (_imgW x _imgH) resolution.
  Uint8List? _workPixels;

  /// Clean copy of initial cutout pixels for instant reset.
  Uint8List? _initialPixels;

  /// Undo / Redo stacks of working RGBA pixel snapshots (max 15 states).
  final List<Uint8List> _undoStack = [];
  final List<Uint8List> _redoStack = [];
  Uint8List? _strokeStartSnapshot;

  bool _isLoadingImages = true;
  bool _isSaving = false;
  bool _isUpdatingTexture = false;
  bool _needsTextureUpdate = false;

  EditorToolMode _mode = EditorToolMode.aiGuided;
  late PreviewBgMode _previewBg;

  double _brushSize = 28.0; // on-screen pixels
  bool _softEdges = true; // smooth antialiased feathering
  bool _smartEdgeSnap = true; // edge-aware color matting in erase/restore modes
  final double _smartTolerance = 88.0; // perceptual color tolerance

  // Scribble-Guided Smart Matting state
  ScribbleType _scribbleType = ScribbleType.show;
  final List<ScribbleStrokeData> _scribbles = [];
  final List<ScribbleStrokeData> _redoScribbles = [];
  List<double>? _activeScribbleCoords;
  double _activeRenderW = 1.0;
  bool _isProcessingAi = false;
  String _aiStatusMessage = '';

  // Active stroke state
  Offset? _currentTouchPoint;
  Offset? _lastNormPt;
  bool _activeStrokeIsRestore = false;
  bool _hasSeedColor = false;
  int _seedR = 0;
  int _seedG = 0;
  int _seedB = 0;
  double _seedVariance = 0.0;

  final TransformationController _transformController = TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _previewBg = widget.initialPreviewBg;
    _transformController.addListener(_onTransformChanged);
    _loadAndSyncImages();
  }

  void _onTransformChanged() {
    final matrix = _transformController.value;
    final isScaled = (matrix.getMaxScaleOnAxis() - 1.0).abs() > 0.05;
    final isTranslated = matrix.getTranslation().length > 5.0;
    final zoomed = isScaled || isTranslated;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() => _isZoomed = false);
    AppToast.showInfo('تمت إعادة ضبط التكبير إلى الوضع الطبيعي (1x)');
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _originalImage?.dispose();
    _cutoutImage?.dispose();
    super.dispose();
  }

  /// Decodes both images and normalizes `_originalImage` to the EXACT dimensions of `_cutoutImage`
  /// so there is zero coordinate or resolution mismatch.
  Future<void> _loadAndSyncImages() async {
    try {
      // 1. Decode cutout image first to establish canonical (W, H)
      final cutDesc = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(widget.cutoutBytes),
      );
      final cutCodec = await cutDesc.instantiateCodec();
      final cutFrame = await cutCodec.getNextFrame();
      final cutUiImg = cutFrame.image;

      final int w = cutUiImg.width;
      final int h = cutUiImg.height;

      // 2. Decode original image and rasterize to exact (w, h) if dimensions differ
      final origDesc = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(widget.originalBytes),
      );
      final origCodec = await origDesc.instantiateCodec();
      final origFrame = await origCodec.getNextFrame();
      final rawOrigImg = origFrame.image;

      final ui.Image syncedOrigImg;
      if (rawOrigImg.width == w && rawOrigImg.height == h) {
        syncedOrigImg = rawOrigImg;
      } else {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
        canvas.drawImageRect(
          rawOrigImg,
          Rect.fromLTWH(0, 0, rawOrigImg.width.toDouble(), rawOrigImg.height.toDouble()),
          Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..filterQuality = FilterQuality.high,
        );
        syncedOrigImg = await recorder.endRecording().toImage(w, h);
        rawOrigImg.dispose();
      }

      // 3. Extract raw RGBA pixel buffers at exact (w, h)
      final origBytesData = await syncedOrigImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      final cutBytesData = await cutUiImg.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (origBytesData == null || cutBytesData == null) {
        throw Exception('تعذر استخراج مصفوفة البكسلات من الصورة');
      }

      final origBuf = Uint8List.fromList(origBytesData.buffer.asUint8List());
      // Ensure _origPixels stores unpremultiplied RGB values for accurate color comparisons
      for (int i = 0; i < origBuf.length; i += 4) {
        final a = origBuf[i + 3];
        if (a > 0 && a < 255) {
          origBuf[i] = ((origBuf[i] * 255) ~/ a).clamp(0, 255);
          origBuf[i + 1] = ((origBuf[i + 1] * 255) ~/ a).clamp(0, 255);
          origBuf[i + 2] = ((origBuf[i + 2] * 255) ~/ a).clamp(0, 255);
        }
      }

      final workBuf = Uint8List.fromList(cutBytesData.buffer.asUint8List());

      if (mounted) {
        setState(() {
          _imgW = w;
          _imgH = h;
          _originalImage = syncedOrigImg;
          _cutoutImage = cutUiImg;
          _origPixels = origBuf;
          _workPixels = workBuf;
          _initialPixels = Uint8List.fromList(workBuf);
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImages = false);
        AppToast.showError('تعذر تحميل بيانات الصورة للتعديل: $e');
        Navigator.of(context).pop();
      }
    }
  }

  /// Uploads `_workPixels` to a GPU `ui.Image` texture once per frame without blocking touch input.
  void _scheduleTextureRefresh() {
    if (_workPixels == null || _imgW == 0 || _imgH == 0) return;
    if (_isUpdatingTexture) {
      _needsTextureUpdate = true;
      return;
    }
    _isUpdatingTexture = true;

    ui.decodeImageFromPixels(
      _workPixels!,
      _imgW,
      _imgH,
      ui.PixelFormat.rgba8888,
      (ui.Image newImg) {
        if (!mounted) {
          newImg.dispose();
          return;
        }
        final oldImg = _cutoutImage;
        setState(() {
          _cutoutImage = newImg;
        });
        oldImg?.dispose();
        _isUpdatingTexture = false;
        if (_needsTextureUpdate) {
          _needsTextureUpdate = false;
          _scheduleTextureRefresh();
        }
      },
    );
  }

  void _pushUndoSnapshot(Uint8List snapshot) {
    if (_undoStack.length >= 15) {
      _undoStack.removeAt(0);
    }
    _undoStack.add(snapshot);
    _redoStack.clear();
  }

  void _undo() {
    if (_isProcessingAi) return;
    if (_scribbles.isNotEmpty) {
      setState(() {
        _redoScribbles.add(_scribbles.removeLast());
      });
      return;
    }
    if (_undoStack.isEmpty || _workPixels == null) return;
    _redoStack.add(Uint8List.fromList(_workPixels!));
    final prev = _undoStack.removeLast();
    _workPixels!.setAll(0, prev);
    _scheduleTextureRefresh();
    setState(() {});
  }

  void _redo() {
    if (_isProcessingAi) return;
    if (_redoScribbles.isNotEmpty) {
      setState(() {
        _scribbles.add(_redoScribbles.removeLast());
      });
      return;
    }
    if (_redoStack.isEmpty || _workPixels == null) return;
    _undoStack.add(Uint8List.fromList(_workPixels!));
    final next = _redoStack.removeLast();
    _workPixels!.setAll(0, next);
    _scheduleTextureRefresh();
    setState(() {});
  }

  void _clearScribbles() {
    if (_isProcessingAi || (_scribbles.isEmpty && _redoScribbles.isEmpty)) return;
    setState(() {
      _scribbles.clear();
      _redoScribbles.clear();
      _activeScribbleCoords = null;
    });
  }

  Future<void> _applyLocalMatte() async {
    if (_isProcessingAi || _scribbles.isEmpty || _workPixels == null || _origPixels == null) {
      return;
    }

    final snapshot = Uint8List.fromList(_workPixels!);
    final strokes = List<ScribbleStrokeData>.from(_scribbles);

    setState(() {
      _isProcessingAi = true;
      _aiStatusMessage = 'جاري تطبيق التحديد الذكي...';
    });

    try {
      final updated = await ScribbleMattingEngine.solveLocalMatte(
        LocalMatteRequest(
          width: _imgW,
          height: _imgH,
          origRgba: _origPixels!,
          workRgba: Uint8List.fromList(_workPixels!),
          strokes: strokes,
        ),
      );
      if (!mounted) return;
      _pushUndoSnapshot(snapshot);
      _workPixels!.setAll(0, updated);
      _scribbles.clear();
      _redoScribbles.clear();
      _scheduleTextureRefresh();
    } catch (_) {
      AppToast.showError('تعذر تطبيق التحسين، حاول مرة أخرى');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAi = false;
          _aiStatusMessage = '';
        });
      }
    }
  }

  void _reset() {
    if (_isProcessingAi) return;
    if (_undoStack.isEmpty && _scribbles.isNotEmpty) {
      _clearScribbles();
      return;
    }
    if (_undoStack.isEmpty || _initialPixels == null || _workPixels == null) return;
    LuxuryDialog.show(
      context,
      compact: true,
      accentColor: Colors.redAccent,
      icon: Icons.restart_alt_rounded,
      title: 'إعادة تعيين التعديلات؟',
      message: 'سيتم التراجع عن كل التعديلات والعودة لنتيجة العزل الأولية.',
      secondaryButtonText: 'إلغاء',
      primaryButtonText: 'إعادة تعيين',
      primaryButtonIcon: Icons.restore_rounded,
      onPrimaryPressed: () {
        _undoStack.clear();
        _redoStack.clear();
        _scribbles.clear();
        _redoScribbles.clear();
        _activeScribbleCoords = null;
        _workPixels!.setAll(0, _initialPixels!);
        _scheduleTextureRefresh();
        setState(() {});
        AppToast.showInfo('تمت إعادة التعيين للنسخة الأولية');
      },
    );
  }

  // ── Edge-Aware Smart Matting & Brush Engine ──

  /// Perceptual Redmean Color Distance (0.0 to ~765.0) approximating CIELAB Delta-E in fast integer math.
  @pragma('vm:prefer-inline')
  static double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    final rMean = (r1 + r2) >> 1;
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    final weightR = 512 + rMean;
    final weightG = 1024;
    final weightB = 767 - rMean;
    return math.sqrt(((weightR * dr * dr) + (weightG * dg * dg) + (weightB * db * db)) >> 8);
  }

  @pragma('vm:prefer-inline')
  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  /// Samples a 5x5 neighborhood around `(cx, cy)` in `_origPixels` to lock onto the target surface color
  /// and measure local texture variance.
  void _sampleSeedPatch(int cx, int cy) {
    final orig = _origPixels!;
    int sumR = 0, sumG = 0, sumB = 0, count = 0;

    for (int dy = -2; dy <= 2; dy++) {
      final py = (cy + dy).clamp(0, _imgH - 1);
      for (int dx = -2; dx <= 2; dx++) {
        final px = (cx + dx).clamp(0, _imgW - 1);
        final idx = (py * _imgW + px) << 2;
        sumR += orig[idx];
        sumG += orig[idx + 1];
        sumB += orig[idx + 2];
        count++;
      }
    }

    _seedR = sumR ~/ count;
    _seedG = sumG ~/ count;
    _seedB = sumB ~/ count;

    double varSum = 0.0;
    for (int dy = -2; dy <= 2; dy++) {
      final py = (cy + dy).clamp(0, _imgH - 1);
      for (int dx = -2; dx <= 2; dx++) {
        final px = (cx + dx).clamp(0, _imgW - 1);
        final idx = (py * _imgW + px) << 2;
        varSum += _colorDistance(_seedR, _seedG, _seedB, orig[idx], orig[idx + 1], orig[idx + 2]);
      }
    }
    _seedVariance = (varSum / count).clamp(0.0, 50.0);
    _hasSeedColor = true;
  }

  void _onStrokeStart(Offset localPt, double renderW, double renderH) {
    if (_isProcessingAi || _isSaving || _workPixels == null || _origPixels == null) return;

    final normPt = Offset(
      (localPt.dx / renderW).clamp(0.0, 1.0),
      (localPt.dy / renderH).clamp(0.0, 1.0),
    );

    if (_mode == EditorToolMode.aiGuided) {
      _redoScribbles.clear();
      _activeRenderW = renderW;
      _activeScribbleCoords = [normPt.dx, normPt.dy];
      _currentTouchPoint = localPt;
      _lastNormPt = normPt;
      setState(() {});
      return;
    }

    _strokeStartSnapshot = Uint8List.fromList(_workPixels!);
    _redoStack.clear();
    _redoScribbles.clear();

    final cx = (normPt.dx * (_imgW - 1)).round();
    final cy = (normPt.dy * (_imgH - 1)).round();

    if (_mode == EditorToolMode.restore) {
      _activeStrokeIsRestore = true;
      _hasSeedColor = false;
      if (_smartEdgeSnap) {
        _sampleSeedPatch(cx, cy);
      }
    } else {
      _activeStrokeIsRestore = false;
      _hasSeedColor = false;
      if (_smartEdgeSnap) {
        final centerIdx = (cy * _imgW + cx) << 2;
        if (_workPixels![centerIdx + 3] > 20) {
          _sampleSeedPatch(cx, cy);
        }
      }
    }

    _currentTouchPoint = localPt;
    _lastNormPt = normPt;

    _applyBrushSegment(normPt, normPt, renderW);
    _scheduleTextureRefresh();
    setState(() {});
  }

  void _onStrokeUpdate(Offset localPt, double renderW, double renderH) {
    if (_isProcessingAi || _isSaving) return;

    final normPt = Offset(
      (localPt.dx / renderW).clamp(0.0, 1.0),
      (localPt.dy / renderH).clamp(0.0, 1.0),
    );

    if (_mode == EditorToolMode.aiGuided) {
      if (_activeScribbleCoords == null) return;
      final coords = _activeScribbleCoords!;
      final lastX = coords[coords.length - 2];
      final lastY = coords[coords.length - 1];
      final dx = normPt.dx - lastX;
      final dy = normPt.dy - lastY;
      if ((dx * dx + dy * dy) >= 0.000004) {
        coords.add(normPt.dx);
        coords.add(normPt.dy);
      }
      _currentTouchPoint = localPt;
      _lastNormPt = normPt;
      setState(() {});
      return;
    }

    if (_workPixels == null || _origPixels == null || _lastNormPt == null) return;

    _currentTouchPoint = localPt;
    _applyBrushSegment(_lastNormPt!, normPt, renderW);
    _lastNormPt = normPt;

    _scheduleTextureRefresh();
    setState(() {});
  }

  void _onStrokeEnd() {
    if (_mode == EditorToolMode.aiGuided) {
      if (_activeScribbleCoords != null && _activeScribbleCoords!.length >= 2) {
        final normRadius = ((_brushSize / 2.0) / math.max(1.0, _activeRenderW)).clamp(0.003, 0.25);
        _scribbles.add(
          ScribbleStrokeData(
            normCoords: List<double>.from(_activeScribbleCoords!),
            normRadius: normRadius,
            isShow: _scribbleType == ScribbleType.show,
          ),
        );
        _activeScribbleCoords = null;
      }
      setState(() {
        _currentTouchPoint = null;
        _lastNormPt = null;
        _hasSeedColor = false;
      });
      return;
    }

    if (_strokeStartSnapshot != null) {
      if (_undoStack.length >= 15) {
        _undoStack.removeAt(0);
      }
      _undoStack.add(_strokeStartSnapshot!);
      _strokeStartSnapshot = null;
    }
    setState(() {
      _currentTouchPoint = null;
      _lastNormPt = null;
      _hasSeedColor = false;
    });
  }

  void _applyBrushSegment(Offset fromNorm, Offset toNorm, double renderW) {
    final radiusPx = ((_brushSize / 2.0) / renderW) * _imgW;
    final clampedRadius = radiusPx.clamp(1.5, _imgW * 0.25);

    final x0 = fromNorm.dx * (_imgW - 1);
    final y0 = fromNorm.dy * (_imgH - 1);
    final x1 = toNorm.dx * (_imgW - 1);
    final y1 = toNorm.dy * (_imgH - 1);

    final dist = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
    final step = math.max(1.0, clampedRadius * 0.25);
    final steps = (dist / step).ceil().clamp(1, 120);

    final useSmartMatting = _smartEdgeSnap;

    for (int i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      final cx = (x0 + (x1 - x0) * t).round().clamp(0, _imgW - 1);
      final cy = (y0 + (y1 - y0) * t).round().clamp(0, _imgH - 1);

      // If user started erasing in empty space and just hit a visible pixel, lock onto its color now
      if (useSmartMatting && !_hasSeedColor) {
        final idx = (cy * _imgW + cx) << 2;
        if (!_activeStrokeIsRestore && _workPixels![idx + 3] > 25) {
          _sampleSeedPatch(cx, cy);
        } else if (_activeStrokeIsRestore) {
          _sampleSeedPatch(cx, cy);
        }
      }

      _applyBrushDab(cx, cy, clampedRadius, useSmartMatting);
    }
  }

  void _applyBrushDab(int cx, int cy, double radius, bool useSmartMatting) {
    final orig = _origPixels!;
    final work = _workPixels!;

    final rInt = radius.ceil();
    final minX = (cx - rInt).clamp(0, _imgW - 1);
    final maxX = (cx + rInt).clamp(0, _imgW - 1);
    final minY = (cy - rInt).clamp(0, _imgH - 1);
    final maxY = (cy + rInt).clamp(0, _imgH - 1);

    final rSq = radius * radius;
    final invRadius = 1.0 / radius;

    // Check local center color & whether local center is still on the same surface as the seed
    final cIdx = (cy * _imgW + cx) << 2;
    final cR = orig[cIdx];
    final cG = orig[cIdx + 1];
    final cB = orig[cIdx + 2];

    final effectiveTol = _smartTolerance + (_seedVariance * 0.65);
    final centerDistToSeed = _hasSeedColor ? _colorDistance(_seedR, _seedG, _seedB, cR, cG, cB) : 0.0;
    final isCenterValid = centerDistToSeed <= effectiveTol * 1.25;

    // Gently adapt seed color along smooth illumination gradients on the same surface
    if (useSmartMatting && _hasSeedColor && isCenterValid) {
      _seedR = ((_seedR * 15) + cR) >> 4;
      _seedG = ((_seedG * 15) + cG) >> 4;
      _seedB = ((_seedB * 15) + cB) >> 4;
    }

    final innerThreshold = effectiveTol * 0.65;
    final outerThreshold = effectiveTol * 1.38;

    for (int py = minY; py <= maxY; py++) {
      final dy = py - cy;
      final dySq = dy * dy;
      final rowOffset = py * _imgW;

      for (int px = minX; px <= maxX; px++) {
        final dx = px - cx;
        final dSq = dx * dx + dySq;
        if (dSq > rSq) continue;

        final idx = (rowOffset + px) << 2;
        final oldAlpha = work[idx + 3];

        // Skip redundant work
        if (!_activeStrokeIsRestore && oldAlpha == 0) continue;
        if (_activeStrokeIsRestore && oldAlpha == 255) continue;

        final normDist = math.sqrt(dSq) * invRadius; // 0.0 .. 1.0

        // 1. Spatial brush profile (Soft feathered vs Crisp edge)
        final double spatialWeight;
        if (_softEdges) {
          spatialWeight = normDist < 0.45 ? 1.0 : 1.0 - _smoothstep(0.45, 1.0, normDist);
        } else {
          spatialWeight = normDist < 0.88 ? 1.0 : 1.0 - _smoothstep(0.88, 1.0, normDist);
        }

        // 2. Edge-aware & color-aware matting weight
        double colorWeight = 1.0;
        if (useSmartMatting && _hasSeedColor) {
          final pR = orig[idx];
          final pG = orig[idx + 1];
          final pB = orig[idx + 2];

          double cDist = _colorDistance(_seedR, _seedG, _seedB, pR, pG, pB);
          if (isCenterValid) {
            final localDist = _colorDistance(cR, cG, cB, pR, pG, pB);
            if (localDist < cDist) cDist = localDist;
          }

          // Radial Edge-Barrier: sample midpoint between brush center and target pixel
          // so the brush does not jump across strong object boundaries.
          if (dSq > 16.0) {
            final midX = (cx + px) >> 1;
            final midY = (cy + py) >> 1;
            final midIdx = (midY * _imgW + midX) << 2;
            final midDist = _colorDistance(
              _seedR,
              _seedG,
              _seedB,
              orig[midIdx],
              orig[midIdx + 1],
              orig[midIdx + 2],
            );
            if (midDist * 0.85 > cDist) {
              cDist = midDist * 0.85;
            }
          }

          if (cDist >= outerThreshold) {
            continue; // Protected across edge boundary
          } else if (cDist > innerThreshold) {
            colorWeight = 1.0 - _smoothstep(innerThreshold, outerThreshold, cDist);
          }
        }

        final strength = spatialWeight * colorWeight;
        if (strength <= 0.01) continue;

        final int newAlpha;
        if (_activeStrokeIsRestore) {
          final added = ((255 - oldAlpha) * strength * 0.85).round();
          newAlpha = (oldAlpha + math.max<int>(added, (strength * 64).round())).clamp(0, 255).toInt();
        } else {
          final removed = (oldAlpha * strength * 0.85).round();
          newAlpha = (oldAlpha - math.max<int>(removed, (strength * 64).round())).clamp(0, 255).toInt();
        }

        if (newAlpha == oldAlpha) continue;

        final origR = orig[idx];
        final origG = orig[idx + 1];
        final origB = orig[idx + 2];

        // Store premultiplied RGBA for accurate Skia/Impeller compositing
        work[idx] = (origR * newAlpha) ~/ 255;
        work[idx + 1] = (origG * newAlpha) ~/ 255;
        work[idx + 2] = (origB * newAlpha) ~/ 255;
        work[idx + 3] = newAlpha;
      }
    }
  }

  Future<ui.Image> _buildImageFromPixels(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  Future<void> _applyAndSave() async {
    if (_workPixels == null || _imgW == 0 || _imgH == 0) return;

    if (_scribbles.isNotEmpty) {
      await _applyLocalMatte();
      if (!mounted) return;
    }

    setState(() => _isSaving = true);

    ui.Image? encodedImg;
    try {
      encodedImg = await _buildImageFromPixels(_workPixels!, _imgW, _imgH);
      final byteData = await encodedImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('تعذر تجهيز الصورة للحفظ');
      }

      final resultBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(resultBytes);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError('حدث خطأ أثناء حفظ التعديل');
      }
    } finally {
      encodedImg?.dispose();
    }
  }

  void _handleBack() {
    if (_isProcessingAi || _isSaving) return;
    if (_undoStack.isEmpty && _scribbles.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    LuxuryDialog.show(
      context,
      compact: true,
      accentColor: Theme.of(context).primaryColor,
      icon: Icons.save_rounded,
      title: 'حفظ التعديلات؟',
      message: 'لديك تعديلات غير محفوظة، هل تريد اعتمادها قبل الخروج؟',
      secondaryButtonText: 'تجاهل',
      onSecondaryPressed: () {
        if (mounted) Navigator.of(context).pop();
      },
      primaryButtonText: 'حفظ والعودة',
      primaryButtonIcon: Icons.check_rounded,
      onPrimaryPressed: () => _applyAndSave(),
    );
  }

  Color _activeAccentColor(Color primaryColor) {
    switch (_mode) {
      case EditorToolMode.aiGuided:
        return _scribbleType == ScribbleType.show ? const Color(0xFF10B981) : Colors.redAccent;
      case EditorToolMode.erase:
        return Colors.redAccent;
      case EditorToolMode.restore:
        return Colors.blueAccent;
      case EditorToolMode.panZoom:
        return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final bgColor = isDark ? const Color(0xFF0D0F17) : const Color(0xFFF3F4F8);
    final cardBg = theme.cardColor;
    final accentColor = _activeAccentColor(primaryColor);

    // Ghost overlay is ALWAYS active in AI Guided & Restore modes so missing parts are visible
    final showGhost = _mode == EditorToolMode.aiGuided || _mode == EditorToolMode.restore;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: (_isSaving || _isProcessingAi) ? null : _handleBack,
          ),
        title: const Text(
          'تعديل دقيق',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          // Direct Background Contrast Picker (No cycling)
          PreviewBgMenuButton(
            currentMode: _previewBg,
            onSelected: (mode) => setState(() => _previewBg = mode),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'تراجع',
            onPressed: (_scribbles.isNotEmpty || _undoStack.isNotEmpty) && !_isSaving && !_isProcessingAi
                ? _undo
                : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'إعادة',
            onPressed: (_redoScribbles.isNotEmpty || _redoStack.isNotEmpty) && !_isSaving && !_isProcessingAi
                ? _redo
                : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'إعادة تعيين',
            onPressed: (_scribbles.isNotEmpty || _undoStack.isNotEmpty) && !_isSaving && !_isProcessingAi
                ? _reset
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4, left: 6),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.check_rounded, color: Colors.green, size: 26),
                    tooltip: 'اعتماد وحفظ التعديل',
                    onPressed: (_isLoadingImages || _isProcessingAi) ? null : _applyAndSave,
                  ),
          ),
        ],
      ),
      body: _isLoadingImages
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Interactive Precision Drawing & Smart Edge Canvas ──
                Expanded(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final canvasWidth = constraints.maxWidth;
                        final canvasHeight = constraints.maxHeight;

                        final imgW = _cutoutImage!.width.toDouble();
                        final imgH = _cutoutImage!.height.toDouble();

                        // Fit inside available area maintaining aspect ratio
                        double renderW = canvasWidth;
                        double renderH = (canvasWidth / imgW) * imgH;
                        if (renderH > canvasHeight) {
                          renderH = canvasHeight;
                          renderW = (canvasHeight / imgH) * imgW;
                        }

                        final renderSize = Size(renderW, renderH);

                        Widget canvasContent = SizedBox(
                          width: renderW,
                          height: renderH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 1. Background (Checkerboard / Dark / Light)
                              Positioned.fill(
                                child: PreviewBackgroundCanvas(
                                  mode: _previewBg,
                                  cellSize: 14.0,
                                ),
                              ),

                              // 2. Live Cutout, Ghost Overlay & Scribbles Painter
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _BrushCanvasPainter(
                                    cutoutImage: _cutoutImage!,
                                    originalImage: _originalImage!,
                                    touchPoint: _currentTouchPoint,
                                    brushSize: _brushSize,
                                    cursorColor: accentColor,
                                    showGhostOverlay: showGhost,
                                    showCursor: _mode != EditorToolMode.panZoom && _currentTouchPoint != null,
                                    scribbles: _scribbles,
                                    activeScribbleCoords: _activeScribbleCoords,
                                    activeScribbleNormRadius:
                                        ((_brushSize / 2.0) / math.max(1.0, renderW)).clamp(0.003, 0.25),
                                    activeScribbleIsShow: _scribbleType == ScribbleType.show,
                                  ),
                                ),
                              ),

                              // 3. Touch Gestures Handler
                              if (_mode != EditorToolMode.panZoom && !_isProcessingAi)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (details) =>
                                        _onStrokeStart(details.localPosition, renderW, renderH),
                                    onPanUpdate: (details) =>
                                        _onStrokeUpdate(details.localPosition, renderW, renderH),
                                    onPanEnd: (_) => _onStrokeEnd(),
                                    onPanCancel: _onStrokeEnd,
                                  ),
                                ),

                              // 4. Adaptive Floating Precision Zoom Loupe (Never occluded by finger)
                              if (_currentTouchPoint != null && _mode != EditorToolMode.panZoom) ...[
                                Builder(builder: (context) {
                                  final isTouchOnRight = _currentTouchPoint!.dx > renderW / 2;
                                  final isTouchOnTop = _currentTouchPoint!.dy < renderH * 0.38;

                                  return Positioned(
                                    top: isTouchOnTop ? null : 14,
                                    bottom: isTouchOnTop ? 14 : null,
                                    left: isTouchOnRight ? 14 : null,
                                    right: isTouchOnRight ? null : 14,
                                    child: _FloatingPrecisionLoupe(
                                      cutoutImage: _cutoutImage!,
                                      originalImage: _originalImage!,
                                      brushSize: _brushSize,
                                      ringColor: accentColor,
                                      showGhostOverlay: showGhost,
                                      touchPoint: _currentTouchPoint!,
                                      renderSize: renderSize,
                                      previewBg: _previewBg,
                                      isDark: isDark,
                                      scribbles: _scribbles,
                                      activeScribbleCoords: _activeScribbleCoords,
                                      activeScribbleNormRadius:
                                          ((_brushSize / 2.0) / math.max(1.0, renderW)).clamp(0.003, 0.25),
                                      activeScribbleIsShow: _scribbleType == ScribbleType.show,
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );

                        // Stack with Persistent InteractiveViewer, 1x Reset Chip, Floating Scribble Actions & AI Loading Overlay
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.8,
                                maxScale: 6.0,
                                panEnabled: _mode == EditorToolMode.panZoom && !_isProcessingAi,
                                scaleEnabled: _mode == EditorToolMode.panZoom && !_isProcessingAi,
                                boundaryMargin: const EdgeInsets.all(120),
                                child: Center(child: canvasContent),
                              ),
                            ),

                            // Floating 1x Reset Zoom Chip (when zoomed in)
                            if (_isZoomed)
                              Positioned(
                                top: 14,
                                left: 14,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  elevation: 4,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _resetZoom,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 5),
                                          Text(
                                            '1x ضبط العرض',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Floating Action Bar for Guided Scribble Matting
                            if (_scribbles.isNotEmpty && !_isProcessingAi)
                              Positioned(
                                bottom: 14,
                                left: 12,
                                right: 12,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (isDark ? const Color(0xFF151824) : Colors.white)
                                          .withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : Colors.black.withValues(alpha: 0.08),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.22),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Clear pending scribbles
                                        InkWell(
                                          onTap: _clearScribbles,
                                          borderRadius: BorderRadius.circular(18),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.delete_sweep_rounded,
                                                  size: 16,
                                                  color: theme.textTheme.bodyMedium?.color
                                                      ?.withValues(alpha: 0.72),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'مسح التحديد',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.textTheme.bodyMedium?.color
                                                        ?.withValues(alpha: 0.78),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Apply fast local geodesic + adaptive smart matting
                                        ElevatedButton.icon(
                                          onPressed: _applyLocalMatte,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                                          label: const Text(
                                            'تطبيق التحديد الذكي',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Processing Progress Overlay
                            if (_isProcessingAi)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  child: Center(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 32),
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3.0,
                                              color: Color(0xFF6366F1),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            _aiStatusMessage.isEmpty
                                                ? 'جاري المعالجة...'
                                                : _aiStatusMessage,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // ── Bottom Control Panel ──
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Hint text
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _mode == EditorToolMode.aiGuided
                                ? 'علّم بالأخضر (+) لإظهار الأجزاء المفقودة وبالأحمر (-) لإخفاء الزوائد، ثم اضغط تطبيق التحديد الذكي'
                                : (_mode == EditorToolMode.erase
                                    ? 'المس الشاشة لمسح الزوائد (تتكيف العدسة المكبرة تلقائياً لتفادي حجب إصبعك)'
                                    : (_mode == EditorToolMode.restore
                                        ? 'يظهر طيف الصورة الأصلية بالخلفية لترسم فوقه مباشرة وتسترجع الأجزاء المحذوفة'
                                        : 'استخدم إصبعين للتكبير والتحريك بحرية (يبقى التكبير ثابتاً عند التبديل)')),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.78),
                            ),
                          ),
                        ),

                        // Brush Size & Mode-Specific Controls
                        if (_mode != EditorToolMode.panZoom) ...[
                          Row(
                            children: [
                              const Icon(Icons.circle, size: 9, color: Colors.grey),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.5,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  ),
                                  child: Slider(
                                    value: _brushSize,
                                    min: 6.0,
                                    max: 80.0,
                                    activeColor: accentColor,
                                    onChanged: (val) => setState(() => _brushSize = val),
                                  ),
                                ),
                              ),
                              const Icon(Icons.circle, size: 20, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                '${_brushSize.round()} px',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // In AI Guided mode: Show (+) vs Hide (-) Scribble Pills
                              if (_mode == EditorToolMode.aiGuided) ...[
                                InkWell(
                                  onTap: () => setState(() => _scribbleType = ScribbleType.show),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _scribbleType == ScribbleType.show
                                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                          : (isDark ? const Color(0xFF1E2230) : const Color(0xFFE5E7EB)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _scribbleType == ScribbleType.show
                                            ? const Color(0xFF10B981)
                                            : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 14,
                                          color: _scribbleType == ScribbleType.show
                                              ? const Color(0xFF10B981)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'إظهار',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: _scribbleType == ScribbleType.show
                                                ? const Color(0xFF10B981)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => setState(() => _scribbleType = ScribbleType.hide),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _scribbleType == ScribbleType.hide
                                          ? Colors.redAccent.withValues(alpha: 0.18)
                                          : (isDark ? const Color(0xFF1E2230) : const Color(0xFFE5E7EB)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _scribbleType == ScribbleType.hide
                                            ? Colors.redAccent
                                            : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 14,
                                          color: _scribbleType == ScribbleType.hide
                                              ? Colors.redAccent
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'إخفاء',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: _scribbleType == ScribbleType.hide
                                                ? Colors.redAccent
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // In Erase/Restore modes: Toggle Smart Edge Protection vs Free Manual Brush & Softness
                              if (_mode == EditorToolMode.erase || _mode == EditorToolMode.restore) ...[
                                InkWell(
                                  onTap: () => setState(() => _smartEdgeSnap = !_smartEdgeSnap),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _smartEdgeSnap
                                          ? const Color(0xFF6366F1).withValues(alpha: 0.16)
                                          : (isDark ? const Color(0xFF1E2230) : const Color(0xFFE5E7EB)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _smartEdgeSnap ? const Color(0xFF6366F1) : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 13.5,
                                          color: _smartEdgeSnap ? const Color(0xFF6366F1) : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _smartEdgeSnap ? 'حماية الحواف' : 'فرشاة حرة',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: _smartEdgeSnap ? const Color(0xFF6366F1) : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Edge Softness / Feathering Pill Toggle
                                InkWell(
                                  onTap: () => setState(() => _softEdges = !_softEdges),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _softEdges
                                          ? primaryColor.withValues(alpha: 0.16)
                                          : (isDark ? const Color(0xFF1E2230) : const Color(0xFFE5E7EB)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _softEdges ? primaryColor : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _softEdges ? Icons.blur_on_rounded : Icons.blur_off_rounded,
                                          size: 14,
                                          color: _softEdges ? primaryColor : Colors.grey,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _softEdges ? 'ناعمة' : 'حادة',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: _softEdges ? primaryColor : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Mode Selector Buttons
                        Row(
                          children: [
                            // Interactive Scribble-Guided AI Matting (+/-)
                            Expanded(
                              child: _ModeButton(
                                icon: Icons.auto_awesome_rounded,
                                label: 'تحديد ذكي (+/-)',
                                isSelected: _mode == EditorToolMode.aiGuided,
                                activeColor: _scribbleType == ScribbleType.show
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                                onTap: () => setState(() => _mode = EditorToolMode.aiGuided),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Dedicated Erase Button
                            Expanded(
                              child: _ModeButton(
                                icon: Icons.auto_fix_normal_rounded,
                                label: 'مسح بالعدسة',
                                isSelected: _mode == EditorToolMode.erase,
                                activeColor: Colors.redAccent,
                                onTap: () => setState(() => _mode = EditorToolMode.erase),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Dedicated Restore Button
                            Expanded(
                              child: _ModeButton(
                                icon: Icons.brush_rounded,
                                label: 'استرجاع بالعدسة',
                                isSelected: _mode == EditorToolMode.restore,
                                activeColor: Colors.blueAccent,
                                onTap: () => setState(() => _mode = EditorToolMode.restore),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Pan / Zoom Button
                            Expanded(
                              child: _ModeButton(
                                icon: Icons.pinch_rounded,
                                label: 'تكبير وتحريك',
                                isSelected: _mode == EditorToolMode.panZoom,
                                activeColor: primaryColor,
                                onTap: () => setState(() => _mode = EditorToolMode.panZoom),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: 0.16)
          : (isDark ? const Color(0xFF1E2230) : const Color(0xFFF0F1F5)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? activeColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _paintScribbles(
  Canvas canvas,
  Size size,
  List<ScribbleStrokeData> scribbles,
  List<double>? activeCoords,
  double activeNormRadius,
  bool activeIsShow,
) {
  final hasActive = activeCoords != null && activeCoords.length >= 2;
  if (scribbles.isEmpty && !hasActive) return;

  canvas.saveLayer(
    Offset.zero & size,
    Paint()..color = const Color.fromRGBO(255, 255, 255, 0.54),
  );

  void drawStroke(List<double> coords, double normRadius, bool isShow) {
    if (coords.length < 2) return;
    final color = isShow ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final radius = normRadius * size.width;
    if (coords.length == 2) {
      final pt = Offset(coords[0] * size.width, coords[1] * size.height);
      canvas.drawCircle(pt, radius, Paint()..color = color);
      return;
    }

    final path = Path()..moveTo(coords[0] * size.width, coords[1] * size.height);
    for (int i = 2; i < coords.length; i += 2) {
      path.lineTo(coords[i] * size.width, coords[i + 1] * size.height);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  for (final s in scribbles) {
    drawStroke(s.normCoords, s.normRadius, s.isShow);
  }
  if (hasActive) {
    drawStroke(activeCoords, activeNormRadius, activeIsShow);
  }

  canvas.restore();
}

/// Floating Precision Magnifying Loupe
class _FloatingPrecisionLoupe extends StatelessWidget {
  final ui.Image cutoutImage;
  final ui.Image originalImage;
  final double brushSize;
  final Color ringColor;
  final bool showGhostOverlay;
  final Offset touchPoint;
  final Size renderSize;
  final PreviewBgMode previewBg;
  final bool isDark;
  final List<ScribbleStrokeData> scribbles;
  final List<double>? activeScribbleCoords;
  final double activeScribbleNormRadius;
  final bool activeScribbleIsShow;

  const _FloatingPrecisionLoupe({
    required this.cutoutImage,
    required this.originalImage,
    required this.brushSize,
    required this.ringColor,
    required this.showGhostOverlay,
    required this.touchPoint,
    required this.renderSize,
    required this.previewBg,
    required this.isDark,
    required this.scribbles,
    required this.activeScribbleCoords,
    required this.activeScribbleNormRadius,
    required this.activeScribbleIsShow,
  });

  @override
  Widget build(BuildContext context) {
    const double loupeSize = 138.0;

    return Container(
      width: loupeSize,
      height: loupeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: 3.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: const Size(loupeSize, loupeSize),
          painter: _LoupePainter(
            cutoutImage: cutoutImage,
            originalImage: originalImage,
            touchPoint: touchPoint,
            brushSize: brushSize,
            ringColor: ringColor,
            showGhostOverlay: showGhostOverlay,
            renderSize: renderSize,
            previewBg: previewBg,
            isDark: isDark,
            scribbles: scribbles,
            activeScribbleCoords: activeScribbleCoords,
            activeScribbleNormRadius: activeScribbleNormRadius,
            activeScribbleIsShow: activeScribbleIsShow,
          ),
        ),
      ),
    );
  }
}

class _LoupePainter extends CustomPainter {
  final ui.Image cutoutImage;
  final ui.Image originalImage;
  final Offset touchPoint;
  final double brushSize;
  final Color ringColor;
  final bool showGhostOverlay;
  final Size renderSize;
  final PreviewBgMode previewBg;
  final bool isDark;
  final List<ScribbleStrokeData> scribbles;
  final List<double>? activeScribbleCoords;
  final double activeScribbleNormRadius;
  final bool activeScribbleIsShow;

  _LoupePainter({
    required this.cutoutImage,
    required this.originalImage,
    required this.touchPoint,
    required this.brushSize,
    required this.ringColor,
    required this.showGhostOverlay,
    required this.renderSize,
    required this.previewBg,
    required this.isDark,
    required this.scribbles,
    required this.activeScribbleCoords,
    required this.activeScribbleNormRadius,
    required this.activeScribbleIsShow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double zoom = 2.8;
    final center = Offset(size.width / 2, size.height / 2);
    final srcRect = Rect.fromLTWH(0, 0, cutoutImage.width.toDouble(), cutoutImage.height.toDouble());
    final dstRect = Offset.zero & renderSize;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-touchPoint.dx, -touchPoint.dy);

    // 1. Draw Background mode
    paintPreviewBackground(canvas, renderSize, previewBg, isDark, cellSize: 14.0);

    // 2. Faint Ghost original overlay (when in AI Guided or Restore mode)
    if (showGhostOverlay) {
      final ghostPaint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.32);
      canvas.drawImageRect(originalImage, srcRect, dstRect, ghostPaint);
    }

    // 3. Draw live cutout image
    canvas.drawImageRect(cutoutImage, srcRect, dstRect, Paint());

    // 4. Draw pending scribble marks inside zoomed loupe
    _paintScribbles(
      canvas,
      renderSize,
      scribbles,
      activeScribbleCoords,
      activeScribbleNormRadius,
      activeScribbleIsShow,
    );

    canvas.restore();

    // 5. Draw precision crosshairs (+) in loupe center
    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(center.dx - 10, center.dy), Offset(center.dx + 10, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 10), Offset(center.dx, center.dy + 10), crosshairPaint);

    // 6. Draw brush size ring in loupe center
    final brushRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = ringColor
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, (brushSize * zoom) / 2, brushRingPaint);
  }

  @override
  bool shouldRepaint(covariant _LoupePainter oldDelegate) => true;
}

class _BrushCanvasPainter extends CustomPainter {
  final ui.Image cutoutImage;
  final ui.Image originalImage;
  final Offset? touchPoint;
  final double brushSize;
  final Color cursorColor;
  final bool showGhostOverlay;
  final bool showCursor;
  final List<ScribbleStrokeData> scribbles;
  final List<double>? activeScribbleCoords;
  final double activeScribbleNormRadius;
  final bool activeScribbleIsShow;

  _BrushCanvasPainter({
    required this.cutoutImage,
    required this.originalImage,
    required this.touchPoint,
    required this.brushSize,
    required this.cursorColor,
    required this.showGhostOverlay,
    required this.showCursor,
    required this.scribbles,
    required this.activeScribbleCoords,
    required this.activeScribbleNormRadius,
    required this.activeScribbleIsShow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, cutoutImage.width.toDouble(), cutoutImage.height.toDouble());
    final dstRect = Offset.zero & size;

    // 1. Faint Ghost original overlay (always active in AI Guided & Restore modes)
    if (showGhostOverlay) {
      final ghostPaint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.32);
      canvas.drawImageRect(originalImage, srcRect, dstRect, ghostPaint);
    }

    // 2. Draw live cutout image
    canvas.drawImageRect(cutoutImage, srcRect, dstRect, Paint());

    // 3. Draw pending scribble marks
    _paintScribbles(
      canvas,
      size,
      scribbles,
      activeScribbleCoords,
      activeScribbleNormRadius,
      activeScribbleIsShow,
    );

    // 4. Draw brush size cursor under touch
    if (showCursor && touchPoint != null) {
      final cursorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = cursorColor;

      final innerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = cursorColor.withValues(alpha: 0.18);

      canvas.drawCircle(touchPoint!, brushSize / 2, innerPaint);
      canvas.drawCircle(touchPoint!, brushSize / 2, cursorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrushCanvasPainter oldDelegate) => true;
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

enum ScribbleType {
  show,
  hide,
}

class ScribbleStrokeData {
  /// Flat normalized coordinates [x0, y0, x1, y1, ...] in 0..1 range.
  final List<double> normCoords;
  final double normRadius;
  final bool isShow;

  const ScribbleStrokeData({
    required this.normCoords,
    required this.normRadius,
    required this.isShow,
  });
}

class LocalMatteRequest {
  final int width;
  final int height;
  final Uint8List origRgba; // unpremultiplied RGBA
  final Uint8List workRgba; // premultiplied RGBA
  final List<ScribbleStrokeData> strokes;

  const LocalMatteRequest({
    required this.width,
    required this.height,
    required this.origRgba,
    required this.workRgba,
    required this.strokes,
  });
}

class ScribbleMattingEngine {
  /// Runs Local Exterior Border Sampling, 3-Rule Edge-Guarded Flood, and
  /// Geodesic Stroke Spine Propagation in a background Isolate.
  static Future<Uint8List> solveLocalMatte(LocalMatteRequest req) {
    return compute(_solveLocalMatteIsolate, req);
  }
}

@pragma('vm:prefer-inline')
int _perceptualDistSq(int r1, int g1, int b1, int r2, int g2, int b2) {
  final rMean = (r1 + r2) >> 1;
  final dr = r1 - r2;
  final dg = g1 - g2;
  final db = b1 - b2;
  return (((512 + rMean) * dr * dr) + (1024 * dg * dg) + ((767 - rMean) * db * db)) >> 8;
}

@pragma('vm:prefer-inline')
double _perceptualDist(int r1, int g1, int b1, int r2, int g2, int b2) {
  return math.sqrt(_perceptualDistSq(r1, g1, b1, r2, g2, b2));
}

class _RasterizedRoi {
  final int roiX;
  final int roiY;
  final int roiW;
  final int roiH;
  final int margin;
  final Uint8List scribbleMask; // 0=none, 1=show, 2=hide
  final Uint8List showCoreMask; // 1 on Show stroke spine (0.6 * rPx)
  final Uint8List hideCoreMask; // 1 on Hide stroke spine (0.65 * rPx)
  final Float32List distShow;
  final Float32List distHide;
  final bool hasShow;
  final bool hasHide;

  _RasterizedRoi({
    required this.roiX,
    required this.roiY,
    required this.roiW,
    required this.roiH,
    required this.margin,
    required this.scribbleMask,
    required this.showCoreMask,
    required this.hideCoreMask,
    required this.distShow,
    required this.distHide,
    required this.hasShow,
    required this.hasHide,
  });
}

_RasterizedRoi _rasterizeScribbles({
  required int w,
  required int h,
  required List<ScribbleStrokeData> strokes,
  required int influenceMargin,
}) {
  bool hasShow = false;
  bool hasHide = false;

  int minX = w - 1;
  int maxX = 0;
  int minY = h - 1;
  int maxY = 0;

  for (final s in strokes) {
    if (s.isShow) {
      hasShow = true;
    } else {
      hasHide = true;
    }
    final int rPx = (s.normRadius * w).ceil().clamp(2, math.max<int>(4, w ~/ 4)).toInt();
    for (int i = 0; i + 1 < s.normCoords.length; i += 2) {
      final px = (s.normCoords[i] * (w - 1)).round();
      final py = (s.normCoords[i + 1] * (h - 1)).round();
      if (px - rPx < minX) minX = px - rPx;
      if (px + rPx > maxX) maxX = px + rPx;
      if (py - rPx < minY) minY = py - rPx;
      if (py + rPx > maxY) maxY = py + rPx;
    }
  }

  final int roiX = (minX - influenceMargin).clamp(0, w - 1);
  final int roiY = (minY - influenceMargin).clamp(0, h - 1);
  final int roiMaxX = (maxX + influenceMargin).clamp(0, w - 1);
  final int roiMaxY = (maxY + influenceMargin).clamp(0, h - 1);

  final int roiW = (roiMaxX - roiX + 1).clamp(1, w);
  final int roiH = (roiMaxY - roiY + 1).clamp(1, h);

  final mask = Uint8List(roiW * roiH);
  final showCore = Uint8List(roiW * roiH);
  final hideCore = Uint8List(roiW * roiH);

  for (final s in strokes) {
    final val = s.isShow ? 1 : 2;
    final rPx = (s.normRadius * w).clamp(1.5, w * 0.2);
    final rSq = rPx * rPx;
    final coreR = math.max(1.0, s.isShow ? rPx * 0.6 : rPx * 0.65);
    final coreRSq = coreR * coreR;
    final rInt = rPx.ceil();
    final coords = s.normCoords;

    void stampCircle(int cx, int cy) {
      final x0 = (cx - rInt).clamp(0, roiW - 1);
      final x1 = (cx + rInt).clamp(0, roiW - 1);
      final y0 = (cy - rInt).clamp(0, roiH - 1);
      final y1 = (cy + rInt).clamp(0, roiH - 1);
      for (int y = y0; y <= y1; y++) {
        final dy = y - cy;
        final dySq = dy * dy;
        final row = y * roiW;
        for (int x = x0; x <= x1; x++) {
          final dx = x - cx;
          final dSq = dx * dx + dySq;
          if (dSq <= rSq) {
            final ri = row + x;
            mask[ri] = val;
            if (dSq <= coreRSq) {
              if (s.isShow) {
                showCore[ri] = 1;
                hideCore[ri] = 0;
              } else {
                hideCore[ri] = 1;
                showCore[ri] = 0;
              }
            }
          }
        }
      }
    }

    if (coords.length < 4) {
      if (coords.length >= 2) {
        stampCircle(
          (coords[0] * (w - 1)).round() - roiX,
          (coords[1] * (h - 1)).round() - roiY,
        );
      }
      continue;
    }

    for (int i = 0; i + 3 < coords.length; i += 2) {
      final x0 = coords[i] * (w - 1) - roiX;
      final y0 = coords[i + 1] * (h - 1) - roiY;
      final x1 = coords[i + 2] * (w - 1) - roiX;
      final y1 = coords[i + 3] * (h - 1) - roiY;
      final dist = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
      final step = math.max(1.0, rPx * 0.35);
      final steps = (dist / step).ceil().clamp(1, 300);
      for (int st = 0; st <= steps; st++) {
        final t = st / steps;
        stampCircle((x0 + (x1 - x0) * t).round(), (y0 + (y1 - y0) * t).round());
      }
    }
  }

  // 2-Pass Chamfer Distance Transform inside ROI for Show (1) and Hide (2)
  const double inf = 1e6;
  final distShow = Float32List(roiW * roiH);
  final distHide = Float32List(roiW * roiH);

  for (int i = 0; i < mask.length; i++) {
    distShow[i] = mask[i] == 1 ? 0.0 : inf;
    distHide[i] = mask[i] == 2 ? 0.0 : inf;
  }

  void runDistancePass(Float32List d) {
    for (int y = 0; y < roiH; y++) {
      final row = y * roiW;
      for (int x = 0; x < roiW; x++) {
        final idx = row + x;
        double best = d[idx];
        if (x > 0) {
          final v = d[idx - 1] + 1.0;
          if (v < best) best = v;
        }
        if (y > 0) {
          final top = idx - roiW;
          double v = d[top] + 1.0;
          if (v < best) best = v;
          if (x > 0) {
            v = d[top - 1] + 1.414;
            if (v < best) best = v;
          }
          if (x + 1 < roiW) {
            v = d[top + 1] + 1.414;
            if (v < best) best = v;
          }
        }
        d[idx] = best;
      }
    }
    for (int y = roiH - 1; y >= 0; y--) {
      final row = y * roiW;
      for (int x = roiW - 1; x >= 0; x--) {
        final idx = row + x;
        double best = d[idx];
        if (x + 1 < roiW) {
          final v = d[idx + 1] + 1.0;
          if (v < best) best = v;
        }
        if (y + 1 < roiH) {
          final bot = idx + roiW;
          double v = d[bot] + 1.0;
          if (v < best) best = v;
          if (x > 0) {
            v = d[bot - 1] + 1.414;
            if (v < best) best = v;
          }
          if (x + 1 < roiW) {
            v = d[bot + 1] + 1.414;
            if (v < best) best = v;
          }
        }
        d[idx] = best;
      }
    }
  }

  if (hasShow) runDistancePass(distShow);
  if (hasHide) runDistancePass(distHide);

  return _RasterizedRoi(
    roiX: roiX,
    roiY: roiY,
    roiW: roiW,
    roiH: roiH,
    margin: influenceMargin,
    scribbleMask: mask,
    showCoreMask: showCore,
    hideCoreMask: hideCore,
    distShow: distShow,
    distHide: distHide,
    hasShow: hasShow,
    hasHide: hasHide,
  );
}

void _addDiverseColor(
  List<int> palette,
  int r,
  int g,
  int b, {
  int maxColors = 48,
  double minDist = 10.0,
}) {
  if (palette.length >= maxColors * 3) return;
  final int minDistSq = (minDist * minDist).round();
  for (int i = 0; i < palette.length; i += 3) {
    if (_perceptualDistSq(palette[i], palette[i + 1], palette[i + 2], r, g, b) < minDistSq) {
      return;
    }
  }
  palette.add(r);
  palette.add(g);
  palette.add(b);
}

(double, int, int, int) _nearestPaletteColor(List<int> palette, int r, int g, int b) {
  int bestDistSq = 0x7fffffff;
  int bestR = r, bestG = g, bestB = b;
  for (int i = 0; i < palette.length; i += 3) {
    final pr = palette[i];
    final pg = palette[i + 1];
    final pb = palette[i + 2];
    final dSq = _perceptualDistSq(r, g, b, pr, pg, pb);
    if (dSq < bestDistSq) {
      bestDistSq = dSq;
      bestR = pr;
      bestG = pg;
      bestB = pb;
    }
  }
  return (math.sqrt(bestDistSq), bestR, bestG, bestB);
}

/// Identifies pixels connected to the image outer perimeter through smooth transparent
/// canvas (`workAlpha <= 32` & gentle orig step `<= 10.0`), so enclosed interiors
/// (such as white cards inside purple borders) are never mistaken for exterior seeds.
(Uint8List mask, bool hasAnySeed) _computeGlobalExteriorMask({
  required int w,
  required int h,
  required Uint8List orig,
  required Uint8List work,
}) {
  final total = w * h;
  final extMask = Uint8List(total);
  final queue = Int32List(total);
  int qHead = 0;
  int qTail = 0;

  void trySeed(int x, int y) {
    final pi = y * w + x;
    if (extMask[pi] == 1) return;
    if (work[(pi << 2) + 3] <= 15) {
      extMask[pi] = 1;
      queue[qTail++] = pi;
    }
  }

  for (int x = 0; x < w; x++) {
    trySeed(x, 0);
    if (h > 1) trySeed(x, h - 1);
  }
  for (int y = 1; y < h - 1; y++) {
    trySeed(0, y);
    if (w > 1) trySeed(w - 1, y);
  }

  final bool hasAnySeed = qTail > 0;
  const int maxStepSq = 100; // stepDist <= 10.0

  while (qHead < qTail) {
    final curr = queue[qHead++];
    final cx = curr % w;
    final cy = curr ~/ w;
    final cIdx = curr << 2;
    final cR = orig[cIdx], cG = orig[cIdx + 1], cB = orig[cIdx + 2];

    if (cx > 0) {
      final ni = curr - 1;
      if (extMask[ni] == 0) {
        final nIdx = ni << 2;
        if (work[nIdx + 3] <= 32 &&
            _perceptualDistSq(cR, cG, cB, orig[nIdx], orig[nIdx + 1], orig[nIdx + 2]) <= maxStepSq) {
          extMask[ni] = 1;
          queue[qTail++] = ni;
        }
      }
    }
    if (cx + 1 < w) {
      final ni = curr + 1;
      if (extMask[ni] == 0) {
        final nIdx = ni << 2;
        if (work[nIdx + 3] <= 32 &&
            _perceptualDistSq(cR, cG, cB, orig[nIdx], orig[nIdx + 1], orig[nIdx + 2]) <= maxStepSq) {
          extMask[ni] = 1;
          queue[qTail++] = ni;
        }
      }
    }
    if (cy > 0) {
      final ni = curr - w;
      if (extMask[ni] == 0) {
        final nIdx = ni << 2;
        if (work[nIdx + 3] <= 32 &&
            _perceptualDistSq(cR, cG, cB, orig[nIdx], orig[nIdx + 1], orig[nIdx + 2]) <= maxStepSq) {
          extMask[ni] = 1;
          queue[qTail++] = ni;
        }
      }
    }
    if (cy + 1 < h) {
      final ni = curr + w;
      if (extMask[ni] == 0) {
        final nIdx = ni << 2;
        if (work[nIdx + 3] <= 32 &&
            _perceptualDistSq(cR, cG, cB, orig[nIdx], orig[nIdx + 1], orig[nIdx + 2]) <= maxStepSq) {
          extMask[ni] = 1;
          queue[qTail++] = ni;
        }
      }
    }
  }

  return (extMask, hasAnySeed);
}

Uint8List _solveLocalMatteIsolate(LocalMatteRequest req) {
  return _solveLocalMatteCore(
    w: req.width,
    h: req.height,
    orig: req.origRgba,
    work: req.workRgba,
    strokes: req.strokes,
  );
}

Uint8List _solveLocalMatteCore({
  required int w,
  required int h,
  required Uint8List orig,
  required Uint8List work,
  required List<ScribbleStrokeData> strokes,
}) {
  final out = Uint8List.fromList(work);
  if (strokes.isEmpty || w <= 0 || h <= 0) return out;

  double maxNormR = 0.02;
  for (final s in strokes) {
    if (s.normRadius > maxNormR) maxNormR = s.normRadius;
  }
  final margin = math.max((maxNormR * w * 1.8).round(), 28);

  final roi = _rasterizeScribbles(
    w: w,
    h: h,
    strokes: strokes,
    influenceMargin: margin,
  );

  final roiTotal = roi.roiW * roi.roiH;
  final (globalExtMask, hasGlobalExterior) = _computeGlobalExteriorMask(
    w: w,
    h: h,
    orig: orig,
    work: work,
  );

  bool isExteriorSeed(int x, int y, int ri, int gIdx) {
    final mark = roi.scribbleMask[ri];
    if (mark == 2) return true;
    if (mark != 0 || work[(gIdx << 2) + 3] > 15) return false;
    if (hasGlobalExterior) {
      return globalExtMask[y * w + x] == 1;
    }
    // Fallback only if all 4 image edges were opaque foreground
    return ri % roi.roiW == 0 ||
        ri % roi.roiW == roi.roiW - 1 ||
        ri ~/ roi.roiW == 0 ||
        ri ~/ roi.roiW == roi.roiH - 1;
  }

  // ── 1. Local Exterior Background Estimation (2.0 <= dist <= 16.0 ring outside strokes) ──
  final localBgPalette = <int>[];
  final gradSamples = <double>[];

  for (int y = 0; y < roi.roiH; y++) {
    final gy = roi.roiY + y;
    final rRow = y * roi.roiW;
    final gRow = gy * w;
    for (int x = 0; x < roi.roiW; x++) {
      final ri = rRow + x;
      final mark = roi.scribbleMask[ri];
      if (mark != 0) continue;

      final d = roi.hasShow ? roi.distShow[ri] : roi.distHide[ri];
      if (d < 2.0 || d > 16.0) continue;

      final gx = roi.roiX + x;
      final gPixel = gRow + gx;
      final idx = gPixel << 2;
      if (work[idx + 3] > 15) continue;
      if (hasGlobalExterior && globalExtMask[gPixel] == 0) continue;

      final r = orig[idx], g = orig[idx + 1], b = orig[idx + 2];
      _addDiverseColor(localBgPalette, r, g, b, maxColors: 40, minDist: 6.0);

      // Measure local background noise gradient among transparent background neighbors
      double maxNbGrad = 0.0;
      if (gx > 0 && work[idx - 1] <= 15) {
        final dNb = _perceptualDist(r, g, b, orig[idx - 4], orig[idx - 3], orig[idx - 2]);
        if (dNb > maxNbGrad) maxNbGrad = dNb;
      }
      if (gx + 1 < w && work[idx + 7] <= 15) {
        final dNb = _perceptualDist(r, g, b, orig[idx + 4], orig[idx + 5], orig[idx + 6]);
        if (dNb > maxNbGrad) maxNbGrad = dNb;
      }
      if (gy > 0) {
        final uIdx = ((gy - 1) * w + gx) << 2;
        if (work[uIdx + 3] <= 15) {
          final dNb = _perceptualDist(r, g, b, orig[uIdx], orig[uIdx + 1], orig[uIdx + 2]);
          if (dNb > maxNbGrad) maxNbGrad = dNb;
        }
      }
      if (gy + 1 < h) {
        final dIdx = ((gy + 1) * w + gx) << 2;
        if (work[dIdx + 3] <= 15) {
          final dNb = _perceptualDist(r, g, b, orig[dIdx], orig[dIdx + 1], orig[dIdx + 2]);
          if (dNb > maxNbGrad) maxNbGrad = dNb;
        }
      }
      gradSamples.add(maxNbGrad);
    }
  }

  double localGrad = 0.0;
  if (gradSamples.isNotEmpty) {
    gradSamples.sort();
    // 80th percentile resists stray outline pixels while capturing compression noise
    localGrad = gradSamples[((gradSamples.length - 1) * 0.80).round()];
  }
  final double bgTol = (localGrad + 4.5).clamp(5.0, 14.0);
  final double bgTolSq = bgTol * bgTol;
  const double stepRuleSq = 5.5 * 5.5;

  // ── 2. 3-Rule Exterior Background Flood (`extBgReach`) ──
  final extBgReach = Uint8List(roiTotal);
  final queue = Int32List(roiTotal);
  int qHead = 0;
  int qTail = 0;

  for (int y = 0; y < roi.roiH; y++) {
    final gy = roi.roiY + y;
    final rRow = y * roi.roiW;
    final gRow = gy * w;
    for (int x = 0; x < roi.roiW; x++) {
      final ri = rRow + x;
      final gx = roi.roiX + x;
      if (isExteriorSeed(gx, gy, ri, gRow + gx)) {
        extBgReach[ri] = 1;
        queue[qTail++] = ri;
      }
    }
  }

  bool matchesLocalBg(int idx) {
    if (localBgPalette.isEmpty) return false;
    final r = orig[idx], g = orig[idx + 1], b = orig[idx + 2];
    for (int i = 0; i < localBgPalette.length; i += 3) {
      if (_perceptualDistSq(localBgPalette[i], localBgPalette[i + 1], localBgPalette[i + 2], r, g, b) <=
          bgTolSq) {
        return true;
      }
    }
    return false;
  }

  const dx4 = [-1, 1, 0, 0];
  const dy4 = [0, 0, -1, 1];

  while (qHead < qTail) {
    final curr = queue[qHead++];
    final cx = curr % roi.roiW;
    final cy = curr ~/ roi.roiW;
    final cIdx = ((roi.roiY + cy) * w + (roi.roiX + cx)) << 2;
    final cR = orig[cIdx], cG = orig[cIdx + 1], cB = orig[cIdx + 2];

    for (int k = 0; k < 4; k++) {
      final nx = cx + dx4[k];
      final ny = cy + dy4[k];
      if (nx < 0 || nx >= roi.roiW || ny < 0 || ny >= roi.roiH) continue;
      final ni = ny * roi.roiW + nx;
      if (extBgReach[ni] == 1) continue;

      final nMark = roi.scribbleMask[ni];
      final nIdx = ((roi.roiY + ny) * w + (roi.roiX + nx)) << 2;

      // Rule 1: Existing opaque foreground blocks the flood completely
      if (nMark != 2 && work[nIdx + 3] > 32) continue;

      // Rule 2: Any color outline / pastel boundary blocks the flood
      final stepSq = _perceptualDistSq(cR, cG, cB, orig[nIdx], orig[nIdx + 1], orig[nIdx + 2]);
      if (stepSq > stepRuleSq) continue;

      // Rule 3: Neighbor must stay within adaptive local background tolerance
      if (!matchesLocalBg(nIdx)) continue;

      extBgReach[ni] = 1;
      queue[qTail++] = ni;
    }
  }

  // Fallback for deliberate strokes drawn entirely inside a uniform region
  if (roi.hasShow) {
    int showCount = 0;
    int showReached = 0;
    for (int i = 0; i < roiTotal; i++) {
      if (roi.scribbleMask[i] == 1) {
        showCount++;
        if (extBgReach[i] == 1) showReached++;
      }
    }
    if (showCount > 0 && (showReached / showCount) > 0.92) {
      for (int i = 0; i < roiTotal; i++) {
        if (roi.showCoreMask[i] == 1) {
          extBgReach[i] = 0;
        }
      }
    }
  }

  // ── 3. Geodesic Propagation Outside Show Spine & Connected Hide Flood ──
  final showRestoreLevel = Float32List(roiTotal); // 0.0 .. 1.0
  if (roi.hasShow) {
    qHead = 0;
    qTail = 0;
    final seedColors = Int32List(roiTotal * 3); // anchor orig color per propagated pixel

    for (int ri = 0; ri < roiTotal; ri++) {
      if (roi.scribbleMask[ri] == 1 && extBgReach[ri] == 0) {
        final cx = ri % roi.roiW;
        final cy = ri ~/ roi.roiW;
        final cIdx = ((roi.roiY + cy) * w + (roi.roiX + cx)) << 2;

        // Smooth 1-2px ramp only where this foreground pixel directly touches exterior background
        bool touchesExtBg = false;
        for (int k = 0; k < 4; k++) {
          final nx = cx + dx4[k];
          final ny = cy + dy4[k];
          if (nx >= 0 && nx < roi.roiW && ny >= 0 && ny < roi.roiH) {
            if (extBgReach[ny * roi.roiW + nx] == 1) {
              touchesExtBg = true;
              break;
            }
          }
        }

        double alphaVal = 1.0;
        if (touchesExtBg && localBgPalette.isNotEmpty) {
          final (dBg, _, _, _) =
              _nearestPaletteColor(localBgPalette, orig[cIdx], orig[cIdx + 1], orig[cIdx + 2]);
          if (dBg < bgTol * 1.6) {
            alphaVal = ((dBg - bgTol * 0.65) / (bgTol * 0.95)).clamp(0.25, 1.0);
          }
        }

        showRestoreLevel[ri] = alphaVal;
        if (alphaVal >= 0.65) {
          queue[qTail++] = ri;
          final sBase = ri * 3;
          seedColors[sBase] = orig[cIdx];
          seedColors[sBase + 1] = orig[cIdx + 1];
          seedColors[sBase + 2] = orig[cIdx + 2];
        }
      }
    }

    const int propStepSq = 144; // stepDist <= 12.0
    const int propAnchorSq = 1024; // color stays within 32.0 of border seed

    while (qHead < qTail) {
      final curr = queue[qHead++];
      final cx = curr % roi.roiW;
      final cy = curr ~/ roi.roiW;
      final cIdx = ((roi.roiY + cy) * w + (roi.roiX + cx)) << 2;
      final cR = orig[cIdx], cG = orig[cIdx + 1], cB = orig[cIdx + 2];
      final cSeedBase = curr * 3;
      final aR = seedColors[cSeedBase];
      final aG = seedColors[cSeedBase + 1];
      final aB = seedColors[cSeedBase + 2];

      for (int k = 0; k < 4; k++) {
        final nx = cx + dx4[k];
        final ny = cy + dy4[k];
        if (nx < 0 || nx >= roi.roiW || ny < 0 || ny >= roi.roiH) continue;
        final ni = ny * roi.roiW + nx;
        if (showRestoreLevel[ni] > 0.0) continue;
        if (roi.scribbleMask[ni] == 2 || extBgReach[ni] == 1) continue;

        final dS = roi.distShow[ni];
        if (dS <= 0.0 || dS > roi.margin) continue;
        if (roi.hasHide && roi.distHide[ni] < dS) continue;

        final nIdx = ((roi.roiY + ny) * w + (roi.roiX + nx)) << 2;
        if (work[nIdx + 3] >= 245) continue;

        final nR = orig[nIdx], nG = orig[nIdx + 1], nB = orig[nIdx + 2];
        if (_perceptualDistSq(cR, cG, cB, nR, nG, nB) > propStepSq) continue;
        if (_perceptualDistSq(aR, aG, aB, nR, nG, nB) > propAnchorSq) continue;

        final distRatio = dS / roi.margin;
        final fade = distRatio <= 0.45
            ? 1.0
            : (1.0 - ((distRatio - 0.45) / 0.55)).clamp(0.0, 1.0);
        if (fade <= 0.02) continue;

        showRestoreLevel[ni] = fade;
        final nSeedBase = ni * 3;
        seedColors[nSeedBase] = aR;
        seedColors[nSeedBase + 1] = aG;
        seedColors[nSeedBase + 2] = aB;
        queue[qTail++] = ni;
      }
    }
  }

  // Connected Hide Flood from Red stroke spine
  final hideEraseMask = Uint8List(roiTotal); // 1 = matched hide flood, 2 = unconditional spine
  if (roi.hasHide) {
    final hidePalette = <int>[];
    qHead = 0;
    qTail = 0;

    for (int y = 0; y < roi.roiH; y++) {
      final gy = roi.roiY + y;
      final rRow = y * roi.roiW;
      final gRow = gy * w;
      for (int x = 0; x < roi.roiW; x++) {
        final ri = rRow + x;
        if (roi.hideCoreMask[ri] == 1) {
          hideEraseMask[ri] = 2;
          queue[qTail++] = ri;
          final idx = (gRow + roi.roiX + x) << 2;
          _addDiverseColor(
            hidePalette,
            orig[idx],
            orig[idx + 1],
            orig[idx + 2],
            maxColors: 36,
            minDist: 10.0,
          );
        }
      }
    }

    const int hideStepSq = 196; // stepDist <= 14.0
    const int hideEdgeStopSq = 484; // stop hard at stepDist > 22.0
    const int hideColorSq = 676; // match hideColors within 26.0

    bool matchesHidePalette(int r, int g, int b) {
      for (int i = 0; i < hidePalette.length; i += 3) {
        if (_perceptualDistSq(hidePalette[i], hidePalette[i + 1], hidePalette[i + 2], r, g, b) <=
            hideColorSq) {
          return true;
        }
      }
      return false;
    }

    while (qHead < qTail) {
      final curr = queue[qHead++];
      final cx = curr % roi.roiW;
      final cy = curr ~/ roi.roiW;
      final cIdx = ((roi.roiY + cy) * w + (roi.roiX + cx)) << 2;
      final cR = orig[cIdx], cG = orig[cIdx + 1], cB = orig[cIdx + 2];

      for (int k = 0; k < 4; k++) {
        final nx = cx + dx4[k];
        final ny = cy + dy4[k];
        if (nx < 0 || nx >= roi.roiW || ny < 0 || ny >= roi.roiH) continue;
        final ni = ny * roi.roiW + nx;
        if (hideEraseMask[ni] != 0) continue;
        if (roi.scribbleMask[ni] == 1) continue;

        final dH = roi.distHide[ni];
        if (dH > roi.margin) continue;
        if (roi.hasShow && roi.distShow[ni] < dH) continue;

        final nIdx = ((roi.roiY + ny) * w + (roi.roiX + nx)) << 2;
        final nR = orig[nIdx], nG = orig[nIdx + 1], nB = orig[nIdx + 2];
        final stepSq = _perceptualDistSq(cR, cG, cB, nR, nG, nB);
        if (stepSq > hideEdgeStopSq || stepSq > hideStepSq) continue;
        if (!matchesHidePalette(nR, nG, nB)) continue;

        hideEraseMask[ni] = 1;
        queue[qTail++] = ni;
      }
    }
  }

  // ── 4. Compose Final Premultiplied Output Alpha & Color Decontamination ──
  for (int y = 0; y < roi.roiH; y++) {
    final gy = roi.roiY + y;
    final rRow = y * roi.roiW;
    final gRow = gy * w;

    for (int x = 0; x < roi.roiW; x++) {
      final ri = rRow + x;
      final mark = roi.scribbleMask[ri];
      final idx = (gRow + roi.roiX + x) << 2;
      final oldAlpha = out[idx + 3];

      int newAlpha = oldAlpha;

      if (mark == 2 || (roi.hasHide && mark != 1 && (!roi.hasShow || roi.distHide[ri] < roi.distShow[ri]))) {
        // Hide Zone: strictly reduces alpha
        if (hideEraseMask[ri] == 2) {
          newAlpha = 0;
        } else if (hideEraseMask[ri] == 1) {
          if (mark == 2) {
            newAlpha = 0;
          } else {
            final dH = roi.distHide[ri];
            final distRatio = (dH / roi.margin).clamp(0.0, 1.0);
            final eraseStrength = distRatio <= 0.45
                ? 1.0
                : (1.0 - ((distRatio - 0.45) / 0.55)).clamp(0.0, 1.0);
            final target = (oldAlpha * (1.0 - eraseStrength)).round().clamp(0, 255);
            newAlpha = math.min(oldAlpha, target);
          }
        } else if (mark == 2 && roi.hideCoreMask[ri] == 1) {
          newAlpha = 0;
        }
      } else if (roi.hasShow) {
        // Show Zone: strictly increases visibility without erasing intact foreground
        if (mark == 1) {
          if (extBgReach[ri] == 1) {
            // Exterior background gap under wide brush stays transparent
            continue;
          }
          final targetA = (showRestoreLevel[ri] * 255.0).round().clamp(0, 255);
          newAlpha = math.max(oldAlpha, targetA);
        } else if (showRestoreLevel[ri] > 0.0 && extBgReach[ri] == 0) {
          final targetA = (showRestoreLevel[ri] * 255.0).round().clamp(0, 255);
          newAlpha = math.max(oldAlpha, targetA);
        }
      }

      if (newAlpha != oldAlpha) {
        int r = orig[idx];
        int g = orig[idx + 1];
        int b = orig[idx + 2];

        // Gentle boundary color decontamination against local background on soft edges
        if (newAlpha > 20 && newAlpha < 235 && localBgPalette.isNotEmpty && newAlpha > oldAlpha) {
          final aNorm = newAlpha / 255.0;
          final (dBg, bR, bG, bB) = _nearestPaletteColor(localBgPalette, r, g, b);
          if (dBg > bgTol * 1.4 && aNorm >= 0.28) {
            final deR = ((r - bR * (1.0 - aNorm)) / aNorm).round().clamp(0, 255);
            final deG = ((g - bG * (1.0 - aNorm)) / aNorm).round().clamp(0, 255);
            final deB = ((b - bB * (1.0 - aNorm)) / aNorm).round().clamp(0, 255);
            r = ((r * 0.45) + (deR * 0.55)).round().clamp(0, 255);
            g = ((g * 0.45) + (deG * 0.55)).round().clamp(0, 255);
            b = ((b * 0.45) + (deB * 0.55)).round().clamp(0, 255);
          }
        }

        out[idx] = (r * newAlpha) ~/ 255;
        out[idx + 1] = (g * newAlpha) ~/ 255;
        out[idx + 2] = (b * newAlpha) ~/ 255;
        out[idx + 3] = newAlpha;
      }
    }
  }

  return out;
}

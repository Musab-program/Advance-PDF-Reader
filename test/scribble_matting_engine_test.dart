import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/modules/background_remover/services/scribble_matting_engine.dart';

void main() {
  group('ScribbleMattingEngine.solveLocalMatte', () {
    test(
      'restores enclosed white PDF card interior and pastel star while keeping exterior white gap transparent',
      () async {
        const int w = 200;
        const int h = 160;
        final orig = Uint8List(w * h * 4);
        final work = Uint8List(w * h * 4);

        void setPx(Uint8List buf, int x, int y, int r, int g, int b, int a) {
          final idx = (y * w + x) << 2;
          buf[idx] = (r * a) ~/ 255;
          buf[idx + 1] = (g * a) ~/ 255;
          buf[idx + 2] = (b * a) ~/ 255;
          buf[idx + 3] = a;
        }

        // Fill canvas with pure white exterior background (orig opaque white, work erased alpha=0)
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            setPx(orig, x, y, 255, 255, 255, 255);
            setPx(work, x, y, 0, 0, 0, 0);
          }
        }

        // Draw enclosed PDF card (x: 30..90, y: 30..130) with 3px purple border (#6C2BD9)
        // Border is intact (alpha=255 in work), while white card interior was mistakenly erased (alpha=0 in work).
        for (int y = 30; y <= 130; y++) {
          for (int x = 30; x <= 90; x++) {
            final isBorder = x < 33 || x > 87 || y < 33 || y > 127;
            if (isBorder) {
              setPx(orig, x, y, 108, 43, 217, 255);
              setPx(work, x, y, 108, 43, 217, 255);
            }
          }
        }

        // Draw pastel lavender star/badge (242, 235, 252) next to white exterior background (erased in work)
        const int starCx = 132;
        const int starCy = 72;
        const int starR = 14;
        for (int y = starCy - starR; y <= starCy + starR; y++) {
          for (int x = starCx - starR; x <= starCx + starR; x++) {
            final dx = x - starCx;
            final dy = y - starCy;
            if (dx * dx + dy * dy <= starR * starR) {
              setPx(orig, x, y, 242, 235, 252, 255);
            }
          }
        }

        // Broad green Show stroke sweeping across card interior (x=60), purple border (x=89),
        // exterior white gap (x=104), and pastel star (x=132) at y=72 (yNorm = 72 / 159 = 0.4528).
        final strokes = [
          const ScribbleStrokeData(
            normCoords: [
              60 / (w - 1),
              72 / (h - 1),
              132 / (w - 1),
              72 / (h - 1),
            ],
            normRadius: 24 / w,
            isShow: true,
          ),
        ];

        final result = await ScribbleMattingEngine.solveLocalMatte(
          LocalMatteRequest(
            width: w,
            height: h,
            origRgba: orig,
            workRgba: work,
            strokes: strokes,
          ),
        );

        int alphaAt(int x, int y) => result[((y * w + x) << 2) + 3];

        // 1. White interior inside the enclosed purple PDF outline is restored to 255
        expect(alphaAt(60, 72), equals(255));
        expect(alphaAt(50, 72), equals(255));

        // 2. Pastel lavender star (242, 235, 252) next to white background is restored to 255
        expect(alphaAt(132, 72), equals(255));
        expect(alphaAt(126, 72), equals(255));

        // 3. Pure white exterior background gap inside the exact same broad green stroke stays transparent (0)
        expect(alphaAt(104, 72), equals(0));
        expect(alphaAt(104, 65), equals(0));

        // 4. Intact purple card border remains opaque (255)
        expect(alphaAt(89, 72), equals(255));
      },
    );

    test(
      'hide stroke erases connected unwanted area cleanly without crossing strong foreground boundary',
      () async {
        const int w = 160;
        const int h = 120;
        final orig = Uint8List(w * h * 4);
        final work = Uint8List(w * h * 4);

        void setPx(Uint8List buf, int x, int y, int r, int g, int b, int a) {
          final idx = (y * w + x) << 2;
          buf[idx] = (r * a) ~/ 255;
          buf[idx + 1] = (g * a) ~/ 255;
          buf[idx + 2] = (b * a) ~/ 255;
          buf[idx + 3] = a;
        }

        // Left half (x < 80): solid purple foreground object kept by AI (alpha=255)
        // Right half (x >= 80): unwanted gray remnant left by AI (alpha=255 in work)
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            if (x < 80) {
              setPx(orig, x, y, 108, 43, 217, 255);
              setPx(work, x, y, 108, 43, 217, 255);
            } else if (x < 120 && y >= 30 && y <= 90) {
              setPx(orig, x, y, 225, 225, 225, 255);
              setPx(work, x, y, 225, 225, 225, 255);
            } else {
              setPx(orig, x, y, 255, 255, 255, 255);
            }
          }
        }

        // Paint Hide (-) centered in gray remnant at x=98, outer rim overlapping foreground edge near x=76
        final strokes = [
          const ScribbleStrokeData(
            normCoords: [
              98 / (w - 1),
              60 / (h - 1),
              102 / (w - 1),
              60 / (h - 1),
            ],
            normRadius: 24 / w, // reaches down to x ~ 74
            isShow: false,
          ),
        ];

        final result = await ScribbleMattingEngine.solveLocalMatte(
          LocalMatteRequest(
            width: w,
            height: h,
            origRgba: orig,
            workRgba: work,
            strokes: strokes,
          ),
        );

        int alphaAt(int x, int y) => result[((y * w + x) << 2) + 3];

        // Core & connected gray remnant erased to 0
        expect(alphaAt(98, 60), equals(0));
        expect(alphaAt(86, 60), equals(0));

        // Strong purple foreground edge just inside outer rim stays protected (255)
        expect(alphaAt(76, 60), equals(255));
      },
    );
  });
}

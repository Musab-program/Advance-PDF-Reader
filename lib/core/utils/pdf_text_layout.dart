import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// A positioned text fragment in PDF page coordinates (Y increases upward: top >= bottom).
class PositionedTextRun {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const PositionedTextRun({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => math.max(0.0, right - left);
  double get height => math.max(0.0, top - bottom);
  double get centerY => (top + bottom) / 2.0;
}

/// Utilities for normalizing extracted PDF text, reconstructing visual lines/BiDi reading order,
/// and cleanly decoding `.txt` byte streams (UTF-8 BOM, UTF-16, and Windows-1256 Arabic ANSI).
class PdfTextLayout {
  PdfTextLayout._();

  // Arabic Presentation Forms-B (U+FE80..U+FEFC) -> canonical Arabic characters
  static const Map<int, String> _arabicFormBMap = {
    0xFE80: '\u0621', // ء
    0xFE81: '\u0622', 0xFE82: '\u0622', // آ
    0xFE83: '\u0623', 0xFE84: '\u0623', // أ
    0xFE85: '\u0624', 0xFE86: '\u0624', // ؤ
    0xFE87: '\u0625', 0xFE88: '\u0625', // إ
    0xFE89: '\u0626', 0xFE8A: '\u0626', 0xFE8B: '\u0626', 0xFE8C: '\u0626', // ئ
    0xFE8D: '\u0627', 0xFE8E: '\u0627', // ا
    0xFE8F: '\u0628', 0xFE90: '\u0628', 0xFE91: '\u0628', 0xFE92: '\u0628', // ب
    0xFE93: '\u0629', 0xFE94: '\u0629', // ة
    0xFE95: '\u062A', 0xFE96: '\u062A', 0xFE97: '\u062A', 0xFE98: '\u062A', // ت
    0xFE99: '\u062B', 0xFE9A: '\u062B', 0xFE9B: '\u062B', 0xFE9C: '\u062B', // ث
    0xFE9D: '\u062C', 0xFE9E: '\u062C', 0xFE9F: '\u062C', 0xFEA0: '\u062C', // ج
    0xFEA1: '\u062D', 0xFEA2: '\u062D', 0xFEA3: '\u062D', 0xFEA4: '\u062D', // ح
    0xFEA5: '\u062E', 0xFEA6: '\u062E', 0xFEA7: '\u062E', 0xFEA8: '\u062E', // خ
    0xFEA9: '\u062F', 0xFEAA: '\u062F', // د
    0xFEAB: '\u0630', 0xFEAC: '\u0630', // ذ
    0xFEAD: '\u0631', 0xFEAE: '\u0631', // ر
    0xFEAF: '\u0632', 0xFEB0: '\u0632', // ز
    0xFEB1: '\u0633', 0xFEB2: '\u0633', 0xFEB3: '\u0633', 0xFEB4: '\u0633', // س
    0xFEB5: '\u0634', 0xFEB6: '\u0634', 0xFEB7: '\u0634', 0xFEB8: '\u0634', // ش
    0xFEB9: '\u0635', 0xFEBA: '\u0635', 0xFEBB: '\u0635', 0xFEBC: '\u0635', // ص
    0xFEBD: '\u0636', 0xFEBE: '\u0636', 0xFEBF: '\u0636', 0xFEC0: '\u0636', // ض
    0xFEC1: '\u0637', 0xFEC2: '\u0637', 0xFEC3: '\u0637', 0xFEC4: '\u0637', // ط
    0xFEC5: '\u0638', 0xFEC6: '\u0638', 0xFEC7: '\u0638', 0xFEC8: '\u0638', // ظ
    0xFEC9: '\u0639', 0xFECA: '\u0639', 0xFECB: '\u0639', 0xFECC: '\u0639', // ع
    0xFECD: '\u063A', 0xFECE: '\u063A', 0xFECF: '\u063A', 0xFED0: '\u063A', // غ
    0xFED1: '\u0641', 0xFED2: '\u0641', 0xFED3: '\u0641', 0xFED4: '\u0641', // ف
    0xFED5: '\u0642', 0xFED6: '\u0642', 0xFED7: '\u0642', 0xFED8: '\u0642', // ق
    0xFED9: '\u0643', 0xFEDA: '\u0643', 0xFEDB: '\u0643', 0xFEDC: '\u0643', // ك
    0xFEDD: '\u0644', 0xFEDE: '\u0644', 0xFEDF: '\u0644', 0xFEE0: '\u0644', // ل
    0xFEE1: '\u0645', 0xFEE2: '\u0645', 0xFEE3: '\u0645', 0xFEE4: '\u0645', // م
    0xFEE5: '\u0646', 0xFEE6: '\u0646', 0xFEE7: '\u0646', 0xFEE8: '\u0646', // ن
    0xFEE9: '\u0647', 0xFEEA: '\u0647', 0xFEEB: '\u0647', 0xFEEC: '\u0647', // ه
    0xFEED: '\u0648', 0xFEEE: '\u0648', // و
    0xFEEF: '\u0649', 0xFEF0: '\u0649', // ى
    0xFEF1: '\u064A', 0xFEF2: '\u064A', 0xFEF3: '\u064A', 0xFEF4: '\u064A', // ي
    // Lam-Alef ligatures
    0xFEF5: '\u0644\u0622', 0xFEF6: '\u0644\u0622', // لآ
    0xFEF7: '\u0644\u0623', 0xFEF8: '\u0644\u0623', // لأ
    0xFEF9: '\u0644\u0625', 0xFEFA: '\u0644\u0625', // لإ
    0xFEFB: '\u0644\u0627', 0xFEFC: '\u0644\u0627', // لا
  };

  // Arabic Presentation Forms-B classification sets for detecting reversed visual strings
  static const Set<int> _arabicInitialForms = {
    0xFE8B, 0xFE91, 0xFE97, 0xFE9B, 0xFE9F, 0xFEA3, 0xFEA7,
    0xFEB3, 0xFEB7, 0xFEBB, 0xFEBF, 0xFEC3, 0xFEC7, 0xFECB, 0xFECF,
    0xFED3, 0xFED7, 0xFEDB, 0xFEDF, 0xFEE3, 0xFEE7, 0xFEEB, 0xFEF3,
  };

  static const Set<int> _arabicFinalForms = {
    0xFE82, 0xFE84, 0xFE86, 0xFE88, 0xFE8A, 0xFE8E,
    0xFE90, 0xFE94, 0xFE96, 0xFE9A, 0xFE9E, 0xFEA2, 0xFEA6,
    0xFEAA, 0xFEAC, 0xFEAE, 0xFEB0, 0xFEB2, 0xFEB6, 0xFEBA, 0xFEBE,
    0xFEC2, 0xFEC6, 0xFECA, 0xFECE, 0xFED2, 0xFED6, 0xFEDA, 0xFEDE,
    0xFEE2, 0xFEE6, 0xFEEA, 0xFEEE, 0xFEF0, 0xFEF2,
    0xFEF6, 0xFEF8, 0xFEFA, 0xFEFC,
  };

  static const Set<int> _arabicMedialForms = {
    0xFE8C,
    0xFE92, 0xFE98, 0xFE9C, 0xFEA0, 0xFEA4, 0xFEA8,
    0xFEB4, 0xFEB8, 0xFEBC, 0xFEC0, 0xFEC4, 0xFEC8,
    0xFECC, 0xFED0, 0xFED4, 0xFED8, 0xFEDC, 0xFEE0,
    0xFEE4, 0xFEE8, 0xFEEC, 0xFEF4,
  };

  // Windows-1256 (CP1256) upper byte table 0x80..0xFF
  static const List<int> _cp1256Upper = [
    0x20AC, 0x067E, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0679, 0x2039, 0x0152, 0x0686, 0x0698, 0x0688,
    0x06AF, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x06A9, 0x2122, 0x0691, 0x203A, 0x0153, 0x200C, 0x200D, 0x06BA,
    0x00A0, 0x060C, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7,
    0x00A8, 0x00A9, 0x06BE, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
    0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
    0x00B8, 0x00B9, 0x061B, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x061F,
    0x06C1, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627,
    0x0628, 0x0629, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F,
    0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x00D7,
    0x0637, 0x0638, 0x0639, 0x063A, 0x0640, 0x0641, 0x0642, 0x0643,
    0x00E0, 0x0644, 0x00E2, 0x0645, 0x0646, 0x0647, 0x0648, 0x00E7,
    0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x0649, 0x064A, 0x00EE, 0x00EF,
    0x064B, 0x064C, 0x064D, 0x064E, 0x00F4, 0x064F, 0x0650, 0x00F7,
    0x0651, 0x00F9, 0x0652, 0x00FB, 0x00FC, 0x200E, 0x200F, 0x06D2,
  ];

  static bool isRtlChar(int rune) =>
      (rune >= 0x0600 && rune <= 0x06FF) ||
      (rune >= 0x0750 && rune <= 0x077F) ||
      (rune >= 0x08A0 && rune <= 0x08FF) ||
      (rune >= 0xFB50 && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFF) ||
      (rune >= 0x0590 && rune <= 0x05FF);

  static bool isLtrChar(int rune) =>
      (rune >= 0x0041 && rune <= 0x005A) ||
      (rune >= 0x0061 && rune <= 0x007A) ||
      (rune >= 0x00C0 && rune <= 0x024F);

  /// Returns `true` when [text] contains more RTL characters than LTR characters (or any RTL when tied).
  static bool isRtlDominantText(String text) {
    int rtl = 0;
    int ltr = 0;
    for (final rune in text.runes) {
      if (isRtlChar(rune)) {
        rtl++;
      } else if (isLtrChar(rune)) {
        ltr++;
      }
    }
    if (rtl == 0 && ltr == 0) return false;
    return rtl >= ltr;
  }

  /// Normalizes Arabic Presentation Forms, corrects visually reversed presentation tokens,
  /// and removes stray invisible bidi markers.
  static String normalizeArabicText(String input) {
    if (input.isEmpty) return '';

    // Remove invisible bidi controls and zero-width spaces first
    final cleaned = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0xFEFF ||
          rune == 0x0000 ||
          (rune >= 0x200B && rune <= 0x200F) ||
          (rune >= 0x202A && rune <= 0x202E) ||
          (rune >= 0x2066 && rune <= 0x2069)) {
        continue;
      }
      cleaned.writeCharCode(rune);
    }

    final raw = cleaned.toString();
    if (raw.isEmpty) return '';

    // Process tokens to detect and reverse visually inverted Arabic presentation tokens (e.g. ﺐﻌﺼﻣ -> مصعب)
    final result = StringBuffer();
    final tokenRunes = <int>[];

    void flushToken() {
      if (tokenRunes.isEmpty) return;

      final hasPresForms = tokenRunes.any((r) => _arabicFormBMap.containsKey(r));
      if (hasPresForms && tokenRunes.length >= 2) {
        final firstR = tokenRunes.first;
        final lastR = tokenRunes.last;
        final startsWithFinalOrMedial =
            _arabicFinalForms.contains(firstR) || _arabicMedialForms.contains(firstR);
        final endsWithInitial =
            _arabicInitialForms.contains(lastR) || _arabicMedialForms.contains(lastR);

        if (startsWithFinalOrMedial || endsWithInitial) {
          final reversed = tokenRunes.reversed.toList();
          tokenRunes
            ..clear()
            ..addAll(reversed);
        }
      }

      for (final r in tokenRunes) {
        final mapped = _arabicFormBMap[r];
        if (mapped != null) {
          result.write(mapped);
        } else {
          result.writeCharCode(r);
        }
      }
      tokenRunes.clear();
    }

    for (final rune in raw.runes) {
      if (rune == 0x0020 ||
          rune == 0x0009 ||
          rune == 0x000A ||
          rune == 0x000D ||
          rune == 0x00A0 ||
          (rune >= 0x2000 && rune <= 0x200A) ||
          rune == 0x060C ||
          rune == 0x061B ||
          rune == 0x061F ||
          rune == 0x002C ||
          rune == 0x002E ||
          rune == 0x003A ||
          rune == 0x003B ||
          rune == 0x0028 || rune == 0x0029 ||
          rune == 0x005B || rune == 0x005D ||
          rune == 0x007B || rune == 0x007D) {
        flushToken();
        result.writeCharCode(rune);
      } else {
        tokenRunes.add(rune);
      }
    }
    flushToken();

    return result.toString();
  }

  /// Decodes raw file bytes cleanly from UTF-8 (with or without BOM), UTF-16 LE/BE, Windows-1256, or Latin-1.
  static String decodeTextBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    String decoded;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      decoded = utf8.decode(bytes.sublist(3), allowMalformed: true);
    } else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      decoded = _decodeUtf16(bytes.sublist(2), littleEndian: true);
    } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      decoded = _decodeUtf16(bytes.sublist(2), littleEndian: false);
    } else {
      try {
        decoded = utf8.decode(bytes);
      } catch (_) {
        int cp1256Hits = 0;
        for (final b in bytes) {
          if (b >= 0xC1 && b <= 0xFA) cp1256Hits++;
        }
        decoded = cp1256Hits > 0 ? decodeWindows1256(bytes) : latin1.decode(bytes);
      }
    }

    return normalizeArabicText(decoded)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{4,}'), '\n\n\n')
        .trim();
  }

  static String decodeWindows1256(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else {
        sb.writeCharCode(_cp1256Upper[b - 0x80]);
      }
    }
    return sb.toString();
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final codeUnits = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final cu = littleEndian
          ? (bytes[i] | (bytes[i + 1] << 8))
          : ((bytes[i] << 8) | bytes[i + 1]);
      codeUnits.add(cu);
    }
    return String.fromCharCodes(codeUnits);
  }

  /// Extracts clean readable lines from a `pdfrx` page using its structured fragment geometry.
  static Future<String> extractPageText(pdfrx.PdfPage page) async {
    final structured = await page.loadStructuredText();
    if (structured.fragments.isEmpty) {
      return normalizeArabicText(structured.fullText).trim();
    }

    final runs = <PositionedTextRun>[];
    for (final frag in structured.fragments) {
      String fragText = frag.text;
      // If the fragment contains RTL characters and glyphs were physically drawn Left-to-Right in PDF coords
      if (frag.length >= 2 && isRtlDominantText(fragText)) {
        if (frag.charRects.length >= 2) {
          final firstChar = frag.charRects.first;
          final lastChar = frag.charRects.last;
          if (firstChar.left < lastChar.left - 2.0) {
            fragText = fragText.runes.toList().reversed.map((r) => String.fromCharCode(r)).join();
          }
        }
      }

      final raw = normalizeArabicText(fragText).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (raw.isEmpty) continue;
      runs.add(PositionedTextRun(
        text: raw,
        left: frag.bounds.left,
        top: frag.bounds.top,
        right: frag.bounds.right,
        bottom: frag.bounds.bottom,
      ));
    }

    if (runs.isEmpty) {
      return normalizeArabicText(structured.fullText).trim();
    }
    return reconstructReadableLines(runs);
  }

  /// Groups positioned fragments into top-to-bottom visual lines and orders each line
  /// with proper BiDi reading order (RTL vs LTR + intact embedded inline runs).
  static String reconstructReadableLines(List<PositionedTextRun> inputRuns) {
    if (inputRuns.isEmpty) return '';

    final cleaned = <PositionedTextRun>[];
    for (final r in inputRuns) {
      final text = normalizeArabicText(r.text).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      cleaned.add(PositionedTextRun(
        text: text,
        left: math.min(r.left, r.right),
        top: math.max(r.top, r.bottom),
        right: math.max(r.left, r.right),
        bottom: math.min(r.top, r.bottom),
      ));
    }
    if (cleaned.isEmpty) return '';

    // Sort top-to-bottom (higher Y = closer to top of PDF page)
    cleaned.sort((a, b) => b.centerY.compareTo(a.centerY));

    final lines = <List<PositionedTextRun>>[];
    final lineCenters = <double>[];
    final lineHeights = <double>[];

    for (final run in cleaned) {
      final h = math.max(run.height, 8.0);
      int matchIdx = -1;
      double bestDist = double.infinity;

      for (int i = 0; i < lines.length; i++) {
        final avgH = lineHeights[i];
        final avgC = lineCenters[i];
        final tol = math.max(avgH, h) * 0.48;
        final dist = (run.centerY - avgC).abs();
        if (dist <= tol && dist < bestDist) {
          bestDist = dist;
          matchIdx = i;
        }
      }

      if (matchIdx == -1) {
        lines.add([run]);
        lineCenters.add(run.centerY);
        lineHeights.add(h);
      } else {
        final group = lines[matchIdx]..add(run);
        lineCenters[matchIdx] =
            group.fold<double>(0, (sum, e) => sum + e.centerY) / group.length;
        lineHeights[matchIdx] =
            group.fold<double>(0, (sum, e) => sum + math.max(e.height, 8.0)) / group.length;
      }
    }

    // Re-sort lines top-to-bottom cleanly
    final order = List<int>.generate(lines.length, (i) => i)
      ..sort((a, b) => lineCenters[b].compareTo(lineCenters[a]));

    final avgPageLineH = lineHeights.isEmpty
        ? 12.0
        : lineHeights.reduce((a, b) => a + b) / lineHeights.length;

    final out = StringBuffer();
    double? prevBottom;
    for (final idx in order) {
      final lineRuns = lines[idx];
      final lineTop = lineRuns.map((e) => e.top).reduce(math.max);
      final lineBottom = lineRuns.map((e) => e.bottom).reduce(math.min);

      if (prevBottom != null) {
        final verticalGap = prevBottom - lineTop;
        if (verticalGap > avgPageLineH * 0.9) {
          out.writeln();
        }
      }

      final lineText = _orderRunsInLine(lineRuns, lineHeights[idx]);
      if (lineText.isNotEmpty) {
        out.writeln(lineText);
      }
      prevBottom = lineBottom;
    }

    return out.toString().trim();
  }

  static String _orderRunsInLine(List<PositionedTextRun> runs, double lineHeight) {
    if (runs.isEmpty) return '';
    if (runs.length == 1) return runs.first.text;

    int rtlChars = 0;
    int ltrChars = 0;
    for (final r in runs) {
      for (final rune in r.text.runes) {
        if (isRtlChar(rune)) {
          rtlChars++;
        } else if (isLtrChar(rune)) {
          ltrChars++;
        }
      }
    }
    final lineIsRtl = rtlChars > 0 && rtlChars >= ltrChars;

    if (!lineIsRtl) {
      // Primarily LTR: sort visually left-to-right, reversing consecutive RTL runs
      final sorted = List<PositionedTextRun>.from(runs)
        ..sort((a, b) => a.left.compareTo(b.left));
      return _assembleWithEmbeddedDirection(
        sorted,
        primaryRtl: false,
        lineHeight: lineHeight,
      );
    }

    // Primarily RTL: walk visually right-to-left, keeping contiguous LTR runs in left-to-right order
    final sorted = List<PositionedTextRun>.from(runs)
      ..sort((a, b) => b.right.compareTo(a.right));
    return _assembleWithEmbeddedDirection(
      sorted,
      primaryRtl: true,
      lineHeight: lineHeight,
    );
  }

  static int _runDirection(PositionedTextRun run) {
    int rtl = 0;
    int ltr = 0;
    for (final rune in run.text.runes) {
      if (isRtlChar(rune)) {
        rtl++;
      } else if (isLtrChar(rune)) {
        ltr++;
      }
    }
    if (rtl == 0 && ltr == 0) return 0; // Neutral (numbers / punctuation)
    return rtl >= ltr ? 1 : -1;
  }

  static String _assembleWithEmbeddedDirection(
    List<PositionedTextRun> ordered, {
    required bool primaryRtl,
    required double lineHeight,
  }) {
    final targetOpp = primaryRtl ? -1 : 1;
    final parts = <PositionedTextRun>[];
    int i = 0;

    while (i < ordered.length) {
      final dir = _runDirection(ordered[i]);
      if (dir == targetOpp) {
        final oppositeStreak = <PositionedTextRun>[ordered[i]];
        int j = i + 1;
        while (j < ordered.length) {
          final nextDir = _runDirection(ordered[j]);
          if (nextDir == targetOpp) {
            oppositeStreak.add(ordered[j]);
            j++;
          } else if (nextDir == 0 &&
              j + 1 < ordered.length &&
              _runDirection(ordered[j + 1]) == targetOpp) {
            oppositeStreak.add(ordered[j]);
            j++;
          } else {
            break;
          }
        }
        // Reverse visual opposite streak into its natural reading order
        if (primaryRtl) {
          oppositeStreak.sort((a, b) => a.left.compareTo(b.left));
        } else {
          oppositeStreak.sort((a, b) => b.right.compareTo(a.right));
        }
        parts.add(PositionedTextRun(
          text: oppositeStreak.map((e) => e.text).join(' '),
          left: oppositeStreak.map((e) => e.left).reduce(math.min),
          top: oppositeStreak.map((e) => e.top).reduce(math.max),
          right: oppositeStreak.map((e) => e.right).reduce(math.max),
          bottom: oppositeStreak.map((e) => e.bottom).reduce(math.min),
        ));
        i = j;
      } else {
        parts.add(ordered[i]);
        i++;
      }
    }

    final sb = StringBuffer();
    for (int k = 0; k < parts.length; k++) {
      if (k > 0) {
        final prev = parts[k - 1];
        final curr = parts[k];
        final gap = primaryRtl ? (prev.left - curr.right) : (curr.left - prev.right);
        sb.write(gap > lineHeight * 2.5 ? '   ' : ' ');
      }
      sb.write(parts[k].text);
    }
    return sb.toString();
  }
}

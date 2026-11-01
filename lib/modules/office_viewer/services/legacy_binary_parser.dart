import 'dart:convert';
import 'dart:typed_data';

/// Extracts structured human-readable content from legacy binary Microsoft Office
/// (`DOC`, `XLS`, `PPT`) and Kingsoft WPS (`WPS`, `ET`, `DPS`) OLE2 streams,
/// as well as Rich Text Format (`RTF`) files.
class LegacyBinaryParser {
  static String parseToHtml(Uint8List bytes, String fileName, String formatType, {bool isDark = false}) {
    final isRtf = bytes.length > 5 &&
        String.fromCharCodes(bytes.sublist(0, 5)).startsWith(r'{\rtf');

    final paragraphs = isRtf
        ? _extractRtfParagraphs(bytes)
        : _extractOle2Paragraphs(bytes);

    final sb = StringBuffer();
    sb.writeln('''
<!DOCTYPE html>
<html dir="auto">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=0.25, maximum-scale=5.0, user-scalable=yes">
  <style>
    :root {
      --bg-canvas: #eef2f6;
      --bg-page: #ffffff;
      --text-main: #0f172a;
      --text-muted: #64748b;
      --border-col: #cbd5e1;
      --accent-col: #2b579a;
    }
    body.dark-theme {
      --bg-canvas: #0b111b;
      --bg-page: #151f2e;
      --text-main: #e2e8f0;
      --text-muted: #94a3b8;
      --border-col: #334155;
      --accent-col: #60a5fa;
    }
    * { box-sizing: border-box; }
    html, body {
      font-family: "Calibri", "Segoe UI", "Traditional Arabic", "Cairo", Roboto, sans-serif;
      margin: 0;
      padding: 0;
      color: var(--text-main);
      background-color: var(--bg-canvas);
      line-height: 1.7;
    }
    .workspace {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 12px 48px 12px;
    }
    .page-sheet {
      width: 794px;
      max-width: 100%;
      min-height: 90vh;
      background: var(--bg-page);
      padding: 40px 44px;
      box-shadow: 0 8px 28px rgba(15, 23, 42, 0.12);
      border: 1px solid var(--border-col);
      border-radius: 6px;
    }
    body.reflow-mode .workspace { padding: 0; }
    body.reflow-mode .page-sheet {
      width: 100% !important;
      padding: 20px 18px 40px 18px !important;
      border: none;
      border-radius: 0;
      box-shadow: none;
    }
    .doc-badge {
      display: inline-block;
      font-size: 11px;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border-col);
      padding-bottom: 8px;
      margin-bottom: 18px;
      width: 100%;
    }
    p {
      margin: 8px 0;
      font-size: 12pt;
      word-wrap: break-word;
    }
  </style>
  <script>
    function setDocZoom(scale) { document.body.style.zoom = scale; }
    function setReflowMode(enableReflow) {
      if (enableReflow) document.body.classList.add('reflow-mode');
      else document.body.classList.remove('reflow-mode');
    }
    function highlightQuery(query) {
      if (window.find && query && query.length > 0) {
        window.find(query, false, false, true, false, false, false);
      }
    }
  </script>
</head>
<body class="${isDark ? 'dark-theme' : ''}">
  <div class="workspace">
    <div class="page-sheet">
      <div class="doc-badge">${const HtmlEscape().convert(fileName)} ($formatType)</div>
''');

    if (paragraphs.isEmpty) {
      sb.writeln('<p>لم يتم العثور على نصوص قابلة للعرض داخل هذا المستند الثنائي.</p>');
    } else {
      for (final p in paragraphs) {
        sb.writeln('<p>${const HtmlEscape().convert(p)}</p>');
      }
    }

    sb.writeln('''
    </div>
  </div>
</body>
</html>
''');
    return sb.toString();
  }

  static List<String> _extractRtfParagraphs(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final cleaned = raw
        .replaceAll(RegExp(r'\\par\b'), '\n')
        .replaceAll(RegExp(r'\\line\b'), '\n')
        .replaceAll(RegExp(r'\\tab\b'), '    ')
        .replaceAll(RegExp(r"\\'[0-9a-fA-F]{2}"), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d*\s?'), '')
        .replaceAll(RegExp(r'[{}]'), '');
    return cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 1)
        .toList();
  }

  /// Scans OLE2 binary streams for both UTF-16LE (used by Word/Excel/PPT for Arabic & Unicode)
  /// and UTF-8 / ASCII text runs, filtering out binary metadata noise.
  static List<String> _extractOle2Paragraphs(Uint8List bytes) {
    final results = <String>[];

    // 1. Scan for UTF-16LE sequences (very common in MS Office 97-2003 for Arabic & English)
    final utf16Sb = StringBuffer();
    int i = 0;
    while (i + 1 < bytes.length) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      final codeUnit = lo | (hi << 8);

      final isAsciiPrintable = hi == 0 && (lo >= 32 && lo <= 126);
      final isArabicUnicode = codeUnit >= 0x0600 && codeUnit <= 0x06FF;
      final isNewline = hi == 0 && (lo == 10 || lo == 13);

      if (isAsciiPrintable || isArabicUnicode) {
        utf16Sb.writeCharCode(codeUnit);
        i += 2;
      } else if (isNewline && utf16Sb.length >= 4) {
        final line = utf16Sb.toString().trim();
        if (_isValidHumanLine(line)) results.add(line);
        utf16Sb.clear();
        i += 2;
      } else {
        if (utf16Sb.length >= 6) {
          final line = utf16Sb.toString().trim();
          if (_isValidHumanLine(line)) results.add(line);
        }
        utf16Sb.clear();
        i++;
      }
    }
    if (utf16Sb.length >= 6) {
      final line = utf16Sb.toString().trim();
      if (_isValidHumanLine(line)) results.add(line);
    }

    // 2. If UTF-16LE yielded very few lines, scan single-byte ASCII/UTF-8 runs
    if (results.length < 3) {
      final currentWord = <int>[];
      final sb = StringBuffer();
      for (int j = 0; j < bytes.length; j++) {
        final b = bytes[j];
        if ((b >= 32 && b <= 126) || b >= 160) {
          currentWord.add(b);
        } else if (b == 10 || b == 13) {
          if (currentWord.length >= 4) {
            sb.write(utf8.decode(currentWord, allowMalformed: true));
            final line = sb.toString().trim();
            if (_isValidHumanLine(line)) results.add(line);
            sb.clear();
          }
          currentWord.clear();
        } else {
          if (currentWord.length >= 5) {
            final decoded = utf8.decode(currentWord, allowMalformed: true).trim();
            if (_isValidHumanLine(decoded)) results.add(decoded);
          }
          currentWord.clear();
        }
      }
    }

    return results;
  }

  static bool _isValidHumanLine(String s) {
    if (s.length < 4) return false;
    final lower = s.toLowerCase();
    const noiseTokens = [
      'root entry',
      'worddocument',
      'summaryinformation',
      'documentsummaryinformation',
      'compobj',
      'workbook',
      'powerpoint document',
      'normal.dot',
      'microsoft office',
      'times new roman',
      'calibri',
      'arial',
    ];
    for (final token in noiseTokens) {
      if (lower == token || (s.length < 30 && lower.contains(token))) {
        return false;
      }
    }
    return true;
  }
}

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class DocxParser {
  /// Converts a `.docx` / `.dotx` file byte buffer into a rich HTML document
  /// modeled after WPS Office's dual-mode engine (`PageMode` using Twips A4 sheet geometry
  /// vs. `MobileMode` responsive reflow), with full styling, tables, numbering, headers/footers,
  /// and embedded images.
  static String parseToHtml(Uint8List docxBytes, {bool isDark = false}) {
    try {
      final archive = ZipDecoder().decodeBytes(docxBytes);

      // 1. Extract relationships (images & hyperlinks) from word/_rels/document.xml.rels
      final imageMap = <String, String>{};
      final linkMap = <String, String>{};
      final relsFile = archive.findFile('word/_rels/document.xml.rels');
      if (relsFile != null) {
        try {
          final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
          final relsDoc = XmlDocument.parse(relsXml);
          for (final rel in relsDoc.findAllElements('Relationship')) {
            final id = rel.getAttribute('Id');
            final target = rel.getAttribute('Target');
            final type = rel.getAttribute('Type') ?? '';
            if (id == null || target == null) continue;

            if (type.contains('image')) {
              final cleanTarget = target.startsWith('/')
                  ? target.substring(1)
                  : (target.startsWith('word/') ? target : 'word/$target');
              ArchiveFile? mediaFile = archive.findFile(cleanTarget);
              mediaFile ??= archive.findFile('word/media/${target.split('/').last}');
              if (mediaFile != null) {
                final mediaBytes = mediaFile.content as List<int>;
                final ext = target.split('.').last.toLowerCase();
                final mime = ext == 'png'
                    ? 'image/png'
                    : (ext == 'jpg' || ext == 'jpeg'
                        ? 'image/jpeg'
                        : (ext == 'gif'
                            ? 'image/gif'
                            : (ext == 'svg' ? 'image/svg+xml' : 'image/png')));
                final base64Str = base64Encode(mediaBytes);
                imageMap[id] = 'data:$mime;base64,$base64Str';
              }
            } else if (type.contains('hyperlink')) {
              linkMap[id] = target;
            }
          }
        } catch (_) {}
      }

      // 2. Parse word/styles.xml for style definitions (Heading sizes, alignments, colors)
      final styleMap = <String, _DocxStyleDef>{};
      final stylesFile = archive.findFile('word/styles.xml');
      if (stylesFile != null) {
        try {
          final stylesXml = utf8.decode(stylesFile.content as List<int>, allowMalformed: true);
          final stylesDoc = XmlDocument.parse(stylesXml);
          for (final s in stylesDoc.findAllElements('w:style')) {
            final styleId = s.getAttribute('w:styleId');
            if (styleId == null) continue;
            final nameVal = s.findElements('w:name').firstOrNull?.getAttribute('w:val')?.toLowerCase() ?? '';
            final pPr = s.findElements('w:pPr').firstOrNull;
            final rPr = s.findElements('w:rPr').firstOrNull;

            double? fontSizePt;
            String? colorHex;
            bool isBold = false;
            bool isItalic = false;
            String? align;

            if (pPr != null) {
              align = pPr.findElements('w:jc').firstOrNull?.getAttribute('w:val');
            }
            if (rPr != null) {
              if (rPr.findElements('w:b').isNotEmpty) isBold = true;
              if (rPr.findElements('w:i').isNotEmpty) isItalic = true;
              colorHex = rPr.findElements('w:color').firstOrNull?.getAttribute('w:val');
              final sz = rPr.findElements('w:sz').firstOrNull?.getAttribute('w:val');
              if (sz != null) {
                final v = double.tryParse(sz);
                if (v != null) fontSizePt = v / 2.0;
              }
            }

            styleMap[styleId] = _DocxStyleDef(
              id: styleId,
              name: nameVal,
              fontSizePt: fontSizePt,
              colorHex: colorHex,
              isBold: isBold,
              isItalic: isItalic,
              align: align,
            );
          }
        } catch (_) {}
      }

      // 3. Parse word/document.xml
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) {
        return '<p style="padding:20px;">الملف غير صالح أو لا يحتوي على محتوى document.xml</p>';
      }

      final docXml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(docXml);
      final body = doc.findAllElements('w:body').firstOrNull;
      if (body == null) {
        return '<p style="padding:20px;">لا يوجد محتوى لعرضه في المستند.</p>';
      }

      // 4. Extract Page Geometry in Twips (1 Twip = 1/20 pt = 1/1440 inch, @96 DPI = 1/15 px)
      // Default A4 in Twips: w = 11906 (794px), h = 16838 (1123px)
      double pageWidthPx = 794;
      double pageMinHeightPx = 1123;
      double marginTopPx = 64;
      double marginBottomPx = 64;
      double marginLeftPx = 68;
      double marginRightPx = 68;

      final sectPr = body.findAllElements('w:sectPr').lastOrNull;
      if (sectPr != null) {
        final pgSz = sectPr.findElements('w:pgSz').firstOrNull;
        if (pgSz != null) {
          final wTwips = double.tryParse(pgSz.getAttribute('w:w') ?? '');
          final hTwips = double.tryParse(pgSz.getAttribute('w:h') ?? '');
          if (wTwips != null && wTwips > 2000) pageWidthPx = (wTwips / 15.0).clamp(480.0, 1400.0);
          if (hTwips != null && hTwips > 2000) pageMinHeightPx = (hTwips / 15.0).clamp(600.0, 2000.0);
        }
        final pgMar = sectPr.findElements('w:pgMar').firstOrNull;
        if (pgMar != null) {
          final topT = double.tryParse(pgMar.getAttribute('w:top') ?? '');
          final botT = double.tryParse(pgMar.getAttribute('w:bottom') ?? '');
          final leftT = double.tryParse(pgMar.getAttribute('w:left') ?? '');
          final rightT = double.tryParse(pgMar.getAttribute('w:right') ?? '');
          if (topT != null) marginTopPx = (topT / 15.0).clamp(24.0, 140.0);
          if (botT != null) marginBottomPx = (botT / 15.0).clamp(24.0, 140.0);
          if (leftT != null) marginLeftPx = (leftT / 15.0).clamp(24.0, 140.0);
          if (rightT != null) marginRightPx = (rightT / 15.0).clamp(24.0, 140.0);
        }
      }

      // 5. Optional Header & Footer extraction
      String headerHtml = '';
      String footerHtml = '';
      for (final file in archive.files) {
        if (file.name.startsWith('word/header') && file.name.endsWith('.xml') && headerHtml.isEmpty) {
          try {
            final hDoc = XmlDocument.parse(utf8.decode(file.content as List<int>, allowMalformed: true));
            final hText = hDoc.findAllElements('w:t').map((e) => e.innerText).join(' ').trim();
            if (hText.isNotEmpty) {
              headerHtml = '<div class="doc-header">${const HtmlEscape().convert(hText)}</div>';
            }
          } catch (_) {}
        } else if (file.name.startsWith('word/footer') && file.name.endsWith('.xml') && footerHtml.isEmpty) {
          try {
            final fDoc = XmlDocument.parse(utf8.decode(file.content as List<int>, allowMalformed: true));
            final fText = fDoc.findAllElements('w:t').map((e) => e.innerText).join(' ').trim();
            if (fText.isNotEmpty) {
              footerHtml = '<div class="doc-footer">${const HtmlEscape().convert(fText)}</div>';
            }
          } catch (_) {}
        }
      }

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
      --table-header: #f1f5f9;
      --table-zebra: #f8fafc;
      --accent-blue: #2b579a;
    }
    body.dark-theme {
      --bg-canvas: #0b111b;
      --bg-page: #151f2e;
      --text-main: #e2e8f0;
      --text-muted: #94a3b8;
      --border-col: #334155;
      --table-header: #1e293b;
      --table-zebra: #192436;
      --accent-blue: #60a5fa;
    }
    * {
      box-sizing: border-box;
    }
    html, body {
      font-family: "Calibri", "Segoe UI", "Traditional Arabic", "Simplified Arabic", "Cairo", Roboto, -apple-system, sans-serif;
      margin: 0;
      padding: 0;
      color: var(--text-main);
      background-color: var(--bg-canvas);
      line-height: 1.65;
      -webkit-text-size-adjust: 100%;
      transition: background-color 0.2s ease, color 0.2s ease;
    }

    /* WPS Dual Engine:
       1) Default Mobile Reflow Mode (body.reflow-mode)
       2) Print Page Layout Mode (body:not(.reflow-mode)) */
    .workspace {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 12px 48px 12px;
      min-width: max-content;
    }
    .page-sheet {
      width: ${pageWidthPx.toStringAsFixed(0)}px;
      min-height: ${pageMinHeightPx.toStringAsFixed(0)}px;
      background: var(--bg-page);
      padding: ${marginTopPx.toStringAsFixed(0)}px ${marginRightPx.toStringAsFixed(0)}px ${marginBottomPx.toStringAsFixed(0)}px ${marginLeftPx.toStringAsFixed(0)}px;
      box-shadow: 0 8px 28px rgba(15, 23, 42, 0.12), 0 1px 3px rgba(15, 23, 42, 0.08);
      border: 1px solid var(--border-col);
      border-radius: 4px;
      margin-bottom: 24px;
      position: relative;
    }
    body.reflow-mode .workspace {
      min-width: 0;
      width: 100%;
      padding: 0;
    }
    body.reflow-mode .page-sheet {
      width: 100% !important;
      max-width: 100vw !important;
      min-height: 100vh;
      padding: 20px 18px 40px 18px !important;
      margin-bottom: 0;
      border: none;
      border-radius: 0;
      box-shadow: none;
      word-wrap: break-word;
      overflow-wrap: break-word;
    }

    .doc-header {
      font-size: 11.5px;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border-col);
      padding-bottom: 8px;
      margin-bottom: 18px;
    }
    .doc-footer {
      font-size: 11.5px;
      color: var(--text-muted);
      border-top: 1px solid var(--border-col);
      padding-top: 8px;
      margin-top: 28px;
      text-align: center;
    }
    .page-break-divider {
      border: 0;
      border-top: 2px dashed var(--border-col);
      margin: 28px 0;
      position: relative;
    }

    h1 { font-size: 22pt; margin: 18px 0 10px 0; font-weight: 700; color: var(--accent-blue); line-height: 1.3; }
    h2 { font-size: 16pt; margin: 16px 0 8px 0; font-weight: 700; color: var(--accent-blue); line-height: 1.35; }
    h3 { font-size: 13.5pt; margin: 14px 0 6px 0; font-weight: 600; line-height: 1.4; }
    h4 { font-size: 12pt; margin: 12px 0 6px 0; font-weight: 600; }
    p { margin: 6px 0; font-size: 11.5pt; max-width: 100%; }

    .list-item {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      margin: 5px 0;
    }
    .list-bullet {
      font-weight: bold;
      color: var(--accent-blue);
      user-select: none;
      flex-shrink: 0;
    }
    .list-content {
      flex: 1;
    }

    .table-scroll-wrapper {
      width: 100%;
      overflow-x: auto;
      margin: 14px 0;
      -webkit-overflow-scrolling: touch;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 10.5pt;
    }
    td, th {
      border: 1px solid var(--border-col);
      padding: 8px 12px;
      text-align: start;
      vertical-align: top;
      min-width: 70px;
    }
    th {
      background-color: var(--table-header);
      font-weight: 700;
    }
    tr:nth-child(even) td {
      background-color: var(--table-zebra);
    }
    img {
      max-width: 100%;
      height: auto;
      border-radius: 4px;
      margin: 10px auto;
      display: block;
    }
    a {
      color: var(--accent-blue);
      text-decoration: underline;
    }
    mark.search-hit {
      background: #fde047;
      color: #0f172a;
      padding: 0 2px;
      border-radius: 2px;
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-left { text-align: left; }
    .text-justify { text-align: justify; }
  </style>
  <script>
    function setDocZoom(scale) {
      document.body.style.zoom = scale;
    }
    function setReflowMode(enableReflow) {
      if (enableReflow) {
        document.body.classList.add('reflow-mode');
      } else {
        document.body.classList.remove('reflow-mode');
      }
    }
    function setDarkMode(enableDark) {
      if (enableDark) {
        document.body.classList.add('dark-theme');
      } else {
        document.body.classList.remove('dark-theme');
      }
    }
    function highlightQuery(query) {
      if (!window.find) return;
      if (query && query.length > 0) {
        window.find(query, false, false, true, false, false, false);
      }
    }
  </script>
</head>
<body class="${isDark ? 'dark-theme' : ''}">
  <div class="workspace">
    <div class="page-sheet">
      $headerHtml
''');

      final Map<String, int> listCounters = {};

      for (final child in body.children) {
        if (child is! XmlElement) continue;

        if (child.name.local == 'p') {
          sb.write(_parseParagraph(child, imageMap, linkMap, styleMap, listCounters));
        } else if (child.name.local == 'tbl') {
          sb.write(_parseTable(child, imageMap, linkMap, styleMap, listCounters));
        } else if (child.name.local == 'sdt') {
          // Structured Document Tag (Table of Contents, Cover page blocks)
          final sdtContent = child.findElements('w:sdtContent').firstOrNull;
          if (sdtContent != null) {
            for (final sub in sdtContent.children) {
              if (sub is! XmlElement) continue;
              if (sub.name.local == 'p') {
                sb.write(_parseParagraph(sub, imageMap, linkMap, styleMap, listCounters));
              } else if (sub.name.local == 'tbl') {
                sb.write(_parseTable(sub, imageMap, linkMap, styleMap, listCounters));
              }
            }
          }
        }
      }

      sb.writeln('''
      $footerHtml
    </div>
  </div>
</body>
</html>
''');
      return sb.toString();
    } catch (e) {
      return '<p style="color:#ef4444; padding:20px;">حدث خطأ أثناء قراءة ملف DOCX: $e</p>';
    }
  }

  /// Extracts plain text from a `.docx` archive for statistics / copy / TTS
  static String extractPlainText(Uint8List docxBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) return '';
      final docXml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(docXml);
      final sb = StringBuffer();
      for (final p in doc.findAllElements('w:p')) {
        final line = p.findAllElements('w:t').map((e) => e.innerText).join();
        if (line.trim().isNotEmpty) {
          sb.writeln(line);
        }
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }

  static String _parseParagraph(
    XmlElement pElem,
    Map<String, String> imageMap,
    Map<String, String> linkMap,
    Map<String, _DocxStyleDef> styleMap,
    Map<String, int> listCounters,
  ) {
    String alignClass = '';
    String headingTag = 'p';
    final inlineStyles = <String>[];
    bool isBidi = false;
    bool isListItem = false;
    int listLevel = 0;
    String? numId;
    bool hasPageBreak = false;

    final pPr = pElem.findElements('w:pPr').firstOrNull;
    _DocxStyleDef? inheritedStyle;

    if (pPr != null) {
      final pStyleVal = pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
      if (pStyleVal != null) {
        inheritedStyle = styleMap[pStyleVal];
        final lower = (inheritedStyle?.name ?? pStyleVal).toLowerCase();
        if (lower.contains('heading 1') || lower.contains('heading1') || lower == 'title') {
          headingTag = 'h1';
        } else if (lower.contains('heading 2') || lower.contains('heading2') || lower == 'subtitle') {
          headingTag = 'h2';
        } else if (lower.contains('heading 3') || lower.contains('heading3')) {
          headingTag = 'h3';
        } else if (lower.contains('heading 4') || lower.contains('heading4')) {
          headingTag = 'h4';
        }
      }

      if (pPr.findElements('w:bidi').isNotEmpty) {
        final bidiVal = pPr.findElements('w:bidi').firstOrNull?.getAttribute('w:val');
        if (bidiVal != '0' && bidiVal != 'false') {
          isBidi = true;
          inlineStyles.add('direction: rtl');
        }
      }

      final jc = pPr.findElements('w:jc').firstOrNull?.getAttribute('w:val') ?? inheritedStyle?.align;
      if (jc == 'center') {
        alignClass = 'text-center';
      } else if (jc == 'right' || (jc == 'start' && isBidi) || (jc == 'end' && !isBidi)) {
        alignClass = 'text-right';
      } else if (jc == 'left' || (jc == 'start' && !isBidi) || (jc == 'end' && isBidi)) {
        alignClass = 'text-left';
      } else if (jc == 'both' || jc == 'distribute') {
        alignClass = 'text-justify';
      }

      // Paragraph shading (background color)
      final shdFill = pPr.findElements('w:shd').firstOrNull?.getAttribute('w:fill');
      if (shdFill != null && shdFill != 'auto' && shdFill.length == 6) {
        inlineStyles.add('background-color: #$shdFill; padding: 6px 10px; border-radius: 4px');
      }

      // Indentation in Twips (1 Twip = 1/15 px)
      final ind = pPr.findElements('w:ind').firstOrNull;
      if (ind != null) {
        final leftTwips = double.tryParse(
            ind.getAttribute('w:start') ?? ind.getAttribute('w:left') ?? '');
        if (leftTwips != null && leftTwips > 0) {
          final px = (leftTwips / 15.0).clamp(0.0, 240.0);
          inlineStyles.add('padding-inline-start: ${px.toStringAsFixed(0)}px');
        }
      }

      // Spacing before / after in Twips
      final spacing = pPr.findElements('w:spacing').firstOrNull;
      if (spacing != null) {
        final beforeT = double.tryParse(spacing.getAttribute('w:before') ?? '');
        final afterT = double.tryParse(spacing.getAttribute('w:after') ?? '');
        if (beforeT != null && beforeT > 0) {
          inlineStyles.add('margin-top: ${(beforeT / 15.0).clamp(2.0, 48.0).toStringAsFixed(0)}px');
        }
        if (afterT != null && afterT > 0) {
          inlineStyles.add('margin-bottom: ${(afterT / 15.0).clamp(2.0, 48.0).toStringAsFixed(0)}px');
        }
      }

      // Numbered / Bulleted lists
      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        isListItem = true;
        final ilvl = numPr.findElements('w:ilvl').firstOrNull?.getAttribute('w:val');
        listLevel = int.tryParse(ilvl ?? '0') ?? 0;
        numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val') ?? '1';
      }

      if (pPr.findElements('w:pageBreakBefore').isNotEmpty) {
        hasPageBreak = true;
      }
    }

    final contentSb = StringBuffer();

    for (final child in pElem.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'r') {
        if (child.findElements('w:br').any((b) => b.getAttribute('w:type') == 'page')) {
          hasPageBreak = true;
        }
        contentSb.write(_parseRun(child, imageMap, inheritedStyle));
      } else if (child.name.local == 'hyperlink') {
        final rId = child.getAttribute('r:id');
        final href = (rId != null && linkMap.containsKey(rId)) ? linkMap[rId]! : '#';
        final linkInner = StringBuffer();
        for (final r in child.findElements('w:r')) {
          linkInner.write(_parseRun(r, imageMap, inheritedStyle));
        }
        if (linkInner.isNotEmpty) {
          contentSb.write('<a href="$href" target="_blank">${linkInner.toString()}</a>');
        }
      } else if (child.name.local == 'drawing') {
        contentSb.write(_parseDrawing(child, imageMap));
      }
    }

    final innerHtml = contentSb.toString();
    final pageBreakHtml = hasPageBreak ? '<hr class="page-break-divider" />\n' : '';

    if (innerHtml.trim().isEmpty) {
      return '$pageBreakHtml<div style="height: 8px;"></div>\n';
    }

    final classAttr = alignClass.isNotEmpty ? ' class="$alignClass"' : '';
    final styleAttr = inlineStyles.isNotEmpty ? ' style="${inlineStyles.join('; ')}"' : '';

    if (isListItem) {
      final key = '${numId}_$listLevel';
      final count = (listCounters[key] ?? 0) + 1;
      listCounters[key] = count;
      final indentPx = listLevel * 20;
      final bulletSymbol = listLevel == 0 ? '•' : (listLevel == 1 ? '◦' : '▪');
      return '$pageBreakHtml<div class="list-item" style="padding-inline-start: ${indentPx}px;">'
          '<span class="list-bullet">$bulletSymbol</span>'
          '<div class="list-content"$styleAttr>$innerHtml</div>'
          '</div>\n';
    }

    return '$pageBreakHtml<$headingTag$classAttr$styleAttr>$innerHtml</$headingTag>\n';
  }

  static String _parseRun(
    XmlElement rElem,
    Map<String, String> imageMap,
    _DocxStyleDef? inheritedStyle,
  ) {
    final sb = StringBuffer();
    bool isBold = inheritedStyle?.isBold ?? false;
    bool isItalic = inheritedStyle?.isItalic ?? false;
    bool isUnderline = false;
    bool isStrike = false;
    String? vertAlign; // superscript / subscript
    String? color = inheritedStyle?.colorHex;
    String? highlight;
    double? fontSize = inheritedStyle?.fontSizePt;

    final rPr = rElem.findElements('w:rPr').firstOrNull;
    if (rPr != null) {
      final bElem = rPr.findElements('w:b').firstOrNull ?? rPr.findElements('w:bCs').firstOrNull;
      if (bElem != null && bElem.getAttribute('w:val') != '0') isBold = true;

      final iElem = rPr.findElements('w:i').firstOrNull ?? rPr.findElements('w:iCs').firstOrNull;
      if (iElem != null && iElem.getAttribute('w:val') != '0') isItalic = true;

      final uElem = rPr.findElements('w:u').firstOrNull;
      if (uElem != null && uElem.getAttribute('w:val') != 'none') isUnderline = true;

      if (rPr.findElements('w:strike').isNotEmpty || rPr.findElements('w:dstrike').isNotEmpty) {
        isStrike = true;
      }

      color = rPr.findElements('w:color').firstOrNull?.getAttribute('w:val') ?? color;
      highlight = rPr.findElements('w:highlight').firstOrNull?.getAttribute('w:val') ??
          rPr.findElements('w:shd').firstOrNull?.getAttribute('w:fill');
      vertAlign = rPr.findElements('w:vertAlign').firstOrNull?.getAttribute('w:val');

      final sz = rPr.findElements('w:sz').firstOrNull?.getAttribute('w:val') ??
          rPr.findElements('w:szCs').firstOrNull?.getAttribute('w:val');
      if (sz != null) {
        final val = double.tryParse(sz);
        if (val != null) fontSize = val / 2.0; // Half-points to points
      }
    }

    // Embedded images inside run
    for (final drawing in rElem.findAllElements('w:drawing')) {
      sb.write(_parseDrawing(drawing, imageMap));
    }

    // Text content, tabs, and line breaks
    for (final child in rElem.children) {
      if (child is! XmlElement) continue;
      if (child.name.local == 't') {
        sb.write(const HtmlEscape().convert(child.innerText));
      } else if (child.name.local == 'tab') {
        sb.write('&emsp;');
      } else if (child.name.local == 'br') {
        if (child.getAttribute('w:type') != 'page') {
          sb.write('<br/>');
        }
      }
    }

    String result = sb.toString();
    if (result.isEmpty) return '';

    final styles = <String>[];
    if (fontSize != null) styles.add('font-size: ${fontSize}pt');
    if (color != null && color != 'auto' && color != '000000') {
      styles.add('color: #$color');
    }
    if (highlight != null && highlight != 'none' && highlight != 'auto') {
      final hlHex = _mapHighlightColor(highlight);
      if (hlHex != null) {
        styles.add('background-color: $hlHex; padding: 0 2px; border-radius: 2px');
      }
    }

    if (styles.isNotEmpty) {
      result = '<span style="${styles.join('; ')}">$result</span>';
    }

    if (vertAlign == 'superscript') result = '<sup>$result</sup>';
    if (vertAlign == 'subscript') result = '<sub>$result</sub>';
    if (isBold) result = '<b>$result</b>';
    if (isItalic) result = '<i>$result</i>';
    if (isUnderline) result = '<u>$result</u>';
    if (isStrike) result = '<s>$result</s>';

    return result;
  }

  static String? _mapHighlightColor(String val) {
    switch (val.toLowerCase()) {
      case 'yellow':
        return '#fef08a';
      case 'green':
        return '#bbf7d0';
      case 'cyan':
        return '#a5f3fc';
      case 'magenta':
        return '#f5d0fe';
      case 'blue':
        return '#bfdbfe';
      case 'red':
        return '#fecaca';
      default:
        if (val.length == 6 && int.tryParse(val, radix: 16) != null) {
          return '#$val';
        }
        return null;
    }
  }

  static String _parseDrawing(XmlElement drawing, Map<String, String> imageMap) {
    // Check EMU dimensions if present (1 inch = 914400 EMUs = 96px -> 1px = 9525 EMUs)
    String styleAttr = '';
    final extent = drawing.findAllElements('wp:extent').firstOrNull;
    if (extent != null) {
      final cx = double.tryParse(extent.getAttribute('cx') ?? '');
      if (cx != null && cx > 0) {
        final widthPx = math.min(cx / 9525.0, 680.0);
        styleAttr = ' style="width: ${widthPx.toStringAsFixed(0)}px; max-width: 100%;"';
      }
    }

    for (final blip in drawing.findAllElements('a:blip')) {
      final embedId = blip.getAttribute('r:embed');
      if (embedId != null && imageMap.containsKey(embedId)) {
        return '<img src="${imageMap[embedId]}"$styleAttr alt="document image" />';
      }
    }
    return '';
  }

  static String _parseTable(
    XmlElement tblElem,
    Map<String, String> imageMap,
    Map<String, String> linkMap,
    Map<String, _DocxStyleDef> styleMap,
    Map<String, int> listCounters,
  ) {
    final sb = StringBuffer();
    sb.writeln('<div class="table-scroll-wrapper"><table>');

    int rowIndex = 0;
    for (final tr in tblElem.findElements('w:tr')) {
      sb.writeln('  <tr>');
      final isHeaderRow = rowIndex == 0 &&
          (tr.findAllElements('w:tblHeader').isNotEmpty || tblElem.findElements('w:tr').length > 1);

      for (final tc in tr.findElements('w:tc')) {
        final tcPr = tc.findElements('w:tcPr').firstOrNull;
        String spanAttr = '';
        final cellStyles = <String>[];

        if (tcPr != null) {
          // Horizontal merge (gridSpan)
          final gridSpan = tcPr.findElements('w:gridSpan').firstOrNull?.getAttribute('w:val');
          if (gridSpan != null && int.tryParse(gridSpan) != null && int.parse(gridSpan) > 1) {
            spanAttr += ' colspan="$gridSpan"';
          }
          // Cell background shading
          final shdFill = tcPr.findElements('w:shd').firstOrNull?.getAttribute('w:fill');
          if (shdFill != null && shdFill != 'auto' && shdFill.length == 6) {
            cellStyles.add('background-color: #$shdFill');
          }
        }

        final tag = isHeaderRow ? 'th' : 'td';
        final styleStr = cellStyles.isNotEmpty ? ' style="${cellStyles.join('; ')}"' : '';
        sb.write('    <$tag$spanAttr$styleStr>');
        for (final p in tc.findElements('w:p')) {
          sb.write(_parseParagraph(p, imageMap, linkMap, styleMap, listCounters));
        }
        sb.writeln('</$tag>');
      }
      sb.writeln('  </tr>');
      rowIndex++;
    }

    sb.writeln('</table></div>');
    return sb.toString();
  }
}

class _DocxStyleDef {
  final String id;
  final String name;
  final double? fontSizePt;
  final String? colorHex;
  final bool isBold;
  final bool isItalic;
  final String? align;

  const _DocxStyleDef({
    required this.id,
    required this.name,
    this.fontSizePt,
    this.colorHex,
    this.isBold = false,
    this.isItalic = false,
    this.align,
  });
}

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class DocxParseResult {
  final String html;
  final int pageCount;
  final double pageWidthPx;
  final double pageMinHeightPx;
  final double fitScale;

  const DocxParseResult({
    required this.html,
    required this.pageCount,
    required this.pageWidthPx,
    required this.pageMinHeightPx,
    required this.fitScale,
  });
}

class DocxParser {
  /// Converts a `.docx` / `.dotx` file byte buffer into a rich HTML document
  /// modeled after WPS Office's dual-mode engine (`PageMode` using Twips A4 sheet geometry
  /// with physical pagination, crop marks, invisible layout tables, and Fit-to-Width auto-zoom
  /// vs. `MobileMode` responsive reflow).
  static DocxParseResult parse(
    Uint8List docxBytes, {
    bool isDark = false,
    double screenWidth = 390.0,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(docxBytes);

      // 1. Extract ALL relationships (images & hyperlinks) from all *.rels files
      final imageMap = <String, String>{};
      final linkMap = <String, String>{};
      for (final relFile in archive.files) {
        if (!relFile.name.endsWith('.rels')) continue;
        try {
          final relsXml = utf8.decode(relFile.content as List<int>, allowMalformed: true);
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

      // 2. Parse word/styles.xml for style definitions
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
        const errorHtml = '<p style="padding:20px;">الملف غير صالح أو لا يحتوي على محتوى document.xml</p>';
        return const DocxParseResult(
          html: errorHtml,
          pageCount: 1,
          pageWidthPx: 794.0,
          pageMinHeightPx: 1123.0,
          fitScale: 1.0,
        );
      }

      final docXml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(docXml);
      final body = doc.findAllElements('w:body').firstOrNull;
      if (body == null) {
        const errorHtml = '<p style="padding:20px;">لا يوجد محتوى لعرضه في المستند.</p>';
        return const DocxParseResult(
          html: errorHtml,
          pageCount: 1,
          pageWidthPx: 794.0,
          pageMinHeightPx: 1123.0,
          fitScale: 1.0,
        );
      }

      // 4. Extract Page Geometry in Twips (1 Twip = 1/20 pt = 1/1440 inch, @96 DPI = 1/15 px)
      // Default A4 in Twips: w = 11906 (794px), h = 16838 (1123px)
      double pageWidthPx = 794;
      double pageMinHeightPx = 1123;
      double marginTopPx = 54;
      double marginBottomPx = 54;
      double marginLeftPx = 54;
      double marginRightPx = 54;

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
          if (topT != null) marginTopPx = (topT / 15.0).clamp(20.0, 120.0);
          if (botT != null) marginBottomPx = (botT / 15.0).clamp(20.0, 120.0);
          if (leftT != null) marginLeftPx = (leftT / 15.0).clamp(20.0, 120.0);
          if (rightT != null) marginRightPx = (rightT / 15.0).clamp(20.0, 120.0);
        }
      }

      // Compute WPS Fit-to-Width Initial Scale:
      final effectiveScreenWidth = screenWidth > 100 ? screenWidth : 390.0;
      final fitScale = ((effectiveScreenWidth - 16.0) / pageWidthPx).clamp(0.25, 1.5);

      // 5. Header & Footer extraction
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

      // 6. Physical Pagination Parsing:
      final pages = <StringBuffer>[StringBuffer()];
      final Map<String, int> listCounters = {};

      for (final child in body.children) {
        if (child is! XmlElement) continue;

        if (child.name.local == 'p') {
          _parseParagraphToPages(
            pElem: child,
            imageMap: imageMap,
            linkMap: linkMap,
            styleMap: styleMap,
            listCounters: listCounters,
            pages: pages,
          );
        } else if (child.name.local == 'tbl') {
          pages.last.write(_parseTable(child, imageMap, linkMap, styleMap, listCounters));
        } else if (child.name.local == 'sdt') {
          final sdtContent = child.findElements('w:sdtContent').firstOrNull;
          if (sdtContent != null) {
            for (final sub in sdtContent.children) {
              if (sub is! XmlElement) continue;
              if (sub.name.local == 'p') {
                _parseParagraphToPages(
                  pElem: sub,
                  imageMap: imageMap,
                  linkMap: linkMap,
                  styleMap: styleMap,
                  listCounters: listCounters,
                  pages: pages,
                );
              } else if (sub.name.local == 'tbl') {
                pages.last.write(_parseTable(sub, imageMap, linkMap, styleMap, listCounters));
              }
            }
          }
        }
      }

      // Prune trailing empty pages
      while (pages.length > 1 && pages.last.toString().trim().isEmpty) {
        pages.removeLast();
      }
      if (pages.isEmpty) {
        pages.add(StringBuffer()..write('<p></p>'));
      }
      final totalPages = pages.length;

      // 7. Render complete HTML with Page Canvas styling, Corner Crop Marks, and Pre-applied Zoom
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

    /* WPS Dual Engine */
    .workspace {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 16px 8px 64px 8px;
      min-width: max-content;
      box-sizing: border-box;
    }
    .page-sheet {
      width: ${pageWidthPx.toStringAsFixed(0)}px;
      min-height: ${pageMinHeightPx.toStringAsFixed(0)}px;
      background: var(--bg-page);
      padding: ${marginTopPx.toStringAsFixed(0)}px ${marginRightPx.toStringAsFixed(0)}px ${marginBottomPx.toStringAsFixed(0)}px ${marginLeftPx.toStringAsFixed(0)}px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.09), 0 1px 3px rgba(0, 0, 0, 0.05);
      border: 1px solid var(--border-col);
      border-radius: 3px;
      margin-bottom: 24px;
      position: relative;
      box-sizing: border-box;
    }
    .page-inner-content {
      width: 100%;
      min-height: calc(100% - 20px);
    }

    /* 3-Column Top Header (English left, Logo center, Arabic right) */
    .header-3col-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      width: 100%;
      margin: 0 0 20px 0;
    }
    .header-col-left {
      flex: 1;
      text-align: left;
      direction: ltr;
      font-size: 10pt;
      line-height: 1.35;
    }
    .header-col-center {
      flex-shrink: 0;
      padding: 0 14px;
      text-align: center;
    }
    .header-col-center img {
      max-height: 110px;
      max-width: 110px;
      object-fit: contain;
      margin: 0 auto;
      display: block;
    }
    .header-col-right {
      flex: 1;
      text-align: right;
      direction: rtl;
      font-size: 10pt;
      line-height: 1.35;
    }

    /* Corner Crop Marks */
    .crop-mark {
      position: absolute;
      width: 14px;
      height: 14px;
      pointer-events: none;
      opacity: 0.35;
    }
    .crop-mark-tl {
      top: 10px;
      left: 10px;
      border-top: 1.5px solid var(--text-muted);
      border-left: 1.5px solid var(--text-muted);
    }
    .crop-mark-tr {
      top: 10px;
      right: 10px;
      border-top: 1.5px solid var(--text-muted);
      border-right: 1.5px solid var(--text-muted);
    }
    .crop-mark-bl {
      bottom: 10px;
      left: 10px;
      border-bottom: 1.5px solid var(--text-muted);
      border-left: 1.5px solid var(--text-muted);
    }
    .crop-mark-br {
      bottom: 10px;
      right: 10px;
      border-bottom: 1.5px solid var(--text-muted);
      border-right: 1.5px solid var(--text-muted);
    }

    .page-sheet-footer {
      position: absolute;
      bottom: 8px;
      left: 0;
      right: 0;
      display: flex;
      justify-content: center;
      pointer-events: none;
    }
    .page-num-pill {
      font-size: 11px;
      color: var(--text-muted);
      background: var(--bg-canvas);
      padding: 2px 10px;
      border-radius: 12px;
      font-weight: 500;
      opacity: 0.85;
      letter-spacing: 0.5px;
    }

    /* Mobile Reflow Mode */
    body.reflow-mode {
      zoom: 1.0 !important;
    }
    body.reflow-mode .workspace {
      min-width: 0 !important;
      width: 100% !important;
      padding: 0 !important;
    }
    body.reflow-mode .page-sheet {
      width: 100% !important;
      max-width: 100vw !important;
      min-height: auto !important;
      padding: 16px 16px 24px 16px !important;
      margin-bottom: 0 !important;
      border: none !important;
      border-radius: 0 !important;
      box-shadow: none !important;
    }
    body.reflow-mode .crop-mark,
    body.reflow-mode .page-sheet-footer {
      display: none !important;
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
      margin: 10px 0;
      -webkit-overflow-scrolling: touch;
    }

    /* Invisible Layout Tables */
    table.layout-table {
      width: 100%;
      border-collapse: collapse;
      border: none !important;
      background: transparent !important;
      margin: 8px 0;
    }
    table.layout-table td,
    table.layout-table th {
      border: none !important;
      background: transparent !important;
      padding: 4px 6px;
      word-break: break-word;
      overflow-wrap: break-word;
    }
    table.layout-table tr:nth-child(even) td {
      background: transparent !important;
    }
    table.layout-table img {
      max-width: 100% !important;
      height: auto !important;
      max-height: 110px !important;
      display: block;
      margin: 0 auto;
      object-fit: contain;
    }

    /* Standard Data Tables */
    table.data-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 10.5pt;
      margin: 14px 0;
    }
    table.data-table td,
    table.data-table th {
      border: 1px solid var(--border-col);
      padding: 8px 12px;
      text-align: start;
      vertical-align: top;
      min-width: 60px;
    }
    table.data-table th {
      background-color: var(--table-header);
      font-weight: 700;
    }
    table.data-table tr:nth-child(even) td {
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
<body class="${isDark ? 'dark-theme' : ''}" style="zoom: ${fitScale.toStringAsFixed(3)};">
  <div class="workspace">
''');

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        sb.writeln('''
    <div class="page-sheet" id="page-$pageNum" data-page="$pageNum">
      <div class="crop-mark crop-mark-tl"></div>
      <div class="crop-mark crop-mark-tr"></div>
      <div class="crop-mark crop-mark-bl"></div>
      <div class="crop-mark crop-mark-br"></div>
      ${i == 0 && headerHtml.isNotEmpty ? headerHtml : ''}
      <div class="page-inner-content">
${pages[i].toString()}
      </div>
      ${i == totalPages - 1 && footerHtml.isNotEmpty ? footerHtml : ''}
      <div class="page-sheet-footer">
        <span class="page-num-pill">$pageNum / $totalPages</span>
      </div>
    </div>
''');
      }

      sb.writeln('''
  </div>
</body>
</html>
''');

      return DocxParseResult(
        html: sb.toString(),
        pageCount: totalPages,
        pageWidthPx: pageWidthPx,
        pageMinHeightPx: pageMinHeightPx,
        fitScale: fitScale,
      );
    } catch (e) {
      final errorHtml = '<p style="color:#ef4444; padding:20px;">حدث خطأ أثناء قراءة ملف DOCX: $e</p>';
      return DocxParseResult(
        html: errorHtml,
        pageCount: 1,
        pageWidthPx: 794.0,
        pageMinHeightPx: 1123.0,
        fitScale: 1.0,
      );
    }
  }

  /// Convenience wrapper returning just HTML string for legacy callers
  static String parseToHtml(
    Uint8List docxBytes, {
    bool isDark = false,
    double screenWidth = 390.0,
  }) {
    return parse(docxBytes, isDark: isDark, screenWidth: screenWidth).html;
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

  /// Dispatches paragraph content across pages, respecting `<w:pageBreakBefore>`,
  /// inline `<w:br w:type="page"/>`, `<w:lastRenderedPageBreak/>`, and section breaks (`<w:sectPr>`).
  static void _parseParagraphToPages({
    required XmlElement pElem,
    required Map<String, String> imageMap,
    required Map<String, String> linkMap,
    required Map<String, _DocxStyleDef> styleMap,
    required Map<String, int> listCounters,
    required List<StringBuffer> pages,
  }) {
    final pPr = pElem.findElements('w:pPr').firstOrNull;

    // 1. Page Break Before attribute
    if (pPr != null && pPr.findElements('w:pageBreakBefore').isNotEmpty) {
      if (pages.last.isNotEmpty) {
        pages.add(StringBuffer());
      }
    }

    // 2. Check for 3-element Top Header (English left, Logo center, Arabic right)
    final drawings = pElem.findAllElements('w:drawing').toList();
    if (drawings.length >= 2 && pElem.parent is XmlElement && (pElem.parent as XmlElement).name.local == 'body') {
      final hasImage = drawings.any((d) => d.findAllElements('a:blip').isNotEmpty);
      final hasTxbx = drawings.any((d) => d.findAllElements('w:txbxContent').isNotEmpty);
      if (hasImage && hasTxbx) {
        pages.last.writeln(_renderHeader3Col(
          drawings: drawings,
          imageMap: imageMap,
          linkMap: linkMap,
          styleMap: styleMap,
          listCounters: listCounters,
        ));
        return;
      }
    }

    String alignClass = '';
    String headingTag = 'p';
    final inlineStyles = <String>[];
    bool isBidi = false;
    bool isListItem = false;
    int listLevel = 0;
    String? numId;
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

      final shdFill = pPr.findElements('w:shd').firstOrNull?.getAttribute('w:fill');
      if (shdFill != null && shdFill != 'auto' && shdFill.length == 6) {
        inlineStyles.add('background-color: #$shdFill; padding: 6px 10px; border-radius: 4px');
      }

      final ind = pPr.findElements('w:ind').firstOrNull;
      if (ind != null) {
        final leftTwips = double.tryParse(ind.getAttribute('w:start') ?? ind.getAttribute('w:left') ?? '');
        if (leftTwips != null && leftTwips > 0) {
          final px = (leftTwips / 15.0).clamp(0.0, 240.0);
          inlineStyles.add('padding-inline-start: ${px.toStringAsFixed(0)}px');
        }
      }

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

      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        isListItem = true;
        final ilvl = numPr.findElements('w:ilvl').firstOrNull?.getAttribute('w:val');
        listLevel = int.tryParse(ilvl ?? '0') ?? 0;
        numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val') ?? '1';
      }
    }

    final classAttr = alignClass.isNotEmpty ? ' class="$alignClass"' : '';
    final styleAttr = inlineStyles.isNotEmpty ? ' style="${inlineStyles.join('; ')}"' : '';

    void emitChunk(String innerContent) {
      if (innerContent.trim().isEmpty) return;
      if (isListItem) {
        final key = '${numId}_$listLevel';
        final count = (listCounters[key] ?? 0) + 1;
        listCounters[key] = count;
        final indentPx = listLevel * 20;
        final bulletSymbol = listLevel == 0 ? '•' : (listLevel == 1 ? '◦' : '▪');
        pages.last.writeln(
          '<div class="list-item" style="padding-inline-start: ${indentPx}px;">'
          '<span class="list-bullet">$bulletSymbol</span>'
          '<div class="list-content"$styleAttr>$innerContent</div>'
          '</div>',
        );
      } else {
        pages.last.writeln('<$headingTag$classAttr$styleAttr>$innerContent</$headingTag>');
      }
    }

    final currentChunkSb = StringBuffer();

    for (final child in pElem.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'r') {
        final hasPageBreak = child.findElements('w:br').any((b) => b.getAttribute('w:type') == 'page') ||
            child.findElements('w:lastRenderedPageBreak').isNotEmpty;

        if (hasPageBreak) {
          emitChunk(currentChunkSb.toString());
          currentChunkSb.clear();
          if (pages.last.isNotEmpty) {
            pages.add(StringBuffer());
          }
        }
        currentChunkSb.write(_parseRun(child, imageMap, linkMap, styleMap, listCounters, inheritedStyle));
      } else if (child.name.local == 'hyperlink') {
        final rId = child.getAttribute('r:id');
        final href = (rId != null && linkMap.containsKey(rId)) ? linkMap[rId]! : '#';
        final linkInner = StringBuffer();
        for (final r in child.findElements('w:r')) {
          linkInner.write(_parseRun(r, imageMap, linkMap, styleMap, listCounters, inheritedStyle));
        }
        if (linkInner.isNotEmpty) {
          currentChunkSb.write('<a href="$href" target="_blank">${linkInner.toString()}</a>');
        }
      } else if (child.name.local == 'drawing') {
        currentChunkSb.write(_parseDrawing(
          child,
          imageMap,
          linkMap,
          styleMap,
          listCounters,
        ));
      }
    }

    emitChunk(currentChunkSb.toString());

    // 3. Paragraph-level Section Break (<w:pPr><w:sectPr>)
    if (pPr != null) {
      final sectPr = pPr.findElements('w:sectPr').firstOrNull;
      if (sectPr != null) {
        final typeVal = sectPr.findElements('w:type').firstOrNull?.getAttribute('w:val')?.toLowerCase();
        if (typeVal != 'continuous') {
          if (pages.last.isNotEmpty) {
            pages.add(StringBuffer());
          }
        }
      }
    }
  }

  /// Renders a 3-column top header (e.g. English text left, Logo center, Arabic text right)
  static String _renderHeader3Col({
    required List<XmlElement> drawings,
    required Map<String, String> imageMap,
    required Map<String, String> linkMap,
    required Map<String, _DocxStyleDef> styleMap,
    required Map<String, int> listCounters,
  }) {
    String englishText = '';
    String arabicText = '';
    String logoImg = '';

    for (final d in drawings) {
      final blip = d.findAllElements('a:blip').firstOrNull;
      if (blip != null) {
        final embedId = blip.getAttribute('r:embed');
        if (embedId != null && imageMap.containsKey(embedId)) {
          logoImg = '<img src="${imageMap[embedId]}" alt="University Logo" />';
        }
      }

      final txbxList = d.findAllElements('w:txbxContent');
      for (final tb in txbxList) {
        final isFallback = tb.ancestors.any((a) => a is XmlElement && a.name.local == 'Fallback');
        if (isFallback) continue;

        final rawText = tb.findAllElements('w:t').map((e) => e.innerText).join(' ');
        final htmlSb = StringBuffer();
        for (final p in tb.findElements('w:p')) {
          htmlSb.write(_parseParagraphContent(p, imageMap, linkMap, styleMap, listCounters));
        }

        // Detect whether English or Arabic
        final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawText);
        if (isArabic) {
          arabicText = htmlSb.toString();
        } else {
          englishText = htmlSb.toString();
        }
      }
    }

    return '''
<div class="header-3col-bar">
  <div class="header-col-left">$englishText</div>
  <div class="header-col-center">$logoImg</div>
  <div class="header-col-right">$arabicText</div>
</div>
''';
  }

  /// Parses paragraph content for inline contexts (e.g. inside table cells or text boxes)
  static String _parseParagraphContent(
    XmlElement pElem,
    Map<String, String> imageMap,
    Map<String, String> linkMap,
    Map<String, _DocxStyleDef> styleMap,
    Map<String, int> listCounters, {
    bool insideTable = false,
  }) {
    String alignClass = '';
    String headingTag = 'p';
    final inlineStyles = <String>[];
    bool isBidi = false;
    bool isListItem = false;
    int listLevel = 0;
    String? numId;

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

      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        isListItem = true;
        final ilvl = numPr.findElements('w:ilvl').firstOrNull?.getAttribute('w:val');
        listLevel = int.tryParse(ilvl ?? '0') ?? 0;
        numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val') ?? '1';
      }
    }

    final contentSb = StringBuffer();
    for (final child in pElem.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'r') {
        contentSb.write(_parseRun(child, imageMap, linkMap, styleMap, listCounters, inheritedStyle, insideTable: insideTable));
      } else if (child.name.local == 'hyperlink') {
        final rId = child.getAttribute('r:id');
        final href = (rId != null && linkMap.containsKey(rId)) ? linkMap[rId]! : '#';
        final linkInner = StringBuffer();
        for (final r in child.findElements('w:r')) {
          linkInner.write(_parseRun(r, imageMap, linkMap, styleMap, listCounters, inheritedStyle, insideTable: insideTable));
        }
        if (linkInner.isNotEmpty) {
          contentSb.write('<a href="$href" target="_blank">${linkInner.toString()}</a>');
        }
      } else if (child.name.local == 'drawing') {
        contentSb.write(_parseDrawing(child, imageMap, linkMap, styleMap, listCounters, insideTable: insideTable));
      }
    }

    final innerHtml = contentSb.toString();
    if (innerHtml.trim().isEmpty) {
      return '<div style="height: 4px;"></div>\n';
    }

    final classAttr = alignClass.isNotEmpty ? ' class="$alignClass"' : '';
    final styleAttr = inlineStyles.isNotEmpty ? ' style="${inlineStyles.join('; ')}"' : '';

    if (isListItem) {
      final key = '${numId}_$listLevel';
      final count = (listCounters[key] ?? 0) + 1;
      listCounters[key] = count;
      final indentPx = listLevel * 16;
      final bulletSymbol = listLevel == 0 ? '•' : (listLevel == 1 ? '◦' : '▪');
      return '<div class="list-item" style="padding-inline-start: ${indentPx}px;">'
          '<span class="list-bullet">$bulletSymbol</span>'
          '<div class="list-content"$styleAttr>$innerHtml</div>'
          '</div>\n';
    }

    return '<$headingTag$classAttr$styleAttr>$innerHtml</$headingTag>\n';
  }

  static String _parseRun(
    XmlElement rElem,
    Map<String, String> imageMap,
    Map<String, String> linkMap,
    Map<String, _DocxStyleDef> styleMap,
    Map<String, int> listCounters,
    _DocxStyleDef? inheritedStyle, {
    bool insideTable = false,
  }) {
    final sb = StringBuffer();
    bool isBold = inheritedStyle?.isBold ?? false;
    bool isItalic = inheritedStyle?.isItalic ?? false;
    bool isUnderline = false;
    bool isStrike = false;
    String? vertAlign;
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
        if (val != null) fontSize = val / 2.0;
      }
    }

    for (final drawing in rElem.findAllElements('w:drawing')) {
      sb.write(_parseDrawing(drawing, imageMap, linkMap, styleMap, listCounters, insideTable: insideTable));
    }

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

  /// Parses drawings, images, and text boxes (`w:txbxContent`)
  static String _parseDrawing(
    XmlElement drawing,
    Map<String, String> imageMap,
    Map<String, String> linkMap,
    Map<String, _DocxStyleDef> styleMap,
    Map<String, int> listCounters, {
    bool insideTable = false,
  }) {
    final sb = StringBuffer();

    // 1. Images (a:blip)
    for (final blip in drawing.findAllElements('a:blip')) {
      final embedId = blip.getAttribute('r:embed');
      if (embedId != null && imageMap.containsKey(embedId)) {
        if (insideTable) {
          sb.write('<img src="${imageMap[embedId]}" style="max-width: 100%; height: auto; max-height: 110px; object-fit: contain; margin: 4px auto; display: block;" alt="image" />');
        } else {
          final extent = drawing.findAllElements('wp:extent').firstOrNull;
          String styleAttr = 'max-width: 100%; height: auto; display: block; margin: 8px auto;';
          if (extent != null) {
            final cx = double.tryParse(extent.getAttribute('cx') ?? '');
            if (cx != null && cx > 0) {
              final widthPx = math.min(cx / 9525.0, 680.0);
              styleAttr = 'width: ${widthPx.toStringAsFixed(0)}px; $styleAttr';
            }
          }
          sb.write('<img src="${imageMap[embedId]}" style="$styleAttr" alt="image" />');
        }
      }
    }

    // 2. Text Boxes (w:txbxContent inside wps:txbx or v:textbox)
    final txbxElements = drawing.findAllElements('w:txbxContent');
    for (final txbx in txbxElements) {
      final isFallback = txbx.ancestors.any((a) => a is XmlElement && a.name.local == 'Fallback');
      if (isFallback) continue;

      for (final child in txbx.children) {
        if (child is! XmlElement) continue;
        if (child.name.local == 'p') {
          sb.write(_parseParagraphContent(
            child,
            imageMap,
            linkMap,
            styleMap,
            listCounters,
            insideTable: insideTable,
          ));
        } else if (child.name.local == 'tbl') {
          sb.write(_parseTable(child, imageMap, linkMap, styleMap, listCounters));
        }
      }
    }

    return sb.toString();
  }

  /// Determines whether a table is an invisible border layout table
  static bool _isTableBorderless(XmlElement tblElem) {
    final tblPr = tblElem.findElements('w:tblPr').firstOrNull;
    if (tblPr == null) return true;

    final tblBorders = tblPr.findElements('w:tblBorders').firstOrNull;
    if (tblBorders != null) {
      final borderNames = ['w:top', 'w:left', 'w:bottom', 'w:right', 'w:insideH', 'w:insideV'];
      bool hasVisibleBorder = false;
      for (final bName in borderNames) {
        final b = tblBorders.findElements(bName).firstOrNull;
        if (b != null) {
          final val = b.getAttribute('w:val')?.toLowerCase();
          if (val != null && val != 'none' && val != 'nil' && val != '0') {
            hasVisibleBorder = true;
            break;
          }
        }
      }
      return !hasVisibleBorder;
    }

    final tblStyle = tblPr.findElements('w:tblStyle').firstOrNull?.getAttribute('w:val')?.toLowerCase() ?? '';
    if (tblStyle.contains('grid') || tblStyle.contains('tablegrid')) {
      return false;
    }

    return true;
  }

  /// Parses table with support for invisible layout tables, column widths (`w:tblGrid` and `w:tcW`),
  /// and vertical cell alignment.
  static String _parseTable(
    XmlElement tblElem,
    Map<String, String> imageMap,
    Map<String, String> linkMap,
    Map<String, _DocxStyleDef> styleMap,
    Map<String, int> listCounters,
  ) {
    final isLayout = _isTableBorderless(tblElem);

    final gridCols = <double>[];
    final tblGrid = tblElem.findElements('w:tblGrid').firstOrNull;
    if (tblGrid != null) {
      for (final col in tblGrid.findElements('w:gridCol')) {
        final w = double.tryParse(col.getAttribute('w:w') ?? '');
        if (w != null && w > 0) {
          gridCols.add(w);
        }
      }
    }
    final totalGridTwips = gridCols.fold<double>(0.0, (sum, w) => sum + w);

    final tableClass = isLayout ? 'layout-table' : 'data-table';
    final tableStyle = isLayout
        ? 'width: 100%; table-layout: fixed; border-collapse: collapse;'
        : 'width: 100%; border-collapse: collapse;';

    final sb = StringBuffer();
    sb.writeln('<div class="table-scroll-wrapper"><table class="$tableClass" style="$tableStyle">');

    int rowIndex = 0;
    final rows = tblElem.findElements('w:tr').toList();
    for (final tr in rows) {
      sb.writeln('  <tr>');
      final isHeaderRow = !isLayout && rowIndex == 0 &&
          (tr.findAllElements('w:tblHeader').isNotEmpty || rows.length > 1);

      final cells = tr.findElements('w:tc').toList();
      int colIndex = 0;

      for (final tc in cells) {
        final tcPr = tc.findElements('w:tcPr').firstOrNull;
        String spanAttr = '';
        final cellStyles = <String>[];

        if (tcPr != null) {
          final gridSpan = tcPr.findElements('w:gridSpan').firstOrNull?.getAttribute('w:val');
          if (gridSpan != null && int.tryParse(gridSpan) != null && int.parse(gridSpan) > 1) {
            spanAttr += ' colspan="$gridSpan"';
          }

          final vAlign = tcPr.findElements('w:vAlign').firstOrNull?.getAttribute('w:val')?.toLowerCase();
          if (vAlign == 'center') {
            cellStyles.add('vertical-align: middle');
          } else if (vAlign == 'bottom') {
            cellStyles.add('vertical-align: bottom');
          } else if (vAlign == 'top') {
            cellStyles.add('vertical-align: top');
          }

          final tcW = tcPr.findElements('w:tcW').firstOrNull;
          if (tcW != null) {
            final wType = tcW.getAttribute('w:type')?.toLowerCase();
            final wVal = double.tryParse(tcW.getAttribute('w:w') ?? '');
            if (wVal != null && wVal > 0) {
              if (wType == 'pct') {
                final pct = (wVal / 50.0).clamp(1.0, 100.0);
                cellStyles.add('width: ${pct.toStringAsFixed(1)}%');
              } else if (wType == 'dxa' && totalGridTwips > 0) {
                final pct = (wVal / totalGridTwips * 100.0).clamp(1.0, 100.0);
                cellStyles.add('width: ${pct.toStringAsFixed(1)}%');
              }
            }
          }

          if (!isLayout) {
            final shdFill = tcPr.findElements('w:shd').firstOrNull?.getAttribute('w:fill');
            if (shdFill != null && shdFill != 'auto' && shdFill != 'FFFFFF' && shdFill.length == 6) {
              cellStyles.add('background-color: #$shdFill');
            }
          }
        }

        if (!cellStyles.any((s) => s.startsWith('width:')) && colIndex < gridCols.length && totalGridTwips > 0) {
          final pct = (gridCols[colIndex] / totalGridTwips * 100.0).clamp(1.0, 100.0);
          cellStyles.add('width: ${pct.toStringAsFixed(1)}%');
        }

        final tag = isHeaderRow ? 'th' : 'td';
        final styleStr = cellStyles.isNotEmpty ? ' style="${cellStyles.join('; ')}"' : '';
        sb.write('    <$tag$spanAttr$styleStr>');
        for (final p in tc.findElements('w:p')) {
          sb.write(_parseParagraphContent(
            p,
            imageMap,
            linkMap,
            styleMap,
            listCounters,
            insideTable: true,
          ));
        }
        sb.writeln('</$tag>');
        colIndex++;
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

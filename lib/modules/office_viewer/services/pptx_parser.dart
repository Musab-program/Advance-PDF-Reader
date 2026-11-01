import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

enum PptxElementType {
  textBox,
  image,
  table,
}

class PptxTextParagraph {
  final String text;
  final bool isBold;
  final bool isItalic;
  final double? fontSizePt;
  final String? colorHex;
  final String align; // 'left', 'center', 'right'
  final bool isBullet;

  const PptxTextParagraph({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.fontSizePt,
    this.colorHex,
    this.align = 'left',
    this.isBullet = false,
  });
}

class PptxSlideElement {
  final PptxElementType type;
  // Normalized fractional coordinates [0.0 .. 1.0] relative to slide EMUs
  final double xFrac;
  final double yFrac;
  final double wFrac;
  final double hFrac;

  // Optional shape fill / border
  final String? fillColorHex;
  final String? borderColorHex;
  final bool isTitle;

  // Content based on type
  final List<PptxTextParagraph> paragraphs;
  final String? imageDataUrl;
  final List<List<String>> tableRows;

  const PptxSlideElement({
    required this.type,
    required this.xFrac,
    required this.yFrac,
    required this.wFrac,
    required this.hFrac,
    this.fillColorHex,
    this.borderColorHex,
    this.isTitle = false,
    this.paragraphs = const [],
    this.imageDataUrl,
    this.tableRows = const [],
  });
}

class PptxSlide {
  final int slideNumber;
  final String title;
  final List<String> bulletPoints;
  final List<String> images; // Base64 data URLs
  final List<PptxSlideElement> elements; // Scene graph positioned elements
  final String? backgroundColorHex;
  final String speakerNotes;

  const PptxSlide({
    required this.slideNumber,
    required this.title,
    required this.bulletPoints,
    required this.images,
    this.elements = const [],
    this.backgroundColorHex,
    this.speakerNotes = '',
  });
}

class PptxPresentation {
  final List<PptxSlide> slides;
  final double slideWidthEmu;
  final double slideHeightEmu;

  const PptxPresentation({
    required this.slides,
    this.slideWidthEmu = 12192000.0, // Default 16:9 Widescreen in EMUs
    this.slideHeightEmu = 6858000.0,
  });

  double get aspectRatio =>
      (slideHeightEmu > 0) ? (slideWidthEmu / slideHeightEmu).clamp(1.2, 2.2) : (16.0 / 9.0);
}

class PptxParser {
  static PptxPresentation parse(Uint8List pptxBytes) {
    final archive = ZipDecoder().decodeBytes(pptxBytes);

    // 1. Read presentation.xml for exact slide EMU dimensions (cx, cy)
    double slideWidthEmu = 12192000.0;
    double slideHeightEmu = 6858000.0;
    final presFile = archive.findFile('ppt/presentation.xml');
    if (presFile != null) {
      try {
        final presDoc = XmlDocument.parse(utf8.decode(presFile.content as List<int>, allowMalformed: true));
        final sldSz = presDoc.findAllElements('p:sldSz').firstOrNull;
        if (sldSz != null) {
          final cx = double.tryParse(sldSz.getAttribute('cx') ?? '');
          final cy = double.tryParse(sldSz.getAttribute('cy') ?? '');
          if (cx != null && cx > 100000) slideWidthEmu = cx;
          if (cy != null && cy > 100000) slideHeightEmu = cy;
        }
      } catch (_) {}
    }

    // 2. Discover all slides in archive
    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') &&
            f.name.endsWith('.xml') &&
            !f.name.contains('_rels'))
        .toList();

    slideFiles.sort((a, b) {
      final numA = _extractSlideNumber(a.name);
      final numB = _extractSlideNumber(b.name);
      return numA.compareTo(numB);
    });

    final slides = <PptxSlide>[];

    for (int i = 0; i < slideFiles.length; i++) {
      final sf = slideFiles[i];
      final slideNum = i + 1;

      // Extract relationships for this slide (images & notes)
      final relsPath = 'ppt/slides/_rels/${sf.name.split('/').last}.rels';
      final relsFile = archive.findFile(relsPath);
      final slideImageMap = <String, String>{};
      String? notesTarget;

      if (relsFile != null) {
        try {
          final relsDoc = XmlDocument.parse(utf8.decode(relsFile.content as List<int>, allowMalformed: true));
          for (final rel in relsDoc.findAllElements('Relationship')) {
            final id = rel.getAttribute('Id');
            final target = rel.getAttribute('Target');
            final type = rel.getAttribute('Type') ?? '';
            if (id == null || target == null) continue;

            if (type.contains('image')) {
              final mediaPath = target.startsWith('../')
                  ? 'ppt/${target.replaceFirst('../', '')}'
                  : (target.startsWith('ppt/') ? target : 'ppt/slides/$target');
              ArchiveFile? mediaFile = archive.findFile(mediaPath);
              mediaFile ??= archive.findFile('ppt/media/${target.split('/').last}');
              if (mediaFile != null) {
                final bytes = mediaFile.content as List<int>;
                final ext = target.split('.').last.toLowerCase();
                final mime = (ext == 'jpg' || ext == 'jpeg')
                    ? 'image/jpeg'
                    : (ext == 'gif' ? 'image/gif' : 'image/png');
                slideImageMap[id] = 'data:$mime;base64,${base64Encode(bytes)}';
              }
            } else if (type.contains('notesSlide')) {
              notesTarget = target.startsWith('../')
                  ? 'ppt/${target.replaceFirst('../', '')}'
                  : 'ppt/notesSlides/${target.split('/').last}';
            }
          }
        } catch (_) {}
      }

      // Extract speaker notes if available
      String speakerNotes = '';
      if (notesTarget != null) {
        final notesFile = archive.findFile(notesTarget);
        if (notesFile != null) {
          try {
            final notesDoc = XmlDocument.parse(utf8.decode(notesFile.content as List<int>, allowMalformed: true));
            final lines = <String>[];
            for (final p in notesDoc.findAllElements('a:p')) {
              final line = p.findAllElements('a:t').map((e) => e.innerText).join().trim();
              if (line.isNotEmpty && line != '$slideNum') {
                lines.add(line);
              }
            }
            speakerNotes = lines.join('\n');
          } catch (_) {}
        }
      }

      String slideTitle = '';
      final bulletPoints = <String>[];
      final images = <String>[];
      final elements = <PptxSlideElement>[];
      String? bgColorHex;

      try {
        final slideDoc = XmlDocument.parse(utf8.decode(sf.content as List<int>, allowMalformed: true));

        // Check slide background solid fill
        final bgElem = slideDoc.findAllElements('p:bg').firstOrNull;
        if (bgElem != null) {
          final srgb = bgElem.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val');
          if (srgb != null && srgb.length == 6) {
            bgColorHex = srgb;
          }
        }

        final spTree = slideDoc.findAllElements('p:spTree').firstOrNull ?? slideDoc.rootElement;

        for (final node in spTree.children.whereType<XmlElement>()) {
          final localName = node.name.local;

          if (localName == 'sp') {
            final elem = _parseShapeElement(
              node,
              slideWidthEmu,
              slideHeightEmu,
              onTitleFound: (t) {
                if (slideTitle.isEmpty) slideTitle = t;
              },
              onBulletFound: (b) => bulletPoints.add(b),
            );
            if (elem != null) elements.add(elem);
          } else if (localName == 'pic') {
            final picElem = _parsePictureElement(node, slideImageMap, slideWidthEmu, slideHeightEmu);
            if (picElem != null) {
              elements.add(picElem);
              if (picElem.imageDataUrl != null) {
                images.add(picElem.imageDataUrl!);
              }
            }
          } else if (localName == 'graphicFrame') {
            final tblElem = _parseGraphicFrameTable(node, slideWidthEmu, slideHeightEmu);
            if (tblElem != null) {
              elements.add(tblElem);
              for (final row in tblElem.tableRows) {
                final joined = row.where((c) => c.trim().isNotEmpty).join(' | ');
                if (joined.isNotEmpty) bulletPoints.add(joined);
              }
            }
          } else if (localName == 'grpSp') {
            // Group shape: iterate children inside group
            for (final sub in node.findAllElements('p:sp')) {
              final elem = _parseShapeElement(
                sub,
                slideWidthEmu,
                slideHeightEmu,
                onTitleFound: (t) {
                  if (slideTitle.isEmpty) slideTitle = t;
                },
                onBulletFound: (b) => bulletPoints.add(b),
              );
              if (elem != null) elements.add(elem);
            }
            for (final subPic in node.findAllElements('p:pic')) {
              final picElem = _parsePictureElement(subPic, slideImageMap, slideWidthEmu, slideHeightEmu);
              if (picElem != null) {
                elements.add(picElem);
                if (picElem.imageDataUrl != null) images.add(picElem.imageDataUrl!);
              }
            }
          }
        }

        // Fallback: if any blip wasn't inside a top-level pic
        if (images.isEmpty) {
          for (final blip in slideDoc.findAllElements('a:blip')) {
            final embedId = blip.getAttribute('r:embed');
            if (embedId != null && slideImageMap.containsKey(embedId)) {
              final dataUrl = slideImageMap[embedId]!;
              if (!images.contains(dataUrl)) {
                images.add(dataUrl);
              }
            }
          }
        }
      } catch (_) {}

      if (slideTitle.isEmpty) {
        slideTitle = 'شريحة $slideNum';
      }

      slides.add(PptxSlide(
        slideNumber: slideNum,
        title: slideTitle,
        bulletPoints: bulletPoints,
        images: images,
        elements: elements,
        backgroundColorHex: bgColorHex,
        speakerNotes: speakerNotes,
      ));
    }

    return PptxPresentation(
      slides: slides,
      slideWidthEmu: slideWidthEmu,
      slideHeightEmu: slideHeightEmu,
    );
  }

  static PptxSlideElement? _parseShapeElement(
    XmlElement sp,
    double slideW,
    double slideH, {
    required void Function(String) onTitleFound,
    required void Function(String) onBulletFound,
  }) {
    final txBody = sp.findElements('p:txBody').firstOrNull;
    final spPr = sp.findElements('p:spPr').firstOrNull;

    final ph = sp.findAllElements('p:ph').firstOrNull;
    final phType = ph?.getAttribute('type') ?? '';
    final isTitle = phType == 'title' || phType == 'ctrTitle';

    final coords = _extractXfrmCoords(spPr, slideW, slideH, isTitle: isTitle);

    String? fillHex;
    if (spPr != null) {
      final solidFill = spPr.findElements('a:solidFill').firstOrNull;
      fillHex = solidFill?.findElements('a:srgbClr').firstOrNull?.getAttribute('val');
    }

    final paragraphs = <PptxTextParagraph>[];
    if (txBody != null) {
      for (final p in txBody.findElements('a:p')) {
        final text = p.findAllElements('a:t').map((e) => e.innerText).join().trim();
        if (text.isEmpty) continue;

        final pPr = p.findElements('a:pPr').firstOrNull;
        final algn = pPr?.getAttribute('algn') ?? (isTitle ? 'ctr' : 'l');
        final alignStr = algn == 'ctr' ? 'center' : (algn == 'r' ? 'right' : 'left');
        final hasBullet = pPr?.findElements('a:buChar').isNotEmpty == true ||
            pPr?.findElements('a:buAutoNum').isNotEmpty == true ||
            (!isTitle && phType == 'body');

        bool isBold = isTitle;
        bool isItalic = false;
        double? fontSizePt;
        String? colorHex;

        final rPr = p.findAllElements('a:rPr').firstOrNull;
        if (rPr != null) {
          if (rPr.getAttribute('b') == '1') isBold = true;
          if (rPr.getAttribute('i') == '1') isItalic = true;
          final sz = double.tryParse(rPr.getAttribute('sz') ?? '');
          if (sz != null && sz > 100) {
            fontSizePt = (sz / 100.0).clamp(9.0, 44.0);
          }
          colorHex = rPr.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val');
        }

        if (isTitle) {
          onTitleFound(text);
        } else {
          onBulletFound(text);
        }

        paragraphs.add(PptxTextParagraph(
          text: text,
          isBold: isBold,
          isItalic: isItalic,
          fontSizePt: fontSizePt,
          colorHex: colorHex,
          align: alignStr,
          isBullet: hasBullet && !isTitle,
        ));
      }
    }

    if (paragraphs.isEmpty && fillHex == null) return null;

    return PptxSlideElement(
      type: PptxElementType.textBox,
      xFrac: coords.$1,
      yFrac: coords.$2,
      wFrac: coords.$3,
      hFrac: coords.$4,
      fillColorHex: fillHex,
      isTitle: isTitle,
      paragraphs: paragraphs,
    );
  }

  static PptxSlideElement? _parsePictureElement(
    XmlElement pic,
    Map<String, String> slideImageMap,
    double slideW,
    double slideH,
  ) {
    final blip = pic.findAllElements('a:blip').firstOrNull;
    final embedId = blip?.getAttribute('r:embed');
    if (embedId == null || !slideImageMap.containsKey(embedId)) return null;

    final spPr = pic.findElements('p:spPr').firstOrNull;
    final coords = _extractXfrmCoords(spPr, slideW, slideH, isTitle: false, isImage: true);

    return PptxSlideElement(
      type: PptxElementType.image,
      xFrac: coords.$1,
      yFrac: coords.$2,
      wFrac: coords.$3,
      hFrac: coords.$4,
      imageDataUrl: slideImageMap[embedId],
    );
  }

  static PptxSlideElement? _parseGraphicFrameTable(
    XmlElement frame,
    double slideW,
    double slideH,
  ) {
    final tbl = frame.findAllElements('a:tbl').firstOrNull;
    if (tbl == null) return null;

    final rows = <List<String>>[];
    for (final tr in tbl.findElements('a:tr')) {
      final rowCells = <String>[];
      for (final tc in tr.findElements('a:tc')) {
        final cellText = tc.findAllElements('a:t').map((e) => e.innerText).join(' ').trim();
        rowCells.add(cellText);
      }
      if (rowCells.isNotEmpty) rows.add(rowCells);
    }
    if (rows.isEmpty) return null;

    final xfrm = frame.findElements('p:xfrm').firstOrNull;
    final coords = _extractXfrmCoordsFromElement(xfrm, slideW, slideH);

    return PptxSlideElement(
      type: PptxElementType.table,
      xFrac: coords.$1,
      yFrac: coords.$2,
      wFrac: coords.$3,
      hFrac: coords.$4,
      tableRows: rows,
    );
  }

  static (double, double, double, double) _extractXfrmCoords(
    XmlElement? spPr,
    double slideW,
    double slideH, {
    bool isTitle = false,
    bool isImage = false,
  }) {
    final xfrm = spPr?.findElements('a:xfrm').firstOrNull;
    return _extractXfrmCoordsFromElement(xfrm, slideW, slideH, isTitle: isTitle, isImage: isImage);
  }

  static (double, double, double, double) _extractXfrmCoordsFromElement(
    XmlElement? xfrm,
    double slideW,
    double slideH, {
    bool isTitle = false,
    bool isImage = false,
  }) {
    if (xfrm != null) {
      final off = xfrm.findElements('a:off').firstOrNull;
      final ext = xfrm.findElements('a:ext').firstOrNull;
      final x = double.tryParse(off?.getAttribute('x') ?? '');
      final y = double.tryParse(off?.getAttribute('y') ?? '');
      final cx = double.tryParse(ext?.getAttribute('cx') ?? '');
      final cy = double.tryParse(ext?.getAttribute('cy') ?? '');

      if (x != null && y != null && cx != null && cy != null && cx > 0 && cy > 0) {
        final xf = (x / slideW).clamp(0.0, 0.92);
        final yf = (y / slideH).clamp(0.0, 0.92);
        final wf = (cx / slideW).clamp(0.08, 1.0 - xf);
        final hf = (cy / slideH).clamp(0.06, 1.0 - yf);
        return (xf, yf, wf, hf);
      }
    }

    // Fallback default positions if placeholder lacks explicit xfrm (inherits from slideLayout)
    if (isTitle) {
      return (0.06, 0.07, 0.88, 0.20);
    } else if (isImage) {
      return (0.52, 0.26, 0.42, 0.62);
    } else {
      return (0.06, 0.28, 0.88, 0.64);
    }
  }

  static int _extractSlideNumber(String path) {
    final fileName = path.split('/').last;
    final digits = RegExp(r'\d+').firstMatch(fileName)?.group(0);
    return digits != null ? int.tryParse(digits) ?? 0 : 0;
  }
}

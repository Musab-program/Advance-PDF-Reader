import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxCell {
  final int row;
  final int col;
  final String value;
  final String? formula;
  final bool isNumeric;
  final bool isBold;
  final String? bgColorHex;
  final String? textColorHex;
  final int colSpan;
  final int rowSpan;

  const XlsxCell({
    required this.row,
    required this.col,
    required this.value,
    this.formula,
    this.isNumeric = false,
    this.isBold = false,
    this.bgColorHex,
    this.textColorHex,
    this.colSpan = 1,
    this.rowSpan = 1,
  });
}

class XlsxSheet {
  final String name;
  final Map<int, Map<int, XlsxCell>> cells; // row -> (col -> XlsxCell)
  final int maxRow;
  final int maxCol;

  const XlsxSheet({
    required this.name,
    required this.cells,
    required this.maxRow,
    required this.maxCol,
  });

  String getCell(int r, int c) => cells[r]?[c]?.value ?? '';

  XlsxCell? getCellObject(int r, int c) => cells[r]?[c];
}

class XlsxWorkbook {
  final List<XlsxSheet> sheets;

  const XlsxWorkbook({required this.sheets});
}

class XlsxParser {
  /// Parses an `.xlsx` / `.xltx` workbook archive into sheets, cells, formulas, and basic styles.
  static XlsxWorkbook parse(Uint8List xlsxBytes) {
    final archive = ZipDecoder().decodeBytes(xlsxBytes);

    // 1. Parse sharedStrings.xml
    final sharedStrings = <String>[];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      try {
        final ssXml = utf8.decode(ssFile.content as List<int>, allowMalformed: true);
        final ssDoc = XmlDocument.parse(ssXml);
        for (final si in ssDoc.findAllElements('si')) {
          final tElements = si.findAllElements('t').map((e) => e.innerText).join();
          sharedStrings.add(tElements);
        }
      } catch (_) {}
    }

    // 2. Parse xl/styles.xml for basic bold / fill / number-format detection
    final cellStyleFormats = <_XlsxStyleFormat>[];
    final stylesFile = archive.findFile('xl/styles.xml');
    if (stylesFile != null) {
      try {
        final stylesXml = utf8.decode(stylesFile.content as List<int>, allowMalformed: true);
        final stylesDoc = XmlDocument.parse(stylesXml);

        // Extract fonts (bold & color)
        final fonts = <(bool, String?)>[];
        final fontsElem = stylesDoc.findAllElements('fonts').firstOrNull;
        if (fontsElem != null) {
          for (final f in fontsElem.findElements('font')) {
            final isB = f.findElements('b').isNotEmpty;
            String? colHex = f.findElements('color').firstOrNull?.getAttribute('rgb');
            if (colHex != null && colHex.length == 8) colHex = colHex.substring(2);
            fonts.add((isB, colHex));
          }
        }

        // Extract fills (background colors)
        final fills = <String?>[];
        final fillsElem = stylesDoc.findAllElements('fills').firstOrNull;
        if (fillsElem != null) {
          for (final fl in fillsElem.findElements('fill')) {
            final pat = fl.findElements('patternFill').firstOrNull;
            String? fgHex = pat?.findElements('fgColor').firstOrNull?.getAttribute('rgb');
            if (fgHex != null && fgHex.length == 8) fgHex = fgHex.substring(2);
            fills.add(fgHex);
          }
        }

        // Extract cellXfs
        final cellXfs = stylesDoc.findAllElements('cellXfs').firstOrNull;
        if (cellXfs != null) {
          for (final xf in cellXfs.findElements('xf')) {
            final fontId = int.tryParse(xf.getAttribute('fontId') ?? '0') ?? 0;
            final fillId = int.tryParse(xf.getAttribute('fillId') ?? '0') ?? 0;
            final numFmtId = int.tryParse(xf.getAttribute('numFmtId') ?? '0') ?? 0;

            final fontInfo = (fontId >= 0 && fontId < fonts.length) ? fonts[fontId] : (false, null);
            final fillHex = (fillId >= 0 && fillId < fills.length) ? fills[fillId] : null;
            final isDateFmt = (numFmtId >= 14 && numFmtId <= 22) || (numFmtId >= 45 && numFmtId <= 47);

            cellStyleFormats.add(_XlsxStyleFormat(
              isBold: fontInfo.$1,
              textColorHex: fontInfo.$2,
              bgColorHex: fillHex,
              isDateFormat: isDateFmt,
            ));
          }
        }
      } catch (_) {}
    }

    // 3. Parse workbook.xml relationships to find sheet filenames
    final sheetRels = <String, String>{};
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    if (relsFile != null) {
      try {
        final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
        final relsDoc = XmlDocument.parse(relsXml);
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) {
            sheetRels[id] = target.startsWith('/')
                ? target.substring(1)
                : (target.startsWith('xl/') ? target : 'xl/$target');
          }
        }
      } catch (_) {}
    }

    // 4. Parse workbook.xml for sheet names
    final sheets = <XlsxSheet>[];
    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile != null) {
      try {
        final wbXml = utf8.decode(wbFile.content as List<int>, allowMalformed: true);
        final wbDoc = XmlDocument.parse(wbXml);
        for (final sheetElem in wbDoc.findAllElements('sheet')) {
          final name = sheetElem.getAttribute('name') ?? 'Sheet';
          final rId = sheetElem.getAttribute('r:id');
          final target = sheetRels[rId];
          if (target != null) {
            final sheetFile = archive.findFile(target);
            if (sheetFile != null) {
              final parsedSheet = _parseSheet(
                name,
                sheetFile.content as List<int>,
                sharedStrings,
                cellStyleFormats,
              );
              sheets.add(parsedSheet);
            }
          }
        }
      } catch (_) {}
    }

    if (sheets.isEmpty) {
      for (final file in archive.files) {
        if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          final name = 'ورقة ${sheets.length + 1}';
          sheets.add(_parseSheet(
            name,
            file.content as List<int>,
            sharedStrings,
            cellStyleFormats,
          ));
        }
      }
    }

    return XlsxWorkbook(sheets: sheets);
  }

  /// Parses a `.csv` file directly into an `XlsxWorkbook` so it uses the exact same
  /// high-speed 2D Virtual Grid Engine as Excel files.
  static XlsxWorkbook parseCsv(String csvContent, {String sheetName = 'CSV Data'}) {
    final cells = <int, Map<int, XlsxCell>>{};
    int maxR = 0;
    int maxC = 0;

    final lines = const LineSplitter().convert(csvContent);
    for (int r = 0; r < lines.length; r++) {
      final line = lines[r];
      if (line.trim().isEmpty && r == lines.length - 1) continue;
      final rowValues = _splitCsvLine(line);
      for (int c = 0; c < rowValues.length; c++) {
        final val = rowValues[c].trim();
        if (val.isNotEmpty) {
          final numVal = double.tryParse(val.replaceAll(',', ''));
          cells.putIfAbsent(r, () => {})[c] = XlsxCell(
            row: r,
            col: c,
            value: val,
            isNumeric: numVal != null,
            isBold: r == 0,
          );
          if (r > maxR) maxR = r;
          if (c > maxC) maxC = c;
        }
      }
    }

    return XlsxWorkbook(
      sheets: [
        XlsxSheet(
          name: sheetName,
          cells: cells,
          maxRow: maxR + 1,
          maxCol: maxC + 1,
        ),
      ],
    );
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    final delimiter = line.contains(';') && !line.contains(',') ? ';' : ',';

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString());
    return result;
  }

  static XlsxSheet _parseSheet(
    String name,
    List<int> content,
    List<String> sharedStrings,
    List<_XlsxStyleFormat> styleFormats,
  ) {
    final cells = <int, Map<int, XlsxCell>>{};
    int maxR = 0;
    int maxC = 0;

    try {
      final xmlStr = utf8.decode(content, allowMalformed: true);
      final doc = XmlDocument.parse(xmlStr);

      for (final rowElem in doc.findAllElements('row')) {
        final rStr = rowElem.getAttribute('r');
        int rowIdx = rStr != null ? (int.tryParse(rStr) ?? 1) - 1 : 0;

        for (final cElem in rowElem.findAllElements('c')) {
          final ref = cElem.getAttribute('r');
          int colIdx = 0;
          if (ref != null) {
            final parsed = _parseCellRef(ref);
            rowIdx = parsed.$1;
            colIdx = parsed.$2;
          }

          final type = cElem.getAttribute('t');
          final styleIdx = int.tryParse(cElem.getAttribute('s') ?? '');
          final styleFmt = (styleIdx != null && styleIdx >= 0 && styleIdx < styleFormats.length)
              ? styleFormats[styleIdx]
              : null;

          final formulaText = cElem.findElements('f').firstOrNull?.innerText;
          String val = '';
          bool isNumeric = false;

          if (type == 's') {
            final v = cElem.findElements('v').firstOrNull?.innerText;
            final idx = int.tryParse(v ?? '');
            if (idx != null && idx >= 0 && idx < sharedStrings.length) {
              val = sharedStrings[idx];
            }
          } else if (type == 'inlineStr') {
            val = cElem.findAllElements('t').map((e) => e.innerText).join();
          } else if (type == 'b') {
            final v = cElem.findElements('v').firstOrNull?.innerText;
            val = (v == '1' || v == 'true') ? 'TRUE' : 'FALSE';
          } else if (type == 'str' || type == 'e') {
            val = cElem.findElements('v').firstOrNull?.innerText ?? '';
          } else {
            final rawV = cElem.findElements('v').firstOrNull?.innerText ?? '';
            if (rawV.isNotEmpty) {
              final numParsed = double.tryParse(rawV);
              if (numParsed != null) {
                if (styleFmt != null && styleFmt.isDateFormat && numParsed > 20000 && numParsed < 80000) {
                  // Excel serial date (days since 1899-12-30)
                  final date = DateTime(1899, 12, 30).add(Duration(days: numParsed.floor()));
                  val = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                } else {
                  isNumeric = true;
                  val = _formatCleanNumber(numParsed, rawV);
                }
              } else {
                val = rawV;
              }
            }
          }

          if (val.isNotEmpty || (formulaText != null && formulaText.isNotEmpty)) {
            cells.putIfAbsent(rowIdx, () => {})[colIdx] = XlsxCell(
              row: rowIdx,
              col: colIdx,
              value: val.isNotEmpty ? val : '=$formulaText',
              formula: formulaText != null && formulaText.isNotEmpty ? '=$formulaText' : null,
              isNumeric: isNumeric,
              isBold: styleFmt?.isBold ?? false,
              bgColorHex: styleFmt?.bgColorHex,
              textColorHex: styleFmt?.textColorHex,
            );
            if (rowIdx > maxR) maxR = rowIdx;
            if (colIdx > maxC) maxC = colIdx;
          }
        }
      }
    } catch (_) {}

    return XlsxSheet(
      name: name,
      cells: cells,
      maxRow: maxR + 1,
      maxCol: maxC + 1,
    );
  }

  static String _formatCleanNumber(double n, String raw) {
    if (n == n.roundToDouble() && !raw.contains('E') && !raw.contains('e')) {
      return n.toInt().toString();
    }
    // Avoid floating point precision noise like 12.300000000000001
    final fixed = double.parse(n.toStringAsFixed(6));
    return fixed.toString();
  }

  /// Parses "B14" into (row: 13, col: 1)
  static (int, int) _parseCellRef(String ref) {
    int col = 0;
    int row = 0;
    int i = 0;

    while (i < ref.length && ref.codeUnitAt(i) >= 65 && ref.codeUnitAt(i) <= 90) {
      col = col * 26 + (ref.codeUnitAt(i) - 64);
      i++;
    }
    col = (col > 0) ? col - 1 : 0;

    if (i < ref.length) {
      row = (int.tryParse(ref.substring(i)) ?? 1) - 1;
    }

    return (row, col);
  }

  static String colToLetter(int colIndex) {
    String result = '';
    int c = colIndex + 1;
    while (c > 0) {
      int rem = (c - 1) % 26;
      result = String.fromCharCode(65 + rem) + result;
      c = (c - 1) ~/ 26;
    }
    return result;
  }
}

class _XlsxStyleFormat {
  final bool isBold;
  final String? textColorHex;
  final String? bgColorHex;
  final bool isDateFormat;

  const _XlsxStyleFormat({
    this.isBold = false,
    this.textColorHex,
    this.bgColorHex,
    this.isDateFormat = false,
  });
}

import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;

void main() {
  group('PDF Tools Backend Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pdf_tools_unit_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<File> createDummyPdf(String name, int pageCount) async {
      final doc = PdfDocument();
      for (int i = 1; i <= pageCount; i++) {
        final page = doc.pages.add();
        page.graphics.drawString(
          'Document $name - Page $i',
          PdfStandardFont(PdfFontFamily.helvetica, 16),
        );
      }
      final file = File('${tempDir.path}/$name.pdf');
      await file.writeAsBytes(await doc.save());
      doc.dispose();
      return file;
    }

    test('1. Merge multiple PDFs in specified order', () async {
      final fileA = await createDummyPdf('fileA', 2);
      final fileB = await createDummyPdf('fileB', 3);

      final mergedDoc = PdfDocument();
      final orderedPaths = [fileB.path, fileA.path]; // B first, then A

      for (final path in orderedPaths) {
        final src = PdfDocument(inputBytes: await File(path).readAsBytes());
        for (int i = 0; i < src.pages.count; i++) {
          final template = src.pages[i].createTemplate();
          final page = mergedDoc.pages.add();
          page.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        src.dispose();
      }

      final outPath = '${tempDir.path}/merged_output.pdf';
      await File(outPath).writeAsBytes(await mergedDoc.save());
      mergedDoc.dispose();

      final verifyDoc = PdfDocument(inputBytes: await File(outPath).readAsBytes());
      expect(verifyDoc.pages.count, 5);
      verifyDoc.dispose();
    });

    test('2. Split PDF by page ranges', () async {
      final source = await createDummyPdf('source_5p', 5);

      // Split into 1-2 and 3-5
      final ranges = [
        [0, 1], // pages 1 and 2
        [2, 3, 4], // pages 3, 4, 5
      ];

      final srcDoc = PdfDocument(inputBytes: await source.readAsBytes());

      for (int r = 0; r < ranges.length; r++) {
        final splitDoc = PdfDocument();
        for (final pageIdx in ranges[r]) {
          final template = srcDoc.pages[pageIdx].createTemplate();
          final page = splitDoc.pages.add();
          page.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        final splitFile = File('${tempDir.path}/split_part_${r + 1}.pdf');
        await splitFile.writeAsBytes(await splitDoc.save());
        splitDoc.dispose();

        final check = PdfDocument(inputBytes: await splitFile.readAsBytes());
        expect(check.pages.count, ranges[r].length);
        check.dispose();
      }

      srcDoc.dispose();
    });

    test('3. Organize PDF pages (delete, reorder, extract)', () async {
      final source = await createDummyPdf('org_source', 4); // pages: 0, 1, 2, 3

      // Reorder and delete: keep only pages 3 and 1 in order [3, 1]
      final selectedOrder = [3, 1];

      final srcDoc = PdfDocument(inputBytes: await source.readAsBytes());
      final newDoc = PdfDocument();

      for (final idx in selectedOrder) {
        final template = srcDoc.pages[idx].createTemplate();
        final page = newDoc.pages.add();
        page.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      srcDoc.dispose();

      final outPath = '${tempDir.path}/organized_output.pdf';
      await File(outPath).writeAsBytes(await newDoc.save());
      newDoc.dispose();

      final check = PdfDocument(inputBytes: await File(outPath).readAsBytes());
      expect(check.pages.count, 2);
      check.dispose();
    });

    test('4. Images to PDF conversion', () async {
      // Create 2 test images
      final img1 = img.Image(width: 400, height: 300);
      img.fill(img1, color: img.ColorRgb8(255, 0, 0));
      final imgFile1 = File('${tempDir.path}/img1.jpg')..writeAsBytesSync(img.encodeJpg(img1));

      final img2 = img.Image(width: 300, height: 400);
      img.fill(img2, color: img.ColorRgb8(0, 255, 0));
      final imgFile2 = File('${tempDir.path}/img2.png')..writeAsBytesSync(img.encodePng(img2));

      final pdfDoc = PdfDocument();
      for (final imgFile in [imgFile1, imgFile2]) {
        final bytes = await imgFile.readAsBytes();
        final bitmap = PdfBitmap(bytes);
        final page = pdfDoc.pages.add();
        // Fit image within page size while maintaining aspect ratio
        final pageWidth = page.size.width;
        final pageHeight = page.size.height;
        final imgWidth = bitmap.width.toDouble();
        final imgHeight = bitmap.height.toDouble();

        double renderW = pageWidth;
        double renderH = (pageWidth / imgWidth) * imgHeight;
        if (renderH > pageHeight) {
          renderH = pageHeight;
          renderW = (pageHeight / imgHeight) * imgWidth;
        }

        final x = (pageWidth - renderW) / 2;
        final y = (pageHeight - renderH) / 2;

        page.graphics.drawImage(bitmap, Rect.fromLTWH(x, y, renderW, renderH));
      }

      final outPath = '${tempDir.path}/from_images.pdf';
      await File(outPath).writeAsBytes(await pdfDoc.save());
      pdfDoc.dispose();

      final check = PdfDocument(inputBytes: await File(outPath).readAsBytes());
      expect(check.pages.count, 2);
      check.dispose();
    });
  });
}

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

    test('5. Page dimensions and rotation preservation in section', () async {
      final doc = PdfDocument();
      doc.pageSettings.margins.all = 0;
      final sec1 = doc.sections!.add();
      sec1.pageSettings.margins.all = 0;
      sec1.pageSettings.size = const Size(800, 600); // Landscape
      sec1.pageSettings.orientation = PdfPageOrientation.landscape;
      final p1 = sec1.pages.add();
      p1.graphics.drawString('Landscape Page', PdfStandardFont(PdfFontFamily.helvetica, 16));

      final sec2 = doc.sections!.add();
      sec2.pageSettings.margins.all = 0;
      sec2.pageSettings.size = const Size(400, 600); // Portrait
      sec2.pageSettings.orientation = PdfPageOrientation.portrait;
      final p2 = sec2.pages.add();
      p2.graphics.drawString('Portrait Page', PdfStandardFont(PdfFontFamily.helvetica, 16));

      final bytes = await doc.save();
      doc.dispose();

      // Read back
      final readDoc = PdfDocument(inputBytes: bytes);
      expect(readDoc.pages.count, 2);
      expect(readDoc.pages[0].size.width, 800);
      expect(readDoc.pages[0].size.height, 600);
      expect(readDoc.pages[1].size.width, 400);
      expect(readDoc.pages[1].size.height, 600);

      // Copying to targetDoc preserving section and zero margins
      final targetDoc = PdfDocument();
      targetDoc.pageSettings.margins.all = 0;
      for (int i = 0; i < readDoc.pages.count; i++) {
        final srcPage = readDoc.pages[i];
        final section = targetDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = srcPage.size;
        section.pageSettings.orientation = srcPage.size.width > srcPage.size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;
        final newPage = section.pages.add();
        newPage.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero, srcPage.size);
      }
      final targetBytes = await targetDoc.save();
      targetDoc.dispose();
      readDoc.dispose();

      final verifyTarget = PdfDocument(inputBytes: targetBytes);
      expect(verifyTarget.pages.count, 2);
      expect(verifyTarget.pages[0].size.width, 800);
      expect(verifyTarget.pages[0].size.height, 600);
      expect(verifyTarget.pages[1].size.width, 400);
      expect(verifyTarget.pages[1].size.height, 600);
      verifyTarget.dispose();
    });

    test('6. Rotation preservation and combining turns', () async {
      int getRotationTurns(PdfPageRotateAngle angle) {
        switch (angle) {
          case PdfPageRotateAngle.rotateAngle90:
            return 1;
          case PdfPageRotateAngle.rotateAngle180:
            return 2;
          case PdfPageRotateAngle.rotateAngle270:
            return 3;
          case PdfPageRotateAngle.rotateAngle0:
          default:
            return 0;
        }
      }

      PdfPageRotateAngle getAngleFromTurns(int turns) {
        switch (turns % 4) {
          case 1:
            return PdfPageRotateAngle.rotateAngle90;
          case 2:
            return PdfPageRotateAngle.rotateAngle180;
          case 3:
            return PdfPageRotateAngle.rotateAngle270;
          case 0:
          default:
            return PdfPageRotateAngle.rotateAngle0;
        }
      }

      final doc = PdfDocument();
      doc.pageSettings.margins.all = 0;
      final sec = doc.sections!.add();
      sec.pageSettings.margins.all = 0;
      sec.pageSettings.size = const Size(500, 700);
      sec.pageSettings.rotate = PdfPageRotateAngle.rotateAngle90;
      sec.pages.add();

      final bytes = await doc.save();
      doc.dispose();

      final readDoc = PdfDocument(inputBytes: bytes);
      final srcP = readDoc.pages[0];
      expect(srcP.rotation, PdfPageRotateAngle.rotateAngle90);
      final origTurns = getRotationTurns(srcP.rotation);
      expect(origTurns, 1);

      // User adds 1 turn (90 deg) in Organize: total should be 2 turns (180 deg)
      final userTurns = 1;
      final totalTurns = (origTurns + userTurns) % 4;
      expect(totalTurns, 2);

      final targetDoc = PdfDocument();
      targetDoc.pageSettings.margins.all = 0;
      final targetSec = targetDoc.sections!.add();
      targetSec.pageSettings.margins.all = 0;
      targetSec.pageSettings.size = srcP.size;
      targetSec.pageSettings.orientation = srcP.size.width > srcP.size.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;
      targetSec.pageSettings.rotate = getAngleFromTurns(totalTurns);
      final newPage = targetSec.pages.add();
      newPage.graphics.drawPdfTemplate(srcP.createTemplate(), Offset.zero, srcP.size);

      final targetBytes = await targetDoc.save();
      targetDoc.dispose();
      readDoc.dispose();

      final verify = PdfDocument(inputBytes: targetBytes);
      expect(verify.pages[0].rotation, PdfPageRotateAngle.rotateAngle180);
      verify.dispose();
    });
  });
}

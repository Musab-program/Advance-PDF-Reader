import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_reader/core/utils/pdf_text_layout.dart';
import 'package:pdf_reader/modules/document_editor/controllers/document_editor_controller.dart';
import 'package:pdf_reader/modules/document_editor/models/editor_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Document Editor (WPS Tools) Suite Tests', () {
    late Directory tempDir;
    late File samplePdf;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('doc_editor_test_');

      // Create a sample multi-page PDF with text
      final doc = sf.PdfDocument();
      for (int i = 1; i <= 3; i++) {
        final page = doc.pages.add();
        page.graphics.drawString(
          'Sample Test Page $i: Architecture Deep Dive Content',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 16),
          bounds: const Rect.fromLTWH(50, 50, 400, 30),
        );
      }

      samplePdf = File('${tempDir.path}/test_document.pdf');
      await samplePdf.writeAsBytes(doc.saveSync());
      doc.dispose();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Document Loading and Basic State', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      expect(controller.filePath.value, samplePdf.path);
      expect(controller.fileName.value, 'test_document.pdf');
      expect(controller.totalPages.value, 3);
      expect(controller.currentPage.value, 1);
      expect(controller.strokes.isEmpty, true);
      expect(controller.stamps.isEmpty, true);
      expect(controller.activeTab.value, EditorTab.none);
    });

    test('2. Tab Switching Architecture (WPS Enum Tabs)', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      // Switch to Annotate tab
      controller.switchTab(EditorTab.annotate);
      expect(controller.activeTab.value, EditorTab.annotate);
      expect(controller.isDrawingModeActive.value, true);

      // Switch to Fill & Sign tab
      controller.switchTab(EditorTab.fillSign);
      expect(controller.activeTab.value, EditorTab.fillSign);
      expect(controller.isDrawingModeActive.value, false);

      // Switch to Edit tab
      controller.switchTab(EditorTab.edit);
      expect(controller.activeTab.value, EditorTab.edit);

      // Switch to Convert tab
      controller.switchTab(EditorTab.convert);
      expect(controller.activeTab.value, EditorTab.convert);

      // Toggle off
      controller.switchTab(EditorTab.convert);
      expect(controller.activeTab.value, EditorTab.none);
    });

    test('3. Annotate Group: Pen Drawing, Highlighting, and Eraser', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      // 3.1 Pen drawing
      controller.selectAnnotateTool(AnnotateTool.pen);
      controller.setDrawingColor(const Color(0xFFDC2626)); // Red
      controller.setStrokeWidth(3.0);

      controller.startDrawing(const Offset(10, 10), 0);
      controller.updateDrawing(const Offset(20, 20));
      controller.updateDrawing(const Offset(30, 30));
      controller.endDrawing(0, const Size(350, 500)); // page index 0

      expect(controller.strokes.length, 1);
      expect(controller.strokes.first.points.length, 3);
      expect(controller.strokes.first.isHighlighter, false);
      expect(controller.strokes.first.pageIndex, 0);

      // 3.2 Highlighter drawing
      controller.selectAnnotateTool(AnnotateTool.highlighter);
      controller.startDrawing(const Offset(50, 50), 0);
      controller.updateDrawing(const Offset(100, 50));
      controller.endDrawing(0, const Size(350, 500));

      expect(controller.strokes.length, 2);
      expect(controller.strokes.last.isHighlighter, true);

      // 3.3 Undo / Redo for Annotations
      controller.undo();
      expect(controller.strokes.length, 1); // highlighter undone

      controller.redo();
      expect(controller.strokes.length, 2); // highlighter restored

      // 3.4 Eraser Tool
      controller.selectAnnotateTool(AnnotateTool.eraser);
      controller.startDrawing(const Offset(20, 20), 0); // close to first stroke
      controller.updateDrawing(const Offset(22, 22));
      controller.endDrawing(0, const Size(350, 500));

      // The first stroke should be erased because it intersects (20,20)
      expect(controller.strokes.length, 1);
      expect(controller.strokes.first.isHighlighter, true); // only highlighter remains
    });

    test('4. Fill & Sign Group: Vector Signatures, Symbols, and Manipulation', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      // 4.1 Checkmark Stamp
      final checkStamp = PlacedStamp(
        id: 'stamp_check_1',
        type: StampType.check,
        pageIndex: 0,
        position: const Offset(100, 100),
        size: const Size(30, 30),
        text: '✔',
        color: const Color(0xFF16A34A),
      );
      controller.stamps.add(checkStamp);

      // 4.2 Cross Mark Stamp
      final crossStamp = PlacedStamp(
        id: 'stamp_cross_1',
        type: StampType.cross,
        pageIndex: 0,
        position: const Offset(150, 100),
        size: const Size(30, 30),
        text: '✖',
        color: const Color(0xFFDC2626),
      );
      controller.stamps.add(crossStamp);

      // 4.3 Date Stamp
      final dateStamp = PlacedStamp(
        id: 'stamp_date_1',
        type: StampType.dateStamp,
        pageIndex: 0,
        position: const Offset(200, 100),
        size: const Size(120, 30),
        text: '2026-11-08',
      );
      controller.stamps.add(dateStamp);

      // 4.4 Vector Signature Stamp
      final sigStamp = PlacedStamp(
        id: 'stamp_sig_1',
        type: StampType.signature,
        pageIndex: 0,
        position: const Offset(50, 200),
        size: const Size(140, 70),
        rawSignatureLines: [
          [const Offset(0.1, 0.5), const Offset(0.5, 0.9), const Offset(0.9, 0.2)],
        ],
        color: const Color(0xFF0F172A),
      );
      controller.stamps.add(sigStamp);

      expect(controller.stamps.length, 4);

      // 4.5 Change color of signature dynamically
      controller.changeStampColor('stamp_sig_1', const Color(0xFF1D4ED8));
      final updatedSig = controller.stamps.firstWhere((s) => s.id == 'stamp_sig_1');
      expect(updatedSig.color, const Color(0xFF1D4ED8));

      // 4.6 Scale stamp (symbols / signatures scale smoothly)
      controller.changeStampScale('stamp_check_1', 1.5);
      final scaledCheck = controller.stamps.firstWhere((s) => s.id == 'stamp_check_1');
      expect(scaledCheck.size.width, 45.0);
      expect(scaledCheck.size.height, 45.0);

      // 4.7 Duplicate Stamp
      controller.duplicateStamp('stamp_check_1');
      expect(controller.stamps.length, 5);

      // 4.8 Remove Stamp
      controller.removeStamp('stamp_cross_1');
      expect(controller.stamps.any((s) => s.id == 'stamp_cross_1'), false);
    });

    test('5. Edit Group: Smart Whiteout and Formatted Box', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      // 5.1 Smart Whiteout with custom background tone
      final whiteout = PlacedStamp(
        id: 'whiteout_1',
        type: StampType.whiteout,
        pageIndex: 0,
        position: const Offset(40, 50),
        size: const Size(200, 40),
        backgroundColor: const Color(0xFFFFFDF7), // warm parchment
      );
      controller.stamps.add(whiteout);

      // Change whiteout background color
      controller.changeStampBackgroundColor('whiteout_1', const Color(0xFFF3F4F6));
      expect(controller.stamps.first.backgroundColor, const Color(0xFFF3F4F6));

      // 5.2 Formatted Box (styled text with alignment, bold, and fill)
      final formattedBox = PlacedStamp(
        id: 'formatted_box_1',
        type: StampType.formattedTextBox,
        pageIndex: 0,
        position: const Offset(45, 55),
        size: const Size(220, 80),
        text: 'Formatted Note\nMulti-line Test',
        color: const Color(0xFF1E293B),
        fontSize: 14,
        isBold: true,
        alignment: TextAlign.center,
        backgroundColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFF93C5FD),
      );
      controller.stamps.add(formattedBox);

      // 5.3 Quick Text (Fill & Sign)
      final quickText = PlacedStamp(
        id: 'quick_text_1',
        type: StampType.quickText,
        pageIndex: 0,
        position: const Offset(50, 150),
        size: const Size(120, 36),
        text: 'Quick Form Value',
        color: const Color(0xFFDC2626),
      );
      controller.stamps.add(quickText);

      expect(controller.stamps.length, 3);
      expect(controller.stamps.first.type, StampType.whiteout);
      expect(controller.stamps[1].type, StampType.formattedTextBox);
      expect(controller.stamps[2].type, StampType.quickText);
    });

    test('6. Convert Group: Text Extraction (PDF to TXT)', () async {
      final bytes = await samplePdf.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(doc);
      final extractedText = extractor.extractText();
      doc.dispose();

      expect(extractedText.contains('Sample Test Page 1'), true);
      expect(extractedText.contains('Architecture Deep Dive Content'), true);
    });

    test('7. Save Modifications to Real PDF with Vector Graphics', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      // Add stroke
      controller.selectAnnotateTool(AnnotateTool.pen);
      controller.startDrawing(const Offset(50, 150), 0);
      controller.updateDrawing(const Offset(250, 150));
      controller.endDrawing(0, const Size(350, 500));

      // Add formatted text stamp
      controller.stamps.add(PlacedStamp(
        id: 'stamp_final_1',
        type: StampType.formattedTextBox,
        pageIndex: 0,
        position: const Offset(50, 200),
        size: const Size(180, 40),
        text: 'Approved By Lead Engineer',
        color: const Color(0xFF1D4ED8),
        fontSize: 12,
      ));

      // Execute Save logic directly on PDF bytes
      final srcBytes = await samplePdf.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: srcBytes);

      for (int i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];

        // Draw stamps
        for (final stamp in controller.stamps.where((s) => s.pageIndex == i)) {
          final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, stamp.fontSize);
          page.graphics.drawString(
            stamp.text!,
            font,
            bounds: Rect.fromLTWH(stamp.position.dx, stamp.position.dy, stamp.size.width, stamp.size.height),
            brush: sf.PdfSolidBrush(sf.PdfColor(0, 0, 255)),
          );
        }

        // Draw strokes
        for (final stroke in controller.strokes.where((s) => s.pageIndex == i)) {
          final pen = sf.PdfPen(sf.PdfColor(255, 0, 0), width: stroke.strokeWidth);
          for (int j = 1; j < stroke.points.length; j++) {
            page.graphics.drawLine(pen, stroke.points[j - 1], stroke.points[j]);
          }
        }
      }

      final outPath = '${tempDir.path}/saved_edited_doc.pdf';
      final savedBytes = doc.saveSync();
      await File(outPath).writeAsBytes(savedBytes);
      doc.dispose();

      // Verify the generated PDF file exists and is valid
      final verifyFile = File(outPath);
      expect(verifyFile.existsSync(), true);
      expect(verifyFile.lengthSync() > 0, true);

      // Verify it can be loaded and has 3 pages
      final verifyDoc = sf.PdfDocument(inputBytes: verifyFile.readAsBytesSync());
      expect(verifyDoc.pages.count, 3);

      final verifyExtractor = sf.PdfTextExtractor(verifyDoc);
      final verifiedText = verifyExtractor.extractText();
      expect(verifiedText.contains('Approved By Lead Engineer'), true);
      verifyDoc.dispose();
    });

    test('8. Shapes Selectability, Recoloring, Stroke Width, and Dirty State', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);
      expect(controller.hasUnsavedChanges.value, false);

      // Register a page size so addShape centers inside it
      controller.registerPageMetrics(0, const Size(400, 600), null);
      controller.setDrawingColor(const Color(0xFFDC2626));
      controller.setStrokeWidth(3.0);

      // Adding a shape must switch out of drawing mode into AnnotateTool.select
      controller.selectAnnotateTool(AnnotateTool.pen);
      expect(controller.isDrawingModeActive.value, true);

      controller.addShape(StampType.rectShape);
      expect(controller.stamps.length, 1);
      expect(controller.activeAnnotateTool.value, AnnotateTool.select);
      expect(controller.isDrawingModeActive.value, false);
      expect(controller.hasUnsavedChanges.value, true);

      final rectShape = controller.stamps.first;
      expect(rectShape.type, StampType.rectShape);
      expect(rectShape.color, const Color(0xFFDC2626));
      expect(rectShape.strokeWidth, 3.0);
      expect(controller.selectedStampId.value, rectShape.id);

      // Changing drawing color and stroke width while selected syncs to selected shape
      controller.setDrawingColor(const Color(0xFF2563EB));
      controller.setStrokeWidth(6.0);
      final syncedShape = controller.stamps.firstWhere((s) => s.id == rectShape.id);
      expect(syncedShape.color, const Color(0xFF2563EB));
      expect(syncedShape.strokeWidth, 6.0);

      // Updating position & size works cleanly
      controller.updateStampPosition(rectShape.id, const Offset(15, 25));
      controller.updateStampSize(rectShape.id, const Size(160, 90));
      final transformed = controller.stamps.firstWhere((s) => s.id == rectShape.id);
      expect(transformed.position, const Offset(15, 25));
      expect(transformed.size, const Size(160, 90));

      // loadFile resets hasUnsavedChanges cleanly
      await controller.loadFile(samplePdf.path);
      expect(controller.hasUnsavedChanges.value, false);
    });

    test('9. clusterCharBoxesIntoLines Groups Multi-Line & Splits Wide Gaps', () {
      // Line 1: two words on the same baseline (~y=100..112), separated vertically from Line 2 (~y=124..136)
      // Plus a wide gap word on Line 3 (~y=160..172)
      final boxes = <Rect>[
        const Rect.fromLTRB(50, 100, 60, 112),
        const Rect.fromLTRB(61, 101, 72, 112),
        const Rect.fromLTRB(80, 100, 95, 113),
        // Line 2
        const Rect.fromLTRB(50, 124, 65, 136),
        const Rect.fromLTRB(66, 124, 88, 136),
        // Line 3 with wide horizontal column gap on same row (gap > lineHeight * 2.5)
        const Rect.fromLTRB(50, 160, 70, 172),
        const Rect.fromLTRB(200, 160, 230, 172),
      ];

      final lines = DocumentEditorController.clusterCharBoxesIntoLines(boxes);
      expect(lines.length, 4);
      // Each clustered line rect includes a crisp 1.0px visual pad around the line bounds
      expect(lines[0], const Rect.fromLTRB(50, 100, 95, 113).inflate(1.0));
      expect(lines[1], const Rect.fromLTRB(50, 124, 88, 136).inflate(1.0));
      // Line 3 column A and column B kept separate across wide gap
      expect(lines[2], const Rect.fromLTRB(50, 160, 70, 172).inflate(1.0));
      expect(lines[3], const Rect.fromLTRB(200, 160, 230, 172).inflate(1.0));
    });

    test('10. Eraser Erases Both Strokes and Stamps Including Multi-Line Markups with Atomic Undo/Redo', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      const pageSize = Size(400, 600);
      controller.registerPageMetrics(0, pageSize, null);

      // Add a freehand stroke across (40, 80) -> (140, 80)
      controller.selectAnnotateTool(AnnotateTool.pen);
      controller.startDrawing(const Offset(40, 80), 0);
      controller.updateDrawing(const Offset(140, 80));
      await controller.endDrawing(0, pageSize);

      // Add a multi-line highlight stamp covering two lines
      controller.stamps.add(PlacedStamp(
        id: 'hl_multi_1',
        type: StampType.highlightRect,
        pageIndex: 0,
        position: const Offset(50, 100),
        size: const Size(150, 40),
        color: const Color(0xFFF59E0B),
        lineRects: const [
          Rect.fromLTWH(50, 100, 150, 14),
          Rect.fromLTWH(50, 122, 110, 14),
        ],
      ));

      // Add a vector check stamp near (300, 300)
      controller.stamps.add(PlacedStamp(
        id: 'chk_1',
        type: StampType.check,
        pageIndex: 0,
        position: const Offset(290, 290),
        size: const Size(30, 30),
        color: const Color(0xFF16A34A),
      ));

      expect(controller.strokes.length, 1);
      expect(controller.stamps.length, 2);

      // Erase over both the stroke (y=80) and the second line of hl_multi_1 (y=128) in one swipe
      controller.selectAnnotateTool(AnnotateTool.eraser);
      controller.startDrawing(const Offset(90, 80), 0);
      controller.updateDrawing(const Offset(90, 128));
      await controller.endDrawing(0, pageSize);

      // Both the stroke AND the multi-line highlight should be erased, while distant chk_1 stays
      expect(controller.strokes.length, 0);
      expect(controller.stamps.length, 1);
      expect(controller.stamps.first.id, 'chk_1');

      // Single Undo must restore BOTH the stroke and hl_multi_1 atomically
      controller.undo();
      expect(controller.strokes.length, 1);
      expect(controller.stamps.length, 2);
      expect(controller.stamps.any((s) => s.id == 'hl_multi_1'), true);

      // Single Redo must remove both again atomically
      controller.redo();
      expect(controller.strokes.length, 0);
      expect(controller.stamps.length, 1);
      expect(controller.stamps.first.id, 'chk_1');
    });

    test('11. Real Editable PDF Annotations & Vector Stamps Export', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      // Register realistic viewport size for coordinate scaling
      controller.registerPageMetrics(0, const Size(595, 842), null);

      // 1. Multi-line Highlight -> PdfTextMarkupAnnotation(highlight)
      controller.stamps.add(PlacedStamp(
        id: 'exp_hl',
        type: StampType.highlightRect,
        pageIndex: 0,
        position: const Offset(40, 60),
        size: const Size(200, 36),
        color: const Color(0xFFF59E0B),
        lineRects: const [
          Rect.fromLTWH(40, 60, 200, 14),
          Rect.fromLTWH(40, 82, 140, 14),
        ],
      ));

      // 2. Underline -> PdfTextMarkupAnnotation(underline)
      controller.stamps.add(PlacedStamp(
        id: 'exp_ul',
        type: StampType.underlineRect,
        pageIndex: 0,
        position: const Offset(40, 120),
        size: const Size(150, 14),
        color: const Color(0xFF2563EB),
        lineRects: const [Rect.fromLTWH(40, 120, 150, 14)],
      ));

      // 3. Strikeout -> PdfTextMarkupAnnotation(strikethrough)
      controller.stamps.add(PlacedStamp(
        id: 'exp_so',
        type: StampType.strikeoutRect,
        pageIndex: 0,
        position: const Offset(40, 150),
        size: const Size(150, 14),
        color: const Color(0xFFDC2626),
        lineRects: const [Rect.fromLTWH(40, 150, 150, 14)],
      ));

      // 4. Shapes -> Rectangle, Ellipse, Line, Arrow annotations
      controller.stamps.addAll([
        PlacedStamp(
          id: 'exp_rect',
          type: StampType.rectShape,
          pageIndex: 0,
          position: const Offset(60, 200),
          size: const Size(100, 60),
          color: const Color(0xFFDC2626),
          strokeWidth: 2.5,
        ),
        PlacedStamp(
          id: 'exp_circle',
          type: StampType.circleShape,
          pageIndex: 0,
          position: const Offset(180, 200),
          size: const Size(80, 80),
          color: const Color(0xFF16A34A),
          strokeWidth: 3.0,
        ),
        PlacedStamp(
          id: 'exp_line',
          type: StampType.lineShape,
          pageIndex: 0,
          position: const Offset(60, 300),
          size: const Size(120, 20),
          color: const Color(0xFF0F172A),
          strokeWidth: 2.0,
        ),
        PlacedStamp(
          id: 'exp_arrow',
          type: StampType.arrowShape,
          pageIndex: 0,
          position: const Offset(200, 300),
          size: const Size(120, 30),
          color: const Color(0xFF7C3AED),
          strokeWidth: 3.5,
        ),
        // Plus baked vector check/cross & whiteout content
        PlacedStamp(
          id: 'exp_check',
          type: StampType.check,
          pageIndex: 0,
          position: const Offset(340, 300),
          size: const Size(28, 28),
          color: const Color(0xFFEF4444),
        ),
        PlacedStamp(
          id: 'exp_cross',
          type: StampType.cross,
          pageIndex: 0,
          position: const Offset(380, 300),
          size: const Size(28, 28),
          color: const Color(0xFFEF4444),
        ),
        PlacedStamp(
          id: 'exp_whiteout',
          type: StampType.whiteout,
          pageIndex: 0,
          position: const Offset(50, 400),
          size: const Size(120, 24),
          backgroundColor: const Color(0xFFFDF6E3),
        ),
      ]);

      final srcBytes = await samplePdf.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: srcBytes);
      await controller.applyModificationsToDocument(doc);
      final outBytes = await doc.save();
      doc.dispose();

      final verifyDoc = sf.PdfDocument(inputBytes: outBytes);
      final annotations = verifyDoc.pages[0].annotations;

      final textMarkups = <sf.PdfTextMarkupAnnotation>[];
      final rects = <sf.PdfRectangleAnnotation>[];
      final ellipses = <sf.PdfEllipseAnnotation>[];
      final lines = <sf.PdfLineAnnotation>[];

      for (int i = 0; i < annotations.count; i++) {
        final ann = annotations[i];
        if (ann is sf.PdfTextMarkupAnnotation) textMarkups.add(ann);
        if (ann is sf.PdfRectangleAnnotation) rects.add(ann);
        if (ann is sf.PdfEllipseAnnotation) ellipses.add(ann);
        if (ann is sf.PdfLineAnnotation) lines.add(ann);
      }

      // 1 grouped highlight annotation (spanning both lines) + 1 underline + 1 strikethrough = 3 markup annotations
      expect(textMarkups.length, 3);
      final hlMarkups = textMarkups
          .where((a) => a.textMarkupAnnotationType == sf.PdfTextMarkupAnnotationType.highlight)
          .toList();
      expect(hlMarkups.length, 1);
      expect(hlMarkups.first.bounds.width, greaterThan(150));
      expect(hlMarkups.first.bounds.height, greaterThan(30));
      expect(
        textMarkups.where((a) => a.textMarkupAnnotationType == sf.PdfTextMarkupAnnotationType.underline).length,
        1,
      );
      expect(
        textMarkups.where((a) => a.textMarkupAnnotationType == sf.PdfTextMarkupAnnotationType.strikethrough).length,
        1,
      );

      expect(rects.length, 1);
      expect(ellipses.length, 1);
      expect(lines.length, 2);

      verifyDoc.dispose();
    });

    test('12. Initial File Launch Starts in Loading State (No Empty-View Flash)', () async {
      final controller = DocumentEditorController(initialFilePath: samplePdf.path);
      // Calling onInit mimics GetX controller startup when initialFilePath is passed
      controller.onInit();
      expect(controller.isLoading.value, true);
      expect(controller.loadFailed.value, false);

      // Explicitly await completion before tempDir cleanup in tearDown
      await controller.loadFile(samplePdf.path);
      expect(controller.isLoading.value, false);
      expect(controller.totalPages.value, 3);
      expect(controller.hasUnsavedChanges.value, false);
    });

    test('13. Circle Shape Starts Square (96x96) so Exported Annotation is Never an Oval', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      controller.addShape(StampType.circleShape);
      expect(controller.stamps.length, 1);
      final circle = controller.stamps.first;
      expect(circle.type, StampType.circleShape);
      expect(circle.size.width, 96.0);
      expect(circle.size.height, 96.0);
      expect(circle.size.width, circle.size.height);
    });

    test('14. Fixed Text Markups (Highlight/Underline/Strikeout) are Immobilized & Cannot Duplicate', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      final hl = PlacedStamp(
        id: 'hl_fixed_1',
        type: StampType.highlightRect,
        pageIndex: 0,
        position: const Offset(40, 60),
        size: const Size(200, 20),
        color: const Color(0xFFFEF08A),
      );
      controller.stamps.add(hl);

      // Attempt duplicate on fixed markup should be ignored
      controller.duplicateStamp('hl_fixed_1');
      expect(controller.stamps.length, 1);

      // Attempt changeStampScale should be ignored
      controller.changeStampScale('hl_fixed_1', 1.5);
      expect(controller.stamps.first.size, const Size(200, 20));

      // Attempt updateStampPosition should be ignored
      controller.updateStampPosition('hl_fixed_1', const Offset(100, 200));
      expect(controller.stamps.first.position, const Offset(40, 60));

      // But recoloring and deletion are allowed
      controller.changeStampColor('hl_fixed_1', const Color(0xFFDC2626));
      expect(controller.stamps.first.color, const Color(0xFFDC2626));

      controller.removeStamp('hl_fixed_1');
      expect(controller.stamps.isEmpty, true);
    });

    test('15. Smart Whiteout Default Borderless & Toggle Border', () async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      final wo = PlacedStamp(
        id: 'wo_1',
        type: StampType.whiteout,
        pageIndex: 0,
        position: const Offset(50, 50),
        size: const Size(100, 30),
        backgroundColor: Colors.white,
      );
      controller.stamps.add(wo);

      // By default borderless
      expect(controller.stamps.first.borderColor, isNull);

      // Toggle border ON
      controller.toggleStampBorder('wo_1');
      expect(controller.stamps.first.borderColor, isNotNull);

      // Toggle border OFF
      controller.toggleStampBorder('wo_1');
      expect(controller.stamps.first.borderColor, isNull);
    });

    test('16. Layout-aware Text and BiDi Detection via PdfTextLayout', () {
      expect(PdfTextLayout.isRtlDominantText('مرحبا بك في عالم البرمجة'), isTrue);
      expect(PdfTextLayout.isRtlDominantText('Hello World'), isFalse);
      expect(PdfTextLayout.isRtlDominantText('تقرير سنوي Report 2026'), isTrue);

      // Presentation Forms-B normalization
      final isolatedAlef = String.fromCharCode(0xFE8D); // Arabic Letter Alef Isolated Form
      final normalized = PdfTextLayout.normalizeArabicText(isolatedAlef);
      expect(normalized, '\u0627'); // Standard logical Alef

      // Reversed Arabic Presentation Forms correction: "ﺐﻌﺼﻣ" (baa-final, ain-medial, sad-medial, meem-initial) -> "مصعب"
      final reversedPresentationMosaab = String.fromCharCodes([0xFE90, 0xFECB, 0xFEBC, 0xFEE3]);
      final correctedMosaab = PdfTextLayout.normalizeArabicText(reversedPresentationMosaab);
      expect(correctedMosaab, 'مصعب');

      // Canonical logical Arabic is preserved without distortion
      expect(PdfTextLayout.normalizeArabicText('مصعب'), 'مصعب');
    });

    testWidgets('17. Date Stamp Compact Badge Sizing and Center Alignment', (tester) async {
      final controller = DocumentEditorController();
      await controller.loadFile(samplePdf.path);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => controller.handleFillSignAction(FillSignTool.dateStamp, context),
              child: const Text('Add Date'),
            );
          },
        ),
      ));

      await tester.tap(find.text('Add Date'));
      await tester.pump();

      expect(controller.stamps.isNotEmpty, true);

      final dateStamp = controller.stamps.first;
      expect(dateStamp.type, StampType.dateStamp);
      expect(dateStamp.size.width <= 100.0, true);
      expect(dateStamp.size.height <= 30.0, true);
      expect(dateStamp.alignment, TextAlign.center);
      expect(dateStamp.isBold, true);
    });
  });
}

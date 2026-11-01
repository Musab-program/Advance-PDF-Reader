import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf_reader/modules/office_viewer/controllers/office_viewer_controller.dart';
import 'package:pdf_reader/modules/office_viewer/services/xlsx_parser.dart';
import 'package:pdf_reader/modules/office_viewer/services/pptx_parser.dart';

class OfficeViewerView extends GetView<OfficeViewerController> {
  const OfficeViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isPresentationPlayMode.value) {
        return _buildFullscreenPresentationPlayMode(context);
      }

      final theme = Theme.of(context);
      final cardBg = theme.cardColor;
      final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
      final type = controller.fileType.value;

      Color badgeColor = const Color(0xFF2B579A); // Word Blue
      if (type == 'XLSX' || type == 'XLS' || type == 'CSV') {
        badgeColor = const Color(0xFF217346); // Excel Green
      } else if (type == 'PPTX' || type == 'PPT') {
        badgeColor = const Color(0xFFD24726); // PowerPoint Orange
      }

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimaryColor, size: 20),
            onPressed: () => Get.back(),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.fileName.value,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (!controller.isLoading.value && controller.errorMessage.value.isEmpty) ...[
              // Search toggle button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  controller.isSearchOpen.value ? Icons.search_off_rounded : Icons.search_rounded,
                  color: controller.isSearchOpen.value ? badgeColor : textPrimaryColor,
                  size: 20,
                ),
                tooltip: 'بحث في المستند',
                onPressed: controller.toggleSearch,
              ),

              // Word / Legacy Dual Layout Mode button (WPS Page Mode vs Mobile Reflow)
              if (controller.isWordFamily || controller.isLegacyBinaryFallback)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    controller.isDocxReflowMode.value
                        ? Icons.description_outlined
                        : Icons.phone_android_rounded,
                    color: controller.isDocxReflowMode.value ? badgeColor : textPrimaryColor,
                    size: 20,
                  ),
                  tooltip: controller.isDocxReflowMode.value
                      ? 'وضع تخطيط الطباعة (Page Mode)'
                      : 'وضع الجوال الذكي (Mobile Reflow)',
                  onPressed: controller.toggleDocxLayoutMode,
                ),

              // Excel Freeze Header toggle
              if (controller.isExcelFamily)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    controller.freezeFirstRow.value
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: controller.freezeFirstRow.value ? badgeColor : textPrimaryColor,
                    size: 19,
                  ),
                  tooltip: 'تثبيت صف العناوين (Freeze Header)',
                  onPressed: controller.toggleFreezeFirstRow,
                ),

              // PowerPoint Play Mode & Canvas/Outline toggle
              if (controller.isPptFamily) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    controller.isSlideCanvasMode.value
                        ? Icons.view_agenda_outlined
                        : Icons.slideshow_rounded,
                    color: textPrimaryColor,
                    size: 20,
                  ),
                  tooltip: controller.isSlideCanvasMode.value
                      ? 'عرض تفصيلي للنصوص'
                      : 'عرض لوحة الشريحة (Scene Graph)',
                  onPressed: controller.togglePptDisplayMode,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.play_circle_fill_rounded, color: badgeColor, size: 22),
                  tooltip: 'بدء العرض التقديمي (Play Slide Show)',
                  onPressed: controller.togglePresentationPlayMode,
                ),
              ],

              // Zoom Controls
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.remove_circle_outline_rounded, color: textPrimaryColor, size: 19),
                tooltip: 'تصغير',
                onPressed: controller.zoomOut,
              ),
              GestureDetector(
                onTap: controller.resetZoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(controller.zoomScale.value * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add_circle_outline_rounded, color: textPrimaryColor, size: 19),
                tooltip: 'تكبير',
                onPressed: controller.zoomIn,
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Optional Search Bar
              if (controller.isSearchOpen.value)
                _buildSearchBar(context, badgeColor),

              Expanded(
                child: Builder(
                  builder: (_) {
                    if (controller.isLoading.value) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: badgeColor),
                            const SizedBox(height: 14),
                            Text(
                              'جاري معالجة وتجهيز المستند...',
                              style: TextStyle(color: textPrimaryColor, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    if (controller.errorMessage.value.isNotEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                controller.errorMessage.value,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textPrimaryColor, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (controller.isExcelFamily) {
                      return _buildXlsxVirtualGridView(context, badgeColor);
                    } else if (controller.isPptFamily) {
                      return _buildPptxView(context, badgeColor);
                    } else {
                      return _buildDocxView();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomSheetBar(context, badgeColor),
      );
    });
  }

  Widget _buildSearchBar(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller.searchTextController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: controller.onSearchSubmitted,
              onChanged: (v) => controller.searchQuery.value = v.trim(),
              style: TextStyle(fontSize: 13.5, color: textPrimary),
              decoration: const InputDecoration(
                hintText: 'ابحث عن نص أو رقم داخل المستند...',
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          TextButton(
            onPressed: () => controller.onSearchSubmitted(controller.searchTextController.text),
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('بحث', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocxView() {
    if (controller.docxWebViewController == null) {
      return const Center(child: Text('تعذر تجهيز عارض المستند.'));
    }
    return WebViewWidget(controller: controller.docxWebViewController!);
  }

  // ===========================================================================
  // EXCEL / CSV ENGINE: 2D Virtualized Grid + Formula Bar + Freeze Header + Stats
  // ===========================================================================
  Widget _buildXlsxVirtualGridView(BuildContext context, Color excelColor) {
    final wb = controller.workbook.value;
    if (wb == null || wb.sheets.isEmpty) {
      return const Center(child: Text('لا توجد بيانات لعرضها في جدول البيانات.'));
    }

    final sheet = wb.sheets[controller.activeSheetIndex.value];
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final colWidths = controller.currentColumnWidths;
    final int totalCols = colWidths.isNotEmpty ? colWidths.length : 10;
    final int totalRows = (sheet.maxRow < 30 ? 30 : sheet.maxRow).clamp(1, 50000);
    const double rowNumberColWidth = 52.0;

    return Column(
      children: [
        // 1. WPS Formula & Cell Reference Bar (fx bar)
        Obx(() {
          final cellRef = controller.selectedCellReference;
          final cellContent = controller.selectedCellFormulaOrValue;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: excelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: excelColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    cellRef,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: excelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'fx',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: textPrimary.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    cellContent.isEmpty ? '—' : cellContent,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                  ),
                ),
                if (cellContent.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.copy_rounded, size: 15, color: textPrimary.withValues(alpha: 0.6)),
                    tooltip: 'نسخ محتوى الخلية',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cellContent));
                      Get.snackbar(
                        'تم النسخ',
                        'تم نسخ محتوى الخلية ($cellRef)',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
              ],
            ),
          );
        }),

        // 2. Virtualized 2D Spreadsheet Grid (Lazy Row Building via ListView.builder)
        Expanded(
          child: Obx(() {
            final scale = controller.zoomScale.value;
            final selR = controller.selectedRow.value;
            final selC = controller.selectedCol.value;
            final q = controller.searchQuery.value.toLowerCase();
            final isFrozen = controller.freezeFirstRow.value;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (rowNumberColWidth +
                        colWidths.fold<double>(0.0, (sum, w) => sum + w)) *
                    scale,
                child: Column(
                  children: [
                    // Column Letters Bar (A, B, C, D...)
                    _buildColumnLettersRow(
                      context,
                      totalCols: totalCols,
                      colWidths: colWidths,
                      rowNumberColWidth: rowNumberColWidth,
                      scale: scale,
                      selectedCol: selC,
                      excelColor: excelColor,
                    ),

                    // Optional Frozen First Data Row (Row 1 Header)
                    if (isFrozen && totalRows > 0)
                      _buildSpreadsheetDataRow(
                        context,
                        sheet: sheet,
                        rowIndex: 0,
                        totalCols: totalCols,
                        colWidths: colWidths,
                        rowNumberColWidth: rowNumberColWidth,
                        scale: scale,
                        selectedRow: selR,
                        selectedCol: selC,
                        searchQueryLower: q,
                        excelColor: excelColor,
                        isFrozenHeaderRow: true,
                      ),

                    // Virtualized Lazy Rows (handles 50,000+ rows at 60 FPS with zero memory spike)
                    Expanded(
                      child: ListView.builder(
                        itemCount: isFrozen ? (totalRows - 1) : totalRows,
                        itemBuilder: (ctx, idx) {
                          final r = isFrozen ? (idx + 1) : idx;
                          return _buildSpreadsheetDataRow(
                            ctx,
                            sheet: sheet,
                            rowIndex: r,
                            totalCols: totalCols,
                            colWidths: colWidths,
                            rowNumberColWidth: rowNumberColWidth,
                            scale: scale,
                            selectedRow: selR,
                            selectedCol: selC,
                            searchQueryLower: q,
                            excelColor: excelColor,
                            isFrozenHeaderRow: false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),

        // 3. WPS GridHintBar: Live Column Summary (Count, Sum, Average)
        Obx(() {
          final count = controller.numericSelectionCount.value;
          if (count <= 0) return const SizedBox.shrink();
          final sum = controller.numericSelectionSum.value;
          final avg = controller.numericSelectionAvg.value;
          final colLetter = XlsxParser.colToLetter(controller.selectedCol.value);

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: excelColor.withValues(alpha: 0.08),
              border: Border(top: BorderSide(color: excelColor.withValues(alpha: 0.25))),
            ),
            child: Wrap(
              spacing: 16,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'عمود $colLetter:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: excelColor),
                ),
                Text(
                  'العدد (Count): $count',
                  style: TextStyle(fontSize: 11, color: textPrimary),
                ),
                Text(
                  'المجموع (Sum): ${sum.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                Text(
                  'المتوسط (Avg): ${avg.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: textPrimary),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildColumnLettersRow(
    BuildContext context, {
    required int totalCols,
    required List<double> colWidths,
    required double rowNumberColWidth,
    required double scale,
    required int selectedCol,
    required Color excelColor,
  }) {
    final theme = Theme.of(context);
    final borderCol = theme.dividerColor.withValues(alpha: 0.45);

    return Container(
      height: 30 * scale,
      decoration: BoxDecoration(
        color: excelColor.withValues(alpha: 0.10),
        border: Border(bottom: BorderSide(color: borderCol, width: 1.0)),
      ),
      child: Row(
        children: [
          Container(
            width: rowNumberColWidth * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: borderCol, width: 0.8)),
            ),
            child: Text(
              '#',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11 * scale, color: excelColor),
            ),
          ),
          for (int c = 0; c < totalCols; c++)
            Container(
              width: colWidths[c] * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selectedCol == c ? excelColor.withValues(alpha: 0.22) : null,
                border: Border(right: BorderSide(color: borderCol, width: 0.8)),
              ),
              child: Text(
                XlsxParser.colToLetter(c),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5 * scale,
                  color: excelColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetDataRow(
    BuildContext context, {
    required XlsxSheet sheet,
    required int rowIndex,
    required int totalCols,
    required List<double> colWidths,
    required double rowNumberColWidth,
    required double scale,
    required int selectedRow,
    required int selectedCol,
    required String searchQueryLower,
    required Color excelColor,
    required bool isFrozenHeaderRow,
  }) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final borderCol = theme.dividerColor.withValues(alpha: 0.35);

    final rowBg = isFrozenHeaderRow
        ? excelColor.withValues(alpha: 0.06)
        : (rowIndex % 2 == 1 ? cardBg.withValues(alpha: 0.55) : cardBg);

    return Container(
      constraints: BoxConstraints(minHeight: 34 * scale),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(
            color: isFrozenHeaderRow ? excelColor.withValues(alpha: 0.45) : borderCol,
            width: isFrozenHeaderRow ? 1.4 : 0.7,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row number index (1, 2, 3...)
            Container(
              width: rowNumberColWidth * scale,
              padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 4 * scale),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selectedRow == rowIndex
                    ? excelColor.withValues(alpha: 0.22)
                    : excelColor.withValues(alpha: 0.04),
                border: Border(right: BorderSide(color: borderCol, width: 0.8)),
              ),
              child: Text(
                '${rowIndex + 1}',
                style: TextStyle(
                  fontSize: 10.5 * scale,
                  fontWeight: FontWeight.bold,
                  color: selectedRow == rowIndex
                      ? excelColor
                      : textPrimary.withValues(alpha: 0.65),
                ),
              ),
            ),

            // Row cells
            for (int c = 0; c < totalCols; c++)
              _buildGridCellWidget(
                context,
                sheet: sheet,
                r: rowIndex,
                c: c,
                width: colWidths[c] * scale,
                scale: scale,
                isSelected: selectedRow == rowIndex && selectedCol == c,
                searchQueryLower: searchQueryLower,
                excelColor: excelColor,
                borderCol: borderCol,
                textPrimary: textPrimary,
                isFrozenHeaderRow: isFrozenHeaderRow,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCellWidget(
    BuildContext context, {
    required XlsxSheet sheet,
    required int r,
    required int c,
    required double width,
    required double scale,
    required bool isSelected,
    required String searchQueryLower,
    required Color excelColor,
    required Color borderCol,
    required Color textPrimary,
    required bool isFrozenHeaderRow,
  }) {
    final cellObj = sheet.getCellObject(r, c);
    final val = cellObj?.value ?? '';
    final isMatch = searchQueryLower.isNotEmpty && val.toLowerCase().contains(searchQueryLower);

    Color? customBg;
    if (isMatch) {
      customBg = Colors.amber.withValues(alpha: 0.35);
    } else if (cellObj?.bgColorHex != null) {
      customBg = _tryParseHexColor(cellObj!.bgColorHex!);
    }

    Color cellTextCol = textPrimary;
    if (cellObj?.textColorHex != null) {
      cellTextCol = _tryParseHexColor(cellObj!.textColorHex!) ?? textPrimary;
    }

    return GestureDetector(
      onTap: () => controller.selectCell(r, c),
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 8 * scale),
        alignment: (cellObj?.isNumeric ?? false) ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected ? excelColor.withValues(alpha: 0.14) : customBg,
          border: isSelected
              ? Border.all(color: excelColor, width: 1.8)
              : Border(right: BorderSide(color: borderCol, width: 0.7)),
        ),
        child: Text(
          val,
          softWrap: true,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: (cellObj?.isBold == true || isFrozenHeaderRow)
                ? FontWeight.bold
                : FontWeight.normal,
            color: cellTextCol,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // POWERPOINT ENGINE: Vector Scene Graph 16:9 Canvas + Thumbnails + Play Mode
  // ===========================================================================
  Widget _buildPptxView(BuildContext context, Color pptColor) {
    final pres = controller.presentation.value;
    if (pres == null || pres.slides.isEmpty) {
      return const Center(child: Text('لا توجد شرائح لعرضها في العرض التقديمي.'));
    }

    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = theme.cardColor;

    return Column(
      children: [
        // Main Slide Viewport
        Expanded(
          child: PageView.builder(
            controller: controller.pptPageController,
            onPageChanged: (idx) {
              controller.currentSlideIndex.value = idx;
              controller.resetZoom();
            },
            itemCount: pres.slides.length,
            itemBuilder: (ctx, idx) {
              final slide = pres.slides[idx];
              return Obx(() {
                final useCanvas = controller.isSlideCanvasMode.value;
                return InteractiveViewer(
                  transformationController: controller.pptxTransformController,
                  minScale: 0.3,
                  maxScale: 4.5,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(140),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (useCanvas && slide.elements.isNotEmpty)
                          _buildSlideSceneGraphCanvas(context, pres, slide, pptColor)
                        else
                          _buildSlideStructuredCard(context, slide, pptColor),

                        // Speaker Notes Drawer (if present)
                        if (slide.speakerNotes.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.speaker_notes_rounded, size: 16, color: pptColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ملاحظات المحاضر (Speaker Notes)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: pptColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  slide.speakerNotes,
                                  style: TextStyle(fontSize: 13, color: textPrimary, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              });
            },
          ),
        ),

        // Bottom Thumbnail Filmstrip + Slide Counter
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 54,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: pres.slides.length,
                  itemBuilder: (ctx, idx) {
                    return Obx(() {
                      final isCurrent = controller.currentSlideIndex.value == idx;
                      final s = pres.slides[idx];
                      return GestureDetector(
                        onTap: () => controller.jumpToSlide(idx),
                        child: Container(
                          width: 88,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? pptColor.withValues(alpha: 0.14)
                                : theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent ? pptColor : theme.dividerColor.withValues(alpha: 0.4),
                              width: isCurrent ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${idx + 1}. ${s.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? pptColor : textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      onPressed: controller.prevSlide,
                    ),
                    Obx(() => Text(
                          'شريحة ${controller.currentSlideIndex.value + 1} من ${pres.slides.length}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        )),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      onPressed: controller.nextSlide,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Renders a PowerPoint slide as a proportional 16:9 / 4:3 Vector Scene Graph Canvas
  Widget _buildSlideSceneGraphCanvas(
    BuildContext context,
    PptxPresentation pres,
    PptxSlide slide,
    Color pptColor,
  ) {
    final slideBg = slide.backgroundColorHex != null
        ? (_tryParseHexColor(slide.backgroundColorHex!) ?? Colors.white)
        : Colors.white;

    return AspectRatio(
      aspectRatio: pres.aspectRatio,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final canvasW = constraints.maxWidth;
          final canvasH = constraints.maxHeight;
          final scaleFactor = (canvasW / 720.0).clamp(0.42, 1.4);

          return Container(
            width: canvasW,
            height: canvasH,
            decoration: BoxDecoration(
              color: slideBg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.black12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                for (final elem in slide.elements)
                  Positioned(
                    left: elem.xFrac * canvasW,
                    top: elem.yFrac * canvasH,
                    width: elem.wFrac * canvasW,
                    height: elem.hFrac * canvasH,
                    child: _buildSceneGraphElementWidget(elem, scaleFactor, pptColor),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSceneGraphElementWidget(
    PptxSlideElement elem,
    double scaleFactor,
    Color pptColor,
  ) {
    if (elem.type == PptxElementType.image && elem.imageDataUrl != null) {
      final uri = Uri.tryParse(elem.imageDataUrl!);
      final bytes = uri?.data?.contentAsBytes();
      if (bytes == null) return const SizedBox.shrink();
      return Image.memory(bytes, fit: BoxFit.contain);
    }

    if (elem.type == PptxElementType.table && elem.tableRows.isNotEmpty) {
      return SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade400, width: 0.7),
          children: [
            for (int r = 0; r < elem.tableRows.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: r == 0 ? pptColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.9),
                ),
                children: [
                  for (final cellText in elem.tableRows[r])
                    Padding(
                      padding: EdgeInsets.all(4 * scaleFactor),
                      child: Text(
                        cellText,
                        style: TextStyle(
                          fontSize: (11 * scaleFactor).clamp(8.0, 16.0),
                          fontWeight: r == 0 ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    }

    final shapeBg = elem.fillColorHex != null ? _tryParseHexColor(elem.fillColorHex!) : null;

    return Container(
      padding: EdgeInsets.all(6 * scaleFactor),
      decoration: shapeBg != null
          ? BoxDecoration(
              color: shapeBg,
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in elem.paragraphs)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2 * scaleFactor),
                child: Text(
                  p.isBullet ? '•  ${p.text}' : p.text,
                  textAlign: p.align == 'center'
                      ? TextAlign.center
                      : (p.align == 'right' ? TextAlign.right : TextAlign.start),
                  style: TextStyle(
                    fontSize: ((p.fontSizePt ?? (elem.isTitle ? 22.0 : 14.0)) * scaleFactor)
                        .clamp(9.5, 32.0),
                    fontWeight: p.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: p.isItalic ? FontStyle.italic : FontStyle.normal,
                    color: p.colorHex != null
                        ? (_tryParseHexColor(p.colorHex!) ?? Colors.black87)
                        : (elem.isTitle ? const Color(0xFF1E293B) : Colors.black87),
                    height: 1.28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideStructuredCard(BuildContext context, PptxSlide slide, Color pptColor) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = theme.cardColor;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: pptColor,
            ),
          ),
          const Divider(height: 20),
          for (final bp in slide.bulletPoints)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: pptColor)),
                  Expanded(
                    child: SelectableText(
                      bp,
                      style: TextStyle(fontSize: 14.5, color: textPrimary, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          if (slide.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: slide.images.map((imgBase64) {
                final uri = Uri.tryParse(imgBase64);
                final bytes = uri?.data?.contentAsBytes();
                if (bytes == null) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// WPS DrawAreaViewPlay: Fullscreen Slide Show Mode with Live Laser Pen Pointer
  Widget _buildFullscreenPresentationPlayMode(BuildContext context) {
    final pres = controller.presentation.value;
    if (pres == null || pres.slides.isEmpty) {
      return const SizedBox.shrink();
    }
    const pptColor = Color(0xFFD24726);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Slide PageView
            Center(
              child: PageView.builder(
                controller: controller.pptPageController,
                physics: controller.isLaserPenEnabled.value
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  controller.currentSlideIndex.value = idx;
                  controller.clearLaserStrokes();
                },
                itemCount: pres.slides.length,
                itemBuilder: (ctx, idx) {
                  final slide = pres.slides[idx];
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: slide.elements.isNotEmpty
                          ? _buildSlideSceneGraphCanvas(ctx, pres, slide, pptColor)
                          : _buildSlideStructuredCard(ctx, slide, pptColor),
                    ),
                  );
                },
              ),
            ),

            // Laser Pen Annotation Overlay (PlayModePenSettingView)
            if (controller.isLaserPenEnabled.value)
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    controller.laserStrokePoints.add(details.localPosition);
                  },
                  onPanEnd: (_) {
                    controller.laserStrokePoints.add(null);
                  },
                  child: Obx(() => CustomPaint(
                        painter: _LaserPenPainter(controller.laserStrokePoints.toList()),
                        size: Size.infinite,
                      )),
                ),
              ),

            // Top Floating Presentation Control Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.togglePresentationPlayMode,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('إنهاء العرض'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: controller.toggleLaserPen,
                        icon: Icon(
                          Icons.draw_rounded,
                          color: controller.isLaserPenEnabled.value ? Colors.redAccent : Colors.white,
                        ),
                        tooltip: 'مؤشر القلم الليزري (Laser Pen)',
                      ),
                      if (controller.isLaserPenEnabled.value)
                        IconButton(
                          onPressed: controller.clearLaserStrokes,
                          icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white70),
                          tooltip: 'مسح الرسم',
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Floating Slide Controls
            Positioned(
              bottom: 14,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    onPressed: controller.prevSlide,
                  ),
                  Obx(() => Text(
                        '${controller.currentSlideIndex.value + 1} / ${pres.slides.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                    onPressed: controller.nextSlide,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetBar(BuildContext context, Color badgeColor) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    if (controller.isExcelFamily && controller.workbook.value != null) {
      final sheets = controller.workbook.value!.sheets;
      if (sheets.length <= 1) return const SizedBox.shrink();

      return Container(
        color: cardBg,
        height: 46,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: sheets.length,
          itemBuilder: (ctx, idx) {
            final isSelected = controller.activeSheetIndex.value == idx;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(sheets[idx].name),
                  selected: isSelected,
                  onSelected: (_) => controller.switchSheet(idx),
                  selectedColor: badgeColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? badgeColor : textPrimaryColor,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Color? _tryParseHexColor(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final v = int.tryParse('FF$cleaned', radix: 16);
      if (v != null) return Color(v);
    } else if (cleaned.length == 8) {
      final v = int.tryParse(cleaned, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }
}

class _LaserPenPainter extends CustomPainter {
  final List<Offset?> points;

  _LaserPenPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF1744)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LaserPenPainter oldDelegate) => true;
}

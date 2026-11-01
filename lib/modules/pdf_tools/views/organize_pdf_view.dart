import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_result_sheet.dart';

class _OrganizePageItem {
  final int originalPageNumber; // 1-based original page index
  final int originalZeroIndex;  // 0-based index
  int rotationTurns = 0; // 0, 1 (90°), 2 (180°), 3 (270°)

  _OrganizePageItem({
    required this.originalPageNumber,
    required this.originalZeroIndex,
  });
}

class OrganizePdfView extends StatefulWidget {
  final String? initialFilePath;

  const OrganizePdfView({super.key, this.initialFilePath});

  @override
  State<OrganizePdfView> createState() => _OrganizePdfViewState();
}

class _OrganizePdfViewState extends State<OrganizePdfView> {
  String? _filePath;
  String? _fileName;
  pdfrx.PdfDocument? _rxDocument;
  List<_OrganizePageItem> _pages = [];
  final Set<int> _selectedOriginalIndices = {}; // set of originalZeroIndex

  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _loadFile(widget.initialFilePath!);
    }
  }

  @override
  void dispose() {
    _rxDocument?.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        await _loadFile(result.files.single.path!);
      }
    } catch (e) {
      Get.snackbar('error'.tr, e.toString(), backgroundColor: Colors.red.shade800, colorText: Colors.white);
    }
  }

  Future<void> _loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();

      final rxDoc = await pdfrx.PdfDocument.openFile(path);

      setState(() {
        _filePath = path;
        _fileName = p.basename(path);
        _rxDocument?.dispose();
        _rxDocument = rxDoc;
        _selectedOriginalIndices.clear();
        _pages = List.generate(
          count,
          (i) => _OrganizePageItem(
            originalPageNumber: i + 1,
            originalZeroIndex: i,
          ),
        );
      });
    } catch (e) {
      Get.snackbar('error'.tr, 'تعذر فتح الملف / Failed to read PDF: $e', backgroundColor: Colors.red.shade800, colorText: Colors.white);
    }
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  void _rotateSelectedPages() {
    if (_selectedOriginalIndices.isEmpty) return;
    setState(() {
      for (final p in _pages) {
        if (_selectedOriginalIndices.contains(p.originalZeroIndex)) {
          p.rotationTurns = (p.rotationTurns + 1) % 4;
        }
      }
    });
    Get.snackbar('تم', 'تم تدوير الصفحات المحددة 90 درجة', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
  }

  void _rotatePage(int index) {
    setState(() {
      _pages[index].rotationTurns = (_pages[index].rotationTurns + 1) % 4;
    });
  }

  void _deleteSelectedPages() {
    if (_selectedOriginalIndices.isEmpty) return;
    setState(() {
      _pages.removeWhere((item) => _selectedOriginalIndices.contains(item.originalZeroIndex));
      _selectedOriginalIndices.clear();
    });
    Get.snackbar('تم', 'تم حذف الصفحات المحددة من القائمة', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
  }

  void _selectAll() {
    setState(() {
      if (_selectedOriginalIndices.length == _pages.length) {
        _selectedOriginalIndices.clear();
      } else {
        _selectedOriginalIndices.addAll(_pages.map((e) => e.originalZeroIndex));
      }
    });
  }

  Future<void> _saveOrganized({bool extractSelectedOnly = false}) async {
    if (_filePath == null) return;

    final List<_OrganizePageItem> targetItems;
    if (extractSelectedOnly) {
      if (_selectedOriginalIndices.isEmpty) {
        Get.snackbar('تنبيه', 'يرجى تحديد صفحة واحدة على الأقل للاستخراج', backgroundColor: Colors.orange.shade800, colorText: Colors.white);
        return;
      }
      targetItems = _pages
          .where((p) => _selectedOriginalIndices.contains(p.originalZeroIndex))
          .toList();
    } else {
      if (_pages.isEmpty) {
        Get.snackbar('تنبيه', 'المستند فارغ، يرجى الإبقاء على صفحة واحدة على الأقل', backgroundColor: Colors.orange.shade800, colorText: Colors.white);
        return;
      }
      targetItems = List.from(_pages);
    }

    final targetIndices = targetItems.map((p) => p.originalZeroIndex).toList();
    final Map<int, int> pageRotations = {};
    for (int i = 0; i < targetItems.length; i++) {
      if (targetItems[i].rotationTurns != 0) {
        pageRotations[i] = targetItems[i].rotationTurns;
      }
    }

    final origBase = p.basenameWithoutExtension(_filePath!);
    final outputName = extractSelectedOnly
        ? '${origBase}_extracted_${targetIndices.length}pages'
        : '${origBase}_organized';

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressStatus = 'جاري بناء وحفظ ملف PDF الجديد...';
    });

    final res = await PdfToolsService().organizePdf(
      _filePath!,
      orderedPageIndices: targetIndices,
      pageRotations: pageRotations,
      outputFileName: outputName,
      onProgress: (prog, status) {
        setState(() {
          _progress = prog;
          _progressStatus = status;
        });
      },
    );

    setState(() {
      _isProcessing = false;
    });

    if (res.isSuccess && mounted) {
      ToolResultSheet.show(
        context,
        result: res,
        title: extractSelectedOnly ? 'استخراج الصفحات' : 'تنظيم الصفحات',
      );
    } else {
      Get.snackbar(
        'error'.tr,
        res.errorMessage ?? 'فشلت العملية',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('تنظيم صفحات PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_fileName != null)
              Text(
                _fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
          ],
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_filePath != null)
            IconButton(
              icon: const Icon(Icons.folder_open_rounded),
              tooltip: 'تغيير الملف',
              onPressed: _pickFile,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_filePath == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 64, color: primaryColor.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'أعد ترتيب الصفحات، أو احذف ما لا تحتاجه، أو استخرج صفحات معينة في ملف PDF جديد دون المساس بالمستند الأصلي.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('اختر مستند PDF لتنظيمه'),
                      onPressed: _pickFile,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Top control toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'الصفحات (${_pages.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: Icon(
                          _selectedOriginalIndices.length == _pages.length
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _selectedOriginalIndices.length == _pages.length ? 'إلغاء التحديد' : 'تحديد الكل',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: _selectAll,
                      ),
                      if (_selectedOriginalIndices.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.rotate_right_rounded, size: 20),
                          tooltip: 'تدوير الصفحات المحددة 90°',
                          onPressed: _rotateSelectedPages,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'حذف الصفحات المحددة',
                          onPressed: _deleteSelectedPages,
                        ),
                      ],
                    ],
                  ),
                ),
                // Pages Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 750
                          ? 4
                          : (MediaQuery.of(context).size.width > 500 ? 3 : 2),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      final isSelected = _selectedOriginalIndices.contains(item.originalZeroIndex);

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? primaryColor : (isDark ? const Color(0xFF22304D) : theme.dividerColor.withOpacity(0.3)),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Header badge with original page number & checkbox
                            Container(
                              color: isSelected ? primaryColor.withOpacity(0.12) : theme.scaffoldBackgroundColor,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${index + 1} (ص ${item.originalPageNumber})',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedOriginalIndices.remove(item.originalZeroIndex);
                                        } else {
                                          _selectedOriginalIndices.add(item.originalZeroIndex);
                                        }
                                      });
                                    },
                                    child: Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      size: 18,
                                      color: isSelected ? primaryColor : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Thumbnail via pdfrx.PdfPageView
                            Expanded(
                              child: _rxDocument != null
                                  ? Container(
                                      padding: const EdgeInsets.all(4),
                                      color: Colors.white,
                                      child: RotatedBox(
                                        quarterTurns: item.rotationTurns,
                                        child: pdfrx.PdfPageView(
                                          document: _rxDocument,
                                          pageNumber: item.originalPageNumber,
                                          maximumDpi: 100,
                                        ),
                                      ),
                                    )
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            // Move left/right, rotate, and delete actions
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              color: theme.scaffoldBackgroundColor,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                    tooltip: 'تقديم للأمام',
                                    onPressed: index > 0 ? () => _movePage(index, index - 1) : null,
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.rotate_right_rounded, size: 16),
                                    tooltip: 'تدوير 90°',
                                    onPressed: () => _rotatePage(index),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                    tooltip: 'حذف الصفحة',
                                    onPressed: () {
                                      setState(() {
                                        _pages.removeAt(index);
                                        _selectedOriginalIndices.remove(item.originalZeroIndex);
                                      });
                                    },
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                    tooltip: 'تأخير للخلف',
                                    onPressed: index < _pages.length - 1 ? () => _movePage(index, index + 1) : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          // Bottom action panel
          if (_filePath != null && _pages.isNotEmpty && !_isProcessing)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_selectedOriginalIndices.isNotEmpty) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.file_download_outlined, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'استخراج ${_selectedOriginalIndices.length} صفحات',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            onPressed: () => _saveOrganized(extractSelectedOnly: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'حفظ الترتيب (${_pages.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          onPressed: () => _saveOrganized(extractSelectedOnly: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: _progress > 0 ? _progress : null),
                      const SizedBox(height: 20),
                      Text(
                        _progressStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

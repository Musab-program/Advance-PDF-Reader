import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import '../../../core/utils/app_toast.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_empty_view.dart';
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
  final TextEditingController _outputNameController = TextEditingController();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressStatus = '';
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _isLoadingInitial = true;
      _loadFile(widget.initialFilePath!).whenComplete(() {
        if (mounted) setState(() => _isLoadingInitial = false);
      });
    }
  }

  @override
  void dispose() {
    _outputNameController.dispose();
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
      AppToast.showError(e.toString());
    }
  }

  Future<void> _loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final rxDoc = await pdfrx.PdfDocument.openFile(path);
      final count = rxDoc.pages.length;

      setState(() {
        _filePath = path;
        _fileName = p.basename(path);
        _outputNameController.text = '${p.basenameWithoutExtension(path)}_organized';
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
      AppToast.showError('تعذر فتح الملف: $e');
    }
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  void _rotateSelectedPages({bool clockwise = true}) {
    if (_selectedOriginalIndices.isEmpty) return;
    setState(() {
      for (final p in _pages) {
        if (_selectedOriginalIndices.contains(p.originalZeroIndex)) {
          p.rotationTurns = (p.rotationTurns + (clockwise ? 1 : 3)) % 4;
        }
      }
    });
    AppToast.showSuccess(clockwise ? 'تم تدوير الصفحات المحددة 90° لليمين' : 'تم تدوير الصفحات المحددة 90° لليسار');
  }

  void _rotatePage(int index, {bool clockwise = true}) {
    setState(() {
      _pages[index].rotationTurns = (_pages[index].rotationTurns + (clockwise ? 1 : 3)) % 4;
    });
  }

  void _deleteSelectedPages() {
    if (_selectedOriginalIndices.isEmpty) return;
    setState(() {
      _pages.removeWhere((item) => _selectedOriginalIndices.contains(item.originalZeroIndex));
      _selectedOriginalIndices.clear();
    });
    AppToast.showSuccess('تم حذف الصفحات المحددة');
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
        AppToast.showWarning('يرجى تحديد صفحة واحدة على الأقل للاستخراج');
        return;
      }
      targetItems = _pages
          .where((p) => _selectedOriginalIndices.contains(p.originalZeroIndex))
          .toList();
    } else {
      if (_pages.isEmpty) {
        AppToast.showWarning('المستند فارغ، يرجى الإبقاء على صفحة واحدة على الأقل');
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

    final outputName = _outputNameController.text.trim();
    if (outputName.isEmpty) {
      AppToast.showWarning('يرجى إدخال اسم الملف الناتج قبل الحفظ');
      return;
    }

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
      AppToast.showError(res.errorMessage ?? 'فشلت العملية');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final primaryColor = theme.primaryColor;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

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
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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
              onPressed: _isProcessing ? null : _pickFile,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoadingInitial)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'opening_file'.tr,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else if (_filePath == null)
            ToolEmptyView(
              imagePath: 'assets/vector/organize_pdf.png',
              title: 'تنظيم صفحات PDF',
              description: 'أعد ترتيب الصفحات، أو احذف ما لا تحتاجه، أو استخرج صفحات معينة في ملف PDF جديد بكل سهولة.',
              actionLabel: 'اختر مستند PDF لتنظيمه',
              actionIcon: Icons.picture_as_pdf_rounded,
              onAction: _pickFile,
            )
          else
            Column(
              children: [
                // Top control toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _selectAll,
                        icon: Icon(
                          _selectedOriginalIndices.length == _pages.length ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        label: Text(_selectedOriginalIndices.length == _pages.length ? 'إلغاء التحديد' : 'تحديد الكل (${_pages.length})'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                      const Spacer(),
                      if (_selectedOriginalIndices.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.rotate_left_rounded),
                          tooltip: 'تدوير الصفحات المحددة 90° لليسار',
                          color: primaryColor,
                          onPressed: () => _rotateSelectedPages(clockwise: false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.rotate_right_rounded),
                          tooltip: 'تدوير الصفحات المحددة 90° لليمين',
                          color: primaryColor,
                          onPressed: () => _rotateSelectedPages(clockwise: true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'حذف الصفحات المحددة',
                          color: Colors.redAccent,
                          onPressed: _deleteSelectedPages,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'استخدم الأسهم ◄ ► لتغيير مكان الصفحة في المستند',
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                  ),
                ),
                // Grid of pages
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      final isSelected = _selectedOriginalIndices.contains(item.originalZeroIndex);

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : (isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3)),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Page header inside card
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  InkWell(
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
                                      size: 20,
                                      color: isSelected ? primaryColor : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ص ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? primaryColor : null,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.rotate_right_rounded, size: 18),
                                    tooltip: 'تدوير 90°',
                                    onPressed: () => _rotatePage(index),
                                  ),
                                ],
                              ),
                            ),
                            // Page thumbnail
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: RotatedBox(
                                          quarterTurns: item.rotationTurns,
                                          child: _rxDocument != null
                                              ? pdfrx.PdfPageView(
                                                  document: _rxDocument!,
                                                  pageNumber: item.originalPageNumber,
                                                )
                                              : const Center(child: CircularProgressIndicator()),
                                        ),
                                      ),
                                    ),
                                    if (item.rotationTurns != 0)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.72),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${item.rotationTurns * 90}°',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            // Position controls
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.black26 : Colors.grey.shade100),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'تحريك للسابق (ص $index)',
                                    onPressed: index > 0 ? () => _movePage(index, index - 1) : null,
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
                                    icon: Icon(
                                      isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'تحريك للتالي (ص ${index + 2})',
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
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _outputNameController,
                        decoration: InputDecoration(
                          labelText: 'اسم الملف الناتج',
                          hintText: 'مثال: document_organized',
                          hintStyle: const TextStyle(fontSize: 12),
                          isDense: true,
                          prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                          suffixText: '.pdf',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
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

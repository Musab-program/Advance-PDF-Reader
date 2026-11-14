import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import '../../../core/utils/app_toast.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_empty_view.dart';
import '../widgets/tool_result_sheet.dart';

class MergePdfView extends StatefulWidget {
  final String? initialFilePath;
  final List<String>? initialFilePaths;

  const MergePdfView({
    super.key,
    this.initialFilePath,
    this.initialFilePaths,
  });

  @override
  State<MergePdfView> createState() => _MergePdfViewState();
}

class _MergePdfItem {
  final String path;
  final String name;
  final int size;
  int? pageCount;

  _MergePdfItem({
    required this.path,
    required this.name,
    required this.size,
    this.pageCount,
  });
}

class _MergePdfViewState extends State<MergePdfView> {
  final List<_MergePdfItem> _items = [];
  final TextEditingController _nameController = TextEditingController();
  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressStatus = '';
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    final hasPaths = (widget.initialFilePaths != null && widget.initialFilePaths!.isNotEmpty) ||
        widget.initialFilePath != null;
    if (hasPaths) {
      _isLoadingInitial = true;
      final future = (widget.initialFilePaths != null && widget.initialFilePaths!.isNotEmpty)
          ? _loadInitialFiles(widget.initialFilePaths!)
          : _loadInitialFile(widget.initialFilePath!);
      future.whenComplete(() {
        if (mounted) setState(() => _isLoadingInitial = false);
      });
    }
  }

  Future<void> _loadInitialFiles(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      int size = 0;
      int? pCount;
      try {
        size = await file.length();
        final rxDoc = await pdfrx.PdfDocument.openFile(path);
        pCount = rxDoc.pages.length;
        await rxDoc.dispose();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _items.add(_MergePdfItem(
            path: path,
            name: p.basename(path),
            size: size,
            pageCount: pCount,
          ));
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = '${p.basenameWithoutExtension(path)}_merged';
          }
        });
      }
    }
  }

  Future<void> _loadInitialFile(String path) async {
    await _loadInitialFiles([path]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        for (final path in result.paths) {
          if (path != null && !_items.any((e) => e.path == path)) {
            final file = File(path);
            int size = 0;
            int? pCount;
            try {
              size = await file.length();
              final rxDoc = await pdfrx.PdfDocument.openFile(path);
              pCount = rxDoc.pages.length;
              await rxDoc.dispose();
            } catch (_) {}

            _items.add(_MergePdfItem(
              path: path,
              name: p.basename(path),
              size: size,
              pageCount: pCount,
            ));
          }
        }
        if (_nameController.text.trim().isEmpty && _items.isNotEmpty) {
          _nameController.text = '${p.basenameWithoutExtension(_items.first.path)}_merged';
        }
        setState(() {});
      }
    } catch (e) {
      AppToast.showError(e.toString());
    }
  }

  Future<void> _startMerge() async {
    if (_items.length < 2) {
      AppToast.showWarning('يرجى اختيار ملفين على الأقل للدمج');
      return;
    }

    final customName = _nameController.text.trim();
    if (customName.isEmpty) {
      AppToast.showWarning('يرجى إدخال اسم الملف الناتج قبل المتابعة');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressStatus = 'جاري تحضير الملفات...';
    });

    final inputPaths = _items.map((e) => e.path).toList();

    final result = await PdfToolsService().mergePdfs(
      inputPaths,
      outputFileName: customName,
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

    if (result.isSuccess && mounted) {
      ToolResultSheet.show(
        context,
        result: result,
        title: 'tool_merge_pdf'.tr,
      );
    } else {
      AppToast.showError(result.errorMessage ?? 'فشلت عملية الدمج');
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
        title: Text('tool_merge_pdf'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الملفات المختارة (${_items.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة ملفات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _isProcessing ? null : _pickFiles,
                      ),
                    ],
                  ),
                ),
              if (_isLoadingInitial)
                Expanded(
                  child: Center(
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
                  ),
                )
              else if (_items.isEmpty)
                Expanded(
                  child: ToolEmptyView(
                    imagePath: 'assets/vector/merge_pdf.png',
                    title: 'tool_merge_pdf'.tr,
                    description: 'دمج عدة ملفات PDF في مستند واحد مرتب حسب رغبتك بسهولة وسرعة.',
                    actionLabel: 'اختر ملفات PDF',
                    actionIcon: Icons.picture_as_pdf_rounded,
                    onAction: _pickFiles,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'اسحب المقبض ≡ لإعادة ترتيب الملفات قبل الدمج',
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        key: ValueKey(item.path),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withValues(alpha: 0.12),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${_formatSize(item.size)}${item.pageCount != null ? ' • ${item.pageCount} صفحة' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(index);
                                  });
                                },
                              ),
                              const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (_items.length >= 2 && !_isProcessing)
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
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'اسم الملف الناتج',
                          hintText: 'مثال: AuraPDF_merged',
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
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.merge_type_rounded),
                          label: Text(
                            'دمج ${_items.length} ملفات الآن',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: _startMerge,
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

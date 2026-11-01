import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_result_sheet.dart';

class MergePdfView extends StatefulWidget {
  const MergePdfView({super.key});

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
              final bytes = await file.readAsBytes();
              final doc = PdfDocument(inputBytes: bytes);
              pCount = doc.pages.count;
              doc.dispose();
            } catch (_) {}

            _items.add(_MergePdfItem(
              path: path,
              name: p.basename(path),
              size: size,
              pageCount: pCount,
            ));
          }
        }
        setState(() {});
      }
    } catch (e) {
      Get.snackbar('error'.tr, e.toString(), backgroundColor: Colors.red.shade800, colorText: Colors.white);
    }
  }

  Future<void> _startMerge() async {
    if (_items.length < 2) {
      Get.snackbar(
        'error'.tr,
        'يرجى اختيار ملفين على الأقل للدمج / Please select at least 2 files',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressStatus = 'جاري تحضير الملفات...';
    });

    final inputPaths = _items.map((e) => e.path).toList();
    final customName = _nameController.text.trim();

    final result = await PdfToolsService().mergePdfs(
      inputPaths,
      outputFileName: customName.isNotEmpty ? customName : null,
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
      Get.snackbar(
        'error'.tr,
        result.errorMessage ?? 'فشلت عملية الدمج',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
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
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
              if (_items.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.merge_type_rounded, size: 64, color: primaryColor.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'desc_merge_pdf'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: const Text('اختر ملفات PDF'),
                            onPressed: _pickFiles,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'اسحب المقبض ≡ لإعادة ترتيب الملفات قبل الدمج',
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
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
                            color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.12),
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
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
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
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
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
                          hintText: 'اسم الملف الناتج (اختياري)',
                          hintStyle: const TextStyle(fontSize: 12),
                          isDense: true,
                          prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                          suffixText: '.pdf',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
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

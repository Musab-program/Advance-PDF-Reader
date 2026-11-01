import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_result_sheet.dart';

enum SplitMode { range, allPages, customRanges }

class SplitPdfView extends StatefulWidget {
  final String? initialFilePath;

  const SplitPdfView({super.key, this.initialFilePath});

  @override
  State<SplitPdfView> createState() => _SplitPdfViewState();
}

class _SplitPdfViewState extends State<SplitPdfView> {
  String? _filePath;
  String? _fileName;
  int _totalPages = 0;
  int _fileSize = 0;

  SplitMode _splitMode = SplitMode.range;
  final TextEditingController _fromPageController = TextEditingController(text: '1');
  final TextEditingController _toPageController = TextEditingController();
  final TextEditingController _customRangesController = TextEditingController(text: '1-2, 3-4');
  final TextEditingController _outputNameController = TextEditingController();

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
    _fromPageController.dispose();
    _toPageController.dispose();
    _customRangesController.dispose();
    _outputNameController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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
      final size = await file.length();
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();

      setState(() {
        _filePath = path;
        _fileName = p.basename(path);
        _fileSize = size;
        _totalPages = count;
        _fromPageController.text = '1';
        _toPageController.text = count > 5 ? '5' : '$count';
        _customRangesController.text = count >= 4 ? '1-2, 3-$count' : '1, 2';
        _outputNameController.text = p.basenameWithoutExtension(path);
      });
    } catch (e) {
      final err = e.toString().toLowerCase();
      String msg = 'الملف تالف أو تعذر قراءته';
      if (err.contains('password') || err.contains('encrypt')) {
        msg = 'الملف محمي بكلمة مرور / Password protected PDF';
      }
      Get.snackbar('error'.tr, msg, backgroundColor: Colors.red.shade800, colorText: Colors.white);
    }
  }

  List<List<int>> _parseRanges() {
    final List<List<int>> result = [];
    if (_splitMode == SplitMode.allPages) {
      for (int i = 0; i < _totalPages; i++) {
        result.add([i]);
      }
    } else if (_splitMode == SplitMode.range) {
      final from = int.tryParse(_fromPageController.text.trim()) ?? 1;
      final to = int.tryParse(_toPageController.text.trim()) ?? _totalPages;
      final start = (from - 1).clamp(0, _totalPages - 1);
      final end = (to - 1).clamp(start, _totalPages - 1);

      final List<int> group = [];
      for (int i = start; i <= end; i++) {
        group.add(i);
      }
      result.add(group);
    } else if (_splitMode == SplitMode.customRanges) {
      final text = _customRangesController.text.trim();
      final parts = text.split(',');
      for (final rawPart in parts) {
        final part = rawPart.trim();
        if (part.contains('-')) {
          final bounds = part.split('-');
          final s = (int.tryParse(bounds[0].trim()) ?? 1) - 1;
          final e = (int.tryParse(bounds[1].trim()) ?? _totalPages) - 1;
          final realStart = s.clamp(0, _totalPages - 1);
          final realEnd = e.clamp(realStart, _totalPages - 1);
          final List<int> grp = [];
          for (int i = realStart; i <= realEnd; i++) {
            grp.add(i);
          }
          if (grp.isNotEmpty) result.add(grp);
        } else {
          final single = (int.tryParse(part) ?? 1) - 1;
          if (single >= 0 && single < _totalPages) {
            result.add([single]);
          }
        }
      }
    }
    return result;
  }

  Future<void> _startSplit() async {
    if (_filePath == null) return;

    final ranges = _parseRanges();
    if (ranges.isEmpty) {
      Get.snackbar('error'.tr, 'يرجى تحديد نطاق صفحات صالح', backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressStatus = 'جاري تقسيم المستند...';
    });

    final res = await PdfToolsService().splitPdf(
      _filePath!,
      pageRanges: ranges,
      baseOutputName: _outputNameController.text.trim(),
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
        title: 'tool_split_pdf'.tr,
      );
    } else {
      Get.snackbar(
        'error'.tr,
        res.errorMessage ?? 'فشلت عملية التقسيم',
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
        title: Text('tool_split_pdf'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
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
                    Icon(Icons.call_split_rounded, size: 64, color: primaryColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'desc_split_pdf'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                      label: const Text('اختر ملف PDF للتقسيم'),
                      onPressed: _pickFile,
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.picture_as_pdf_rounded, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fileName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '$_totalPages صفحات • ${_formatSize(_fileSize)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _pickFile,
                          child: const Text('تغيير', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Split Mode selection
                  Text(
                    'طريقة التقسيم',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<SplitMode>(
                          value: SplitMode.range,
                          groupValue: _splitMode,
                          activeColor: primaryColor,
                          title: const Text('نطاق صفحات محدد', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('استخراج الصفحات من رقم إلى رقم', style: TextStyle(fontSize: 11)),
                          onChanged: (val) => setState(() => _splitMode = val!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<SplitMode>(
                          value: SplitMode.allPages,
                          groupValue: _splitMode,
                          activeColor: primaryColor,
                          title: const Text('فصل كل صفحة في ملف مستقل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('إنشاء $_totalPages ملفات منفصلة', style: const TextStyle(fontSize: 11)),
                          onChanged: (val) => setState(() => _splitMode = val!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<SplitMode>(
                          value: SplitMode.customRanges,
                          groupValue: _splitMode,
                          activeColor: primaryColor,
                          title: const Text('نطاقات مخصصة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('مثال: 1-3, 4-6, 7', style: TextStyle(fontSize: 11)),
                          onChanged: (val) => setState(() => _splitMode = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Range inputs based on selection
                  if (_splitMode == SplitMode.range)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _fromPageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'من صفحة',
                                hintText: '1',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _toPageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'إلى صفحة',
                                hintText: '$_totalPages',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_splitMode == SplitMode.customRanges)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _customRangesController,
                        decoration: InputDecoration(
                          labelText: 'النطاقات (مفصولة بفواصل)',
                          hintText: '1-2, 3-5, 6',
                          helperText: 'أرقام الصفحات من 1 إلى $_totalPages',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  // Output name field
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _outputNameController,
                      decoration: InputDecoration(
                        labelText: 'بادئة اسم الملفات الناتجة',
                        hintText: 'document_split',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_filePath != null && !_isProcessing)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.call_split_rounded),
                    label: const Text('تقسيم المستند الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: _startSplit,
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

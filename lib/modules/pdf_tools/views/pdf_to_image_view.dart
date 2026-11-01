import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_result_sheet.dart';

enum ExportScope { all, single, range }

class PdfToImageView extends StatefulWidget {
  final String? initialFilePath;

  const PdfToImageView({super.key, this.initialFilePath});

  @override
  State<PdfToImageView> createState() => _PdfToImageViewState();
}

class _PdfToImageViewState extends State<PdfToImageView> {
  String? _filePath;
  String? _fileName;
  int _totalPages = 0;
  int _fileSize = 0;

  ExportScope _scope = ExportScope.all;
  int _singlePage = 1;
  final TextEditingController _fromPageController = TextEditingController(text: '1');
  final TextEditingController _toPageController = TextEditingController();

  String _format = 'png'; // 'png' or 'jpg'
  int _quality = 85; // For JPG
  double _scale = 2.0; // High resolution default
  bool _exportAsLongPicture = false; // WPS-style continuous stitched picture

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
        _singlePage = 1;
        _fromPageController.text = '1';
        _toPageController.text = count > 10 ? '10' : '$count';
      });
    } catch (e) {
      Get.snackbar('error'.tr, 'تعذر فتح الملف / Failed to read PDF: $e', backgroundColor: Colors.red.shade800, colorText: Colors.white);
    }
  }

  List<int> _computePagesToExport() {
    final List<int> list = [];
    if (_scope == ExportScope.all) {
      for (int i = 1; i <= _totalPages; i++) {
        list.add(i);
      }
    } else if (_scope == ExportScope.single) {
      list.add(_singlePage.clamp(1, _totalPages));
    } else if (_scope == ExportScope.range) {
      final from = (int.tryParse(_fromPageController.text.trim()) ?? 1).clamp(1, _totalPages);
      final to = (int.tryParse(_toPageController.text.trim()) ?? _totalPages).clamp(from, _totalPages);
      for (int i = from; i <= to; i++) {
        list.add(i);
      }
    }
    return list;
  }

  Future<void> _startExport() async {
    if (_filePath == null) return;

    final targetPages = _computePagesToExport();
    if (targetPages.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى تحديد صفحة واحدة على الأقل للتصدير', backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressStatus = 'جاري تصدير الصفحات كصور...';
    });

    final res = await PdfToolsService().pdfToImages(
      _filePath!,
      pageNumbers: targetPages,
      format: _format,
      jpgQuality: _quality,
      scale: _scale,
      asLongPicture: _exportAsLongPicture,
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
        title: 'tool_pdf_to_img'.tr,
      );
    } else {
      Get.snackbar(
        'error'.tr,
        res.errorMessage ?? 'فشلت عملية التصدير',
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
        title: Text('tool_pdf_to_img'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    Icon(Icons.photo_library_rounded, size: 64, color: primaryColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'desc_pdf_to_img'.tr,
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
                      label: const Text('اختر مستند PDF لتحويله لصور'),
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

                  // Scope selection
                  Text(
                    'نطاق الصفحات للتصدير',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color),
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
                        RadioListTile<ExportScope>(
                          value: ExportScope.all,
                          groupValue: _scope,
                          activeColor: primaryColor,
                          title: Text('كامل صفحات المستند ($_totalPages صفحة)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onChanged: (val) => setState(() => _scope = val!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<ExportScope>(
                          value: ExportScope.range,
                          groupValue: _scope,
                          activeColor: primaryColor,
                          title: const Text('نطاق صفحات محدد', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('تصدير جزء من الصفحات', style: TextStyle(fontSize: 11)),
                          onChanged: (val) => setState(() => _scope = val!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<ExportScope>(
                          value: ExportScope.single,
                          groupValue: _scope,
                          activeColor: primaryColor,
                          title: const Text('صفحة واحدة فقط', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onChanged: (val) => setState(() => _scope = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_scope == ExportScope.range)
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

                  if (_scope == ExportScope.single)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Text('رقم الصفحة:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            onPressed: _singlePage > 1 ? () => setState(() => _singlePage--) : null,
                          ),
                          Text('$_singlePage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            onPressed: _singlePage < _totalPages ? () => setState(() => _singlePage++) : null,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  // Image Format & Resolution
                  Text(
                    'إعدادات الصورة والتنسيق',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const Text('صيغة الإخراج:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('PNG (بدون فقدان)'),
                                  selected: _format == 'png',
                                  onSelected: (val) => setState(() => _format = 'png'),
                                ),
                                ChoiceChip(
                                  label: const Text('JPG (مضغوط)'),
                                  selected: _format == 'jpg',
                                  onSelected: (val) => setState(() => _format = 'jpg'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const Text('طريقة الحفظ:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('صور منفصلة'),
                                  selected: !_exportAsLongPicture,
                                  onSelected: (val) => setState(() => _exportAsLongPicture = false),
                                ),
                                ChoiceChip(
                                  avatar: const Icon(Icons.auto_awesome, size: 14),
                                  label: const Text('صورة طولية مدمجة'),
                                  selected: _exportAsLongPicture,
                                  onSelected: (val) => setState(() => _exportAsLongPicture = true),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const Text('دقة التصدير:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('عالية (2x)'),
                                  selected: _scale == 2.0,
                                  onSelected: (val) => setState(() => _scale = 2.0),
                                ),
                                ChoiceChip(
                                  label: const Text('قياسية (1.5x)'),
                                  selected: _scale == 1.5,
                                  onSelected: (val) => setState(() => _scale = 1.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_format == 'jpg') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text('جودة JPG: $_quality%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Slider(
                                  value: _quality.toDouble(),
                                  min: 50,
                                  max: 100,
                                  divisions: 5,
                                  label: '$_quality%',
                                  onChanged: (val) => setState(() => _quality = val.round()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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
                    icon: const Icon(Icons.photo_library_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'تصدير ${_computePagesToExport().length} صفحات كصور',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    onPressed: _startExport,
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

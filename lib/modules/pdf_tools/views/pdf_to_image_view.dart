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
  final TextEditingController _outputNameController = TextEditingController();

  String _format = 'png'; // 'png' or 'jpg'
  int _quality = 85; // For JPG
  double _scale = 2.0; // High resolution default
  bool _exportAsLongPicture = false; // WPS-style continuous stitched picture

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
    _fromPageController.dispose();
    _toPageController.dispose();
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
      AppToast.showError(e.toString());
    }
  }

  Future<void> _loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final size = await file.length();
      final rxDoc = await pdfrx.PdfDocument.openFile(path);
      final count = rxDoc.pages.length;
      await rxDoc.dispose();

      setState(() {
        _filePath = path;
        _fileName = p.basename(path);
        _fileSize = size;
        _totalPages = count;
        _singlePage = 1;
        _fromPageController.text = '1';
        _toPageController.text = count > 10 ? '10' : '$count';
        _outputNameController.text = '${p.basenameWithoutExtension(path)}_images';
      });
    } catch (e) {
      AppToast.showError('تعذر فتح الملف: $e');
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

    final outputName = _outputNameController.text.trim();
    if (outputName.isEmpty) {
      AppToast.showWarning('يرجى إدخال اسم المجلد/الصور الناتجة أولاً');
      return;
    }

    final targetPages = _computePagesToExport();
    if (targetPages.isEmpty) {
      AppToast.showWarning('يرجى تحديد صفحة واحدة على الأقل للتصدير');
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
      outputName: outputName,
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
      AppToast.showError(res.errorMessage ?? 'فشلت عملية التصدير');
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
              imagePath: 'assets/vector/pdf_to_photos.png',
              title: 'tool_pdf_to_img'.tr,
              description: 'استخراج وتصدير جميع صفحات مستند الـ PDF كصور عالية الدقة وبصيغ متعددة.',
              actionLabel: 'اختر مستند PDF',
              actionIcon: Icons.picture_as_pdf_rounded,
              onAction: _pickFile,
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
                      border: Border.all(color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
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
                              const SizedBox(height: 4),
                              Text(
                                '$_totalPages صفحات • ${_formatSize(_fileSize)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
                  const SizedBox(height: 16),

                  // Output name card (Mandatory)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextField(
                      controller: _outputNameController,
                      decoration: InputDecoration(
                        labelText: 'اسم مجلد وبادئة الصور الناتجة',
                        hintText: 'مثال: document_images',
                        hintStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // WPS-style Stitch option
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _exportAsLongPicture
                            ? primaryColor
                            : (isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3)),
                        width: _exportAsLongPicture ? 1.5 : 1,
                      ),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      value: _exportAsLongPicture,
                      onChanged: (val) => setState(() => _exportAsLongPicture = val),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_exportAsLongPicture ? primaryColor : Colors.grey).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.view_day_rounded,
                          color: _exportAsLongPicture ? primaryColor : Colors.grey,
                        ),
                      ),
                      title: const Text('تصدير كصورة واحدة طويلة (دمج رأسي)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('دمج كل الصفحات المختارة في صورة شريطية واحدة متصلة', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scope selector
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الصفحات المراد تصديرها:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('جميع الصفحات ($_totalPages)'),
                              selected: _scope == ExportScope.all,
                              onSelected: (val) => setState(() => _scope = ExportScope.all),
                            ),
                            ChoiceChip(
                              label: const Text('صفحة واحدة'),
                              selected: _scope == ExportScope.single,
                              onSelected: (val) => setState(() => _scope = ExportScope.single),
                            ),
                            ChoiceChip(
                              label: const Text('نطاق صفحات'),
                              selected: _scope == ExportScope.range,
                              onSelected: (val) => setState(() => _scope = ExportScope.range),
                            ),
                          ],
                        ),
                        if (_scope == ExportScope.single) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text('رقم الصفحة: ', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _singlePage > 1 ? () => setState(() => _singlePage--) : null,
                              ),
                              Text('$_singlePage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: _singlePage < _totalPages ? () => setState(() => _singlePage++) : null,
                              ),
                            ],
                          ),
                        ],
                        if (_scope == ExportScope.range) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _fromPageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'من صفحة',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _toPageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'إلى صفحة',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quality & format card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF22304D) : theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('صيغة الصور:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('PNG (أعلى نقاء)'),
                                  selected: _format == 'png',
                                  onSelected: (val) => setState(() => _format = 'png'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('JPG (حجم أقل)'),
                                  selected: _format == 'jpg',
                                  onSelected: (val) => setState(() => _format = 'jpg'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
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

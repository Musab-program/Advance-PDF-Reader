import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/utils/app_toast.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/tool_empty_view.dart';
import '../widgets/success_dialog.dart';

class _ImageItem {
  final String path;
  final String name;
  final int size;

  _ImageItem({
    required this.path,
    required this.name,
    required this.size,
  });
}

class ImageToPdfView extends StatefulWidget {
  const ImageToPdfView({super.key});

  @override
  State<ImageToPdfView> createState() => _ImageToPdfViewState();
}

class _ImageToPdfViewState extends State<ImageToPdfView> {
  final List<_ImageItem> _images = [];
  final TextEditingController _nameController = TextEditingController();
  double _margin = 20.0;
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

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        for (final path in result.paths) {
          if (path != null && !_images.any((e) => e.path == path)) {
            final file = File(path);
            int size = 0;
            try {
              size = await file.length();
            } catch (_) {}

            _images.add(_ImageItem(
              path: path,
              name: p.basename(path),
              size: size,
            ));
          }
        }
        if (_nameController.text.trim().isEmpty && _images.isNotEmpty) {
          _nameController.text = '${p.basenameWithoutExtension(_images.first.path)}_pdf';
        }
        setState(() {});
      }
    } catch (e) {
      AppToast.showError(e.toString());
    }
  }

  Future<void> _startConvert() async {
    if (_images.isEmpty) {
      AppToast.showWarning('يرجى اختيار صورة واحدة على الأقل');
      return;
    }

    final customName = _nameController.text.trim();
    if (customName.isEmpty) {
      AppToast.showWarning('يرجى إدخال اسم ملف PDF الناتج أولاً');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressStatus = 'جاري تحويل الصور إلى ملف PDF...';
    });

    final inputPaths = _images.map((e) => e.path).toList();

    final result = await PdfToolsService().imagesToPdf(
      inputPaths,
      outputFileName: customName,
      margin: _margin,
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

    if (!mounted) return;

    if (result.isSuccess) {
      SuccessDialog.show(
        context,
        title: 'تم إنشاء ملف PDF بنجاح',
        message: result.message ?? 'تم تحويل الصور وحفظ المستند بنجاح',
        outputFiles: result.outputFiles,
      );
    } else {
      AppToast.showError(result.errorMessage ?? 'فشلت عملية التحويل');
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
        title: Text('tool_img_to_pdf'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الصور المختارة (${_images.length})',
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
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                        label: const Text('إضافة صور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _isProcessing ? null : _pickImages,
                      ),
                    ],
                  ),
                ),
              if (_images.isEmpty)
                Expanded(
                  child: ToolEmptyView(
                    imagePath: 'assets/vector/photos_to_pdf.png',
                    description: 'تحويل مجموعة من الصور إلى مستند PDF عالي الجودة وبسهولة وسرعة.',
                    actionLabel: 'اختر صوراً',
                    actionIcon: Icons.add_photo_alternate_rounded,
                    onAction: _isProcessing ? null : _pickImages,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'اسحب المقبض ≡ لإعادة ترتيب الصور في صفحات PDF',
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                    itemCount: _images.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _images.removeAt(oldIndex);
                        _images.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _images[index];
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(item.path),
                              width: 44,
                              height: 44,
                              cacheWidth: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image_rounded, size: 20),
                              ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            'صفحة ${index + 1} • ${_formatSize(item.size)}',
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
                                    _images.removeAt(index);
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
          if (_images.isNotEmpty && !_isProcessing)
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
                          labelText: 'اسم ملف PDF الناتج',
                          hintText: 'مثال: AuraPDF_images',
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('هوامش الصفحة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('بدون هوامش', style: TextStyle(fontSize: 11)),
                                selected: _margin == 0.0,
                                onSelected: (val) => setState(() => _margin = 0.0),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('هوامش قياسية', style: TextStyle(fontSize: 11)),
                                selected: _margin == 20.0,
                                onSelected: (val) => setState(() => _margin = 20.0),
                              ),
                            ],
                          ),
                        ],
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
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(
                            'إنشاء PDF من ${_images.length} صور',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: _startConvert,
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

/// Modern success dialog with static vector illustration and built-in
/// application reader integration (opens PDF in app reader without system chooser).
class SuccessDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<File> outputFiles;

  const SuccessDialog({
    super.key,
    required this.title,
    this.message,
    this.outputFiles = const [],
  });

  static Future<void> show(
    BuildContext? context, {
    required String title,
    String? message,
    List<File> outputFiles = const [],
  }) {
    final ctx = context ?? Get.overlayContext ?? Get.context;
    final widget = SuccessDialog(
      title: title,
      message: message,
      outputFiles: outputFiles,
    );
    if (ctx != null && ctx.mounted) {
      return LuxuryDialog.showCustom<void>(
        ctx,
        builder: (_) => widget,
      );
    }
    return Get.dialog(
      widget,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 260),
      transitionCurve: Curves.easeOutBack,
    );
  }

  /// Opens the file directly inside our application's built-in viewer
  /// rather than triggering the external Android application chooser dialog.
  static void openFileInsideApp(File file) {
    final path = file.path;
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');

    if (ext == 'pdf') {
      Get.toNamed('/reader', arguments: {
        'singleFile': path,
      });
    } else if (ext == 'txt') {
      Get.toNamed('/txt-reader', arguments: {
        'filePath': path,
        'fileName': p.basename(path),
      });
    } else if (ext == 'html' || ext == 'htm') {
      Get.toNamed('/html-reader', arguments: {
        'filePath': path,
        'fileName': p.basename(path),
      });
    } else if (ext == 'xml') {
      Get.toNamed('/xml-reader', arguments: {
        'filePath': path,
        'fileName': p.basename(path),
      });
    } else if (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp') {
      final ctx = Get.overlayContext ?? Get.context;
      final preview = Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: Colors.black87,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () {
                    if (ctx != null && ctx.mounted) {
                      Navigator.of(ctx, rootNavigator: true).pop();
                    } else {
                      Get.back();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
      if (ctx != null && ctx.mounted) {
        LuxuryDialog.showCustom<void>(ctx, builder: (_) => preview);
      } else {
        Get.dialog(preview, barrierDismissible: true);
      }
    } else {
      OpenFilex.open(path);
    }
  }

  Future<void> _shareFiles(List<File> files) async {
    try {
      final xFiles = files.map((f) => XFile(f.path)).toList();
      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          text: title,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
    } catch (e) {
      Get.snackbar('error'.tr, 'فشلت المشاركة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.titleMedium?.color ?? Colors.black87;
    final textSecondary = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72) ?? Colors.black54;

    final hasFiles = outputFiles.isNotEmpty;
    final firstFile = hasFiles ? outputFiles.first : null;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.85).clamp(280.0, 370.0),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: LuxuryDialog.cardDecoration(context, borderRadius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Completely Static Vector Illustration (No pulsation) ──
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 145, maxWidth: 210),
                child: Image.asset(
                  'assets/vector/Success.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle / message
              if (message != null && message!.isNotEmpty)
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.45,
                  ),
                ),

              const SizedBox(height: 20),

              // Action buttons
              if (hasFiles && firstFile != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: LuxuryDialog.gradientButton(
                    context: context,
                    label: 'فتح الملف الآن',
                    icon: Icons.menu_book_rounded,
                    height: 45,
                    borderRadius: 14,
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      openFileInsideApp(firstFile);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareFiles(outputFiles),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('مشاركة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'تم / إغلاق',
                          style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: LuxuryDialog.gradientButton(
                    context: context,
                    label: 'حسناً',
                    icon: Icons.check_rounded,
                    height: 44,
                    borderRadius: 14,
                    onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

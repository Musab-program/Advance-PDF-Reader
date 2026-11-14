// lib/modules/home/widgets/selection_tools_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/core/utils/app_toast.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/modules/document_editor/controllers/document_editor_controller.dart';
import 'package:pdf_reader/modules/document_editor/views/document_editor_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/merge_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/organize_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/pdf_to_image_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/split_pdf_view.dart';

void showSelectionToolsSheet(
  BuildContext context,
  List<String> selectedPaths, {
  VoidCallback? onActionTaken,
}) {
  final pdfPaths = selectedPaths.where((path) => path.toLowerCase().endsWith('.pdf')).toList();

  if (pdfPaths.isEmpty) {
    AppToast.showWarning('select_at_least_one_pdf'.tr);
    return;
  }

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final cardBg = theme.cardColor;
  final primaryColor = theme.primaryColor;
  final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
  final textSecondary = theme.textTheme.bodyMedium?.color ?? Colors.grey;

  showModalBottomSheet(
    context: context,
    backgroundColor: cardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (modalContext) {
      final double systemBottom = MediaQuery.of(modalContext).padding.bottom;
      final double dynamicBottom = systemBottom > 20 ? systemBottom : 16.0;

      return Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: EdgeInsets.only(
          top: 14,
          left: 20,
          right: 20,
          bottom: dynamicBottom + 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (pdfPaths.length == 1) ...[
                _buildSingleFileTools(
                  context: modalContext,
                  filePath: pdfPaths.first,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onActionTaken: onActionTaken,
                ),
              ] else ...[
                _buildMultiFilesTools(
                  context: modalContext,
                  pdfPaths: pdfPaths,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onActionTaken: onActionTaken,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildSingleFileTools({
  required BuildContext context,
  required String filePath,
  required bool isDark,
  required Color primaryColor,
  required Color textPrimary,
  required Color textSecondary,
  VoidCallback? onActionTaken,
}) {
  final fileName = p.basename(filePath);
  final file = File(filePath);
  final fileSize = file.existsSync() ? FileUtils.formatSize(file.lengthSync()) : '';
  int pageCount = 0;
  try {
    final storage = Get.find<StorageService>();
    pageCount = storage.getPageCount(filePath);
  } catch (_) {}

  final tools = [
    _ToolOption(
      id: 'document_editor',
      title: 'tool_document_editor'.tr,
      description: 'desc_document_editor'.tr,
      icon: Icons.edit_note_rounded,
      color: const Color(0xFF0284C7),
      onTap: () {
        Navigator.pop(context);
        onActionTaken?.call();
        if (Get.isRegistered<DocumentEditorController>()) {
          Get.delete<DocumentEditorController>();
        }
        Get.to(() => DocumentEditorView(initialFilePath: filePath));
      },
    ),
    _ToolOption(
      id: 'organize',
      title: 'tool_organize_pdf'.tr,
      description: 'desc_organize_pdf'.tr,
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF6366F1),
      onTap: () {
        Navigator.pop(context);
        onActionTaken?.call();
        Get.to(() => OrganizePdfView(initialFilePath: filePath));
      },
    ),
    _ToolOption(
      id: 'split',
      title: 'tool_split_pdf'.tr,
      description: 'desc_split_pdf'.tr,
      icon: Icons.call_split_rounded,
      color: const Color(0xFFEC4899),
      onTap: () {
        Navigator.pop(context);
        onActionTaken?.call();
        Get.to(() => SplitPdfView(initialFilePath: filePath));
      },
    ),
    _ToolOption(
      id: 'pdf_to_img',
      title: 'tool_pdf_to_img'.tr,
      description: 'desc_pdf_to_img'.tr,
      icon: Icons.photo_library_rounded,
      color: const Color(0xFFF59E0B),
      onTap: () {
        Navigator.pop(context);
        onActionTaken?.call();
        Get.to(() => PdfToImageView(initialFilePath: filePath));
      },
    ),
    _ToolOption(
      id: 'merge',
      title: 'tool_merge_pdf'.tr,
      description: 'desc_merge_pdf'.tr,
      icon: Icons.merge_type_rounded,
      color: const Color(0xFF10B981),
      onTap: () {
        Navigator.pop(context);
        onActionTaken?.call();
        Get.to(() => MergePdfView(initialFilePath: filePath));
      },
    ),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSheetHeader(
        primaryColor: primaryColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        title: 'open_with_tools'.tr,
        subtitle: 'choose_tool_for_file'.tr,
      ),
      const SizedBox(height: 16),
      _buildInfoBadge(
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        icon: Icons.picture_as_pdf_rounded,
        iconColor: Colors.redAccent,
        title: fileName,
        subtitle: [
          if (fileSize.isNotEmpty) fileSize,
          if (pageCount > 0) '$pageCount ${'pages'.tr}',
        ].join(' • '),
      ),
      const SizedBox(height: 18),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _buildToolItemCard(
            tool: tools[index],
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          );
        },
      ),
    ],
  );
}

Widget _buildMultiFilesTools({
  required BuildContext context,
  required List<String> pdfPaths,
  required bool isDark,
  required Color primaryColor,
  required Color textPrimary,
  required Color textSecondary,
  VoidCallback? onActionTaken,
}) {
  int totalBytes = 0;
  for (final path in pdfPaths) {
    try {
      final f = File(path);
      if (f.existsSync()) totalBytes += f.lengthSync();
    } catch (_) {}
  }
  final totalSizeFormatted = FileUtils.formatSize(totalBytes);

  final mergeTool = _ToolOption(
    id: 'merge_multiple',
    title: 'tool_merge_pdf'.tr,
    description: 'desc_merge_pdf'.tr,
    icon: Icons.merge_type_rounded,
    color: const Color(0xFF10B981),
    onTap: () {
      Navigator.pop(context);
      onActionTaken?.call();
      Get.to(() => MergePdfView(initialFilePaths: pdfPaths));
    },
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSheetHeader(
        primaryColor: primaryColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        title: 'open_with_tools'.tr,
        subtitle: 'choose_tool_for_file'.tr,
      ),
      const SizedBox(height: 16),
      _buildInfoBadge(
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        icon: Icons.picture_as_pdf_rounded,
        iconColor: Colors.redAccent,
        title: '${pdfPaths.length} ${'files'.tr}',
        subtitle: totalSizeFormatted,
      ),
      const SizedBox(height: 18),
      _buildToolItemCard(
        tool: mergeTool,
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
    ],
  );
}

Widget _buildSheetHeader({
  required Color primaryColor,
  required Color textPrimary,
  required Color textSecondary,
  required String title,
  required String subtitle,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.handyman_rounded, color: primaryColor, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildInfoBadge({
  required bool isDark,
  required Color textPrimary,
  required Color textSecondary,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildToolItemCard({
  required _ToolOption tool,
  required bool isDark,
  required Color textPrimary,
  required Color textSecondary,
}) {
  return Material(
    color: isDark ? const Color(0xFF192233) : const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: tool.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF28364F) : const Color(0xFFEEF2F6),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool.icon, color: tool.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: textSecondary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ToolOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ToolOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

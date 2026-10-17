// lib/modules/home/widgets/selection_details_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/core/services/storage_service.dart';

void showSelectionDetailsSheet(BuildContext context, List<String> selectedPaths) {
  final theme = Theme.of(context);
  final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
  final textSecondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
  final cardBg = theme.cardColor;
  final primaryColor = theme.primaryColor;
  final isRtl = Get.locale?.languageCode == 'ar';

  int totalFiles = 0;
  int totalFolders = 0;
  int totalSize = 0;
  
  String singleName = '';
  String singlePath = '';
  String singleSize = '';
  String singleDate = '';
  String singleFormat = '';
  int singlePageCount = 0;

  if (selectedPaths.length == 1) {
    final path = selectedPaths.first;
    final file = File(path);
    final isDir = Directory(path).existsSync();
    
    singleName = p.basename(path);
    singlePath = path;
    singleFormat = isDir 
        ? (isRtl ? 'مجلد' : 'Folder') 
        : p.extension(path).replaceAll('.', '').toUpperCase();
    
    if (file.existsSync()) {
      totalSize = file.lengthSync();
      singleSize = FileUtils.formatSize(totalSize);
      try {
        final mod = file.lastModifiedSync();
        singleDate = '${mod.year}-${mod.month.toString().padLeft(2, '0')}-${mod.day.toString().padLeft(2, '0')} '
            '${mod.hour.toString().padLeft(2, '0')}:${mod.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        singleDate = '---';
      }
      
      if (singleFormat == 'PDF') {
        try {
          final storage = Get.find<StorageService>();
          singlePageCount = storage.getPageCount(path);
        } catch (_) {}
      }
    } else if (isDir) {
      singleSize = '---';
      try {
        final mod = Directory(path).statSync().modified;
        singleDate = '${mod.year}-${mod.month.toString().padLeft(2, '0')}-${mod.day.toString().padLeft(2, '0')} '
            '${mod.hour.toString().padLeft(2, '0')}:${mod.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        singleDate = '---';
      }
    }
  } else {
    for (final path in selectedPaths) {
      if (Directory(path).existsSync()) {
        totalFolders++;
      } else {
        totalFiles++;
        final file = File(path);
        try {
          if (file.existsSync()) {
            totalSize += file.lengthSync();
          }
        } catch (_) {}
      }
    }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: cardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final double systemBottom = MediaQuery.of(context).padding.bottom;
      final double dynamicBottom = systemBottom > 24 ? systemBottom : 12.0;

      return Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.only(
          top: 16,
          left: 24,
          right: 24,
          bottom: dynamicBottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'details'.tr,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (selectedPaths.length == 1) ...[
                // Single File Details
                _buildDetailRow('details_name'.tr, singleName, textPrimaryColor, textSecondaryColor),
                _buildDetailRow(isRtl ? 'الصيغة' : 'Format', singleFormat, textPrimaryColor, textSecondaryColor),
                _buildDetailRow('details_size'.tr, singleSize, textPrimaryColor, textSecondaryColor),
                _buildDetailRow('details_path'.tr, singlePath, textPrimaryColor, textSecondaryColor, isPath: true),
                _buildDetailRow('details_last_modified'.tr, singleDate, textPrimaryColor, textSecondaryColor),
                if (singlePageCount > 0)
                  _buildDetailRow('details_total_pages'.tr, '$singlePageCount', textPrimaryColor, textSecondaryColor),
              ] else ...[
                // Multiple Files Details
                _buildDetailRow(isRtl ? 'العناصر المحددة' : 'Selected Items', '${selectedPaths.length}', textPrimaryColor, textSecondaryColor),
                if (totalFiles > 0)
                  _buildDetailRow('files'.tr, '$totalFiles', textPrimaryColor, textSecondaryColor),
                if (totalFolders > 0)
                  _buildDetailRow('folders'.tr, '$totalFolders', textPrimaryColor, textSecondaryColor),
                _buildDetailRow(isRtl ? 'الحجم الإجمالي' : 'Total Size', FileUtils.formatSize(totalSize), textPrimaryColor, textSecondaryColor),
              ],
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'close'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildDetailRow(String label, String value, Color primaryColor, Color secondaryColor, {bool isPath = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: secondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            softWrap: true,
            maxLines: isPath ? 5 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

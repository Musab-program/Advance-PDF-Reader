import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';

class LegacyOfficeSheet {
  static void show({
    required BuildContext context,
    required LibraryItem item,
    required String ext,
    required VoidCallback onOpenExternal,
    required VoidCallback onExtractText,
  }) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Color formatColor = const Color(0xFF2B579A);
    String formatName = 'Word';
    if (ext == 'XLS') {
      formatColor = const Color(0xFF217346);
      formatName = 'Excel';
    } else if (ext == 'PPT') {
      formatColor = const Color(0xFFD24726);
      formatName = 'PowerPoint';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: formatColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '.$ext',
                          style: TextStyle(
                            color: formatColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'صيغة $formatName ثنائية قديمة (Office 97-2003)',
                            style: TextStyle(fontSize: 11.5, color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذا الملف محفوظ بصيغة ثنائية قديمة. للحفاظ على كامل الجداول والتنسيقات يُنصح بفتحه عبر تطبيق أوفيس مثبت، أو حفظه بصيغة حديثة (مثل DOCX أو XLSX).',
                          style: TextStyle(fontSize: 12, color: textPrimaryColor.withValues(alpha: 0.85), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onOpenExternal();
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('فتح عبر تطبيق أوفيس مثبت'),
                    style: FilledButton.styleFrom(
                      backgroundColor: formatColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onExtractText();
                    },
                    icon: const Icon(Icons.text_snippet_rounded, size: 18),
                    label: const Text('عرض النص المستخرج فقط'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Extracts readable UTF-8 / ASCII strings from binary OLE2 stream
  static String extractReadableText(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final sb = StringBuffer();
      final currentWord = <int>[];

      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        // Printable ASCII or Arabic / UTF-8
        if (b >= 32 && b <= 126 || b >= 160) {
          currentWord.add(b);
        } else if (b == 10 || b == 13) {
          // newline
          if (currentWord.isNotEmpty) {
            sb.write(utf8.decode(currentWord, allowMalformed: true));
            currentWord.clear();
          }
          sb.writeln();
        } else {
          if (currentWord.length >= 3) {
            sb.write(utf8.decode(currentWord, allowMalformed: true));
            sb.write(' ');
          }
          currentWord.clear();
        }
      }

      if (currentWord.isNotEmpty) {
        sb.write(utf8.decode(currentWord, allowMalformed: true));
      }

      final text = sb.toString().trim();
      return text.isNotEmpty ? text : 'لم يتم العثور على نصوص قابلة للاستخراج من هذا الملف الثنائي.';
    } catch (e) {
      return 'تعذر استخراج النص: $e';
    }
  }
}

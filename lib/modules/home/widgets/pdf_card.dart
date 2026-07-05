// lib/modules/home/widgets/pdf_card.dart
import 'package:flutter/material.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';

class PdfCard extends StatelessWidget {
  final PdfEntity pdf;
  final int index;
  final VoidCallback onTap;

  const PdfCard({
    super.key,
    required this.pdf,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pdf.progress > 0
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.cardBorder.withOpacity(0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──
            ClipRRect(
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(15),
                bottomStart: Radius.circular(15),
              ),
              child: Container(
                width: 80,
                height: 110,
                color: AppColors.surfaceLight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Index number as visual identifier
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppColors.primary.withOpacity(0.4),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white24,
                      size: 28,
                    ),
                    // Progress bar at bottom
                    if (pdf.progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: pdf.progress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withOpacity(0.8),
                          ),
                          minHeight: 3,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File name
                    Text(
                      pdf.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    // Tags row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(text: pdf.extension, color: AppColors.primary),
                        _Tag(text: FileUtils.formatSize(pdf.size), color: AppColors.textSecondary),
                        if (pdf.pageCount > 0)
                          _Tag(text: '${pdf.pageCount} pages', color: AppColors.textSecondary),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Status
                    Row(
                      children: [
                        Icon(
                          pdf.progress >= 1.0
                              ? Icons.check_circle_rounded
                              : pdf.progress > 0
                                  ? Icons.auto_stories_rounded
                                  : Icons.book_outlined,
                          size: 13,
                          color: pdf.progress > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          pdf.statusText,
                          style: TextStyle(
                            color: pdf.progress > 0
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Chevron ──
            const Padding(
              padding: EdgeInsets.only(right: 12, top: 44),
              child: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

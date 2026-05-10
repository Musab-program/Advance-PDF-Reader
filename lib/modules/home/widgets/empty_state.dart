// lib/modules/home/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:pdf_reader/core/constants/app_colors.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.library_books_outlined, size: 60, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.noFilesFound,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Select a folder to start your library',
            style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

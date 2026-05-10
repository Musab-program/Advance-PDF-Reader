// lib/core/widgets/app_error_widget.dart
import 'package:flutter/material.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';
import 'package:pdf_reader/core/constants/app_text_styles.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  const AppErrorWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.subtitle),
          const SizedBox(height: 8),
          Text(AppStrings.error, style: AppTextStyles.subtitle),
        ],
      ),
    );
  }
}

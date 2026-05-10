// lib/core/widgets/loading_widget.dart
import 'package:flutter/material.dart';
import 'package:pdf_reader/core/constants/app_strings.dart';
import 'package:pdf_reader/core/constants/app_text_styles.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppStrings.loading,
            style: AppTextStyles.subtitle,
          ),
        ],
      ),
    );
  }
}

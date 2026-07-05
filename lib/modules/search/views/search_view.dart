// lib/modules/search/views/search_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/modules/search/controllers/search_controller.dart' as sc;

class SearchView extends GetView<sc.SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;
    final homeController = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimaryColor, size: 24),
          onPressed: () => Get.back(),
        ),
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderCol.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: textSecondaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller.textController,
                  autofocus: true,
                  style: TextStyle(color: textPrimaryColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'search_hint'.tr,
                    hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Obx(() => controller.query.value.isNotEmpty
                  ? GestureDetector(
                      onTap: () => controller.textController.clear(),
                      child: Icon(Icons.close_rounded, color: textSecondaryColor, size: 18),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Three Sorting Chips ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: borderCol.withOpacity(0.4))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    context,
                    labelKey: 'sort_date'.tr,
                    activeValue: controller.selectedDateFilter,
                    icon: Icons.calendar_today_rounded,
                    onTap: () => _showDateFilterSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    context,
                    labelKey: 'sort_type'.tr,
                    activeValue: controller.selectedTypeFilter,
                    icon: Icons.category_rounded,
                    onTap: () => _showTypeFilterSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    context,
                    labelKey: 'sort_size'.tr,
                    activeValue: controller.selectedSizeFilter,
                    icon: Icons.data_usage_rounded,
                    onTap: () => _showSizeFilterSheet(context),
                  ),
                ),
              ],
            ),
          ),

          // ── Search Results List ──
          Expanded(
            child: Obx(() {
              final files = controller.results;
              if (files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.find_in_page_outlined, size: 72, color: textSecondaryColor.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'no_results'.tr,
                        style: TextStyle(color: textSecondaryColor, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final item = files[index];
                  final progress = homeController.getFileProgress(item.path);

                  return _SearchListCard(
                    item: item,
                    progress: progress > 0 ? progress : null,
                    onTap: () => homeController.openFile(item),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String labelKey,
    required RxString activeValue,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Obx(() {
      final isSelected = activeValue.value != 'all';
      final primaryColor = Theme.of(context).primaryColor;
      final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

      String displayLabel = labelKey;
      if (isSelected) {
        if (activeValue == controller.selectedDateFilter) {
          displayLabel = _getDateFilterLabel(activeValue.value);
        } else if (activeValue == controller.selectedTypeFilter) {
          displayLabel = _getTypeFilterLabel(activeValue.value);
        } else if (activeValue == controller.selectedSizeFilter) {
          displayLabel = _getSizeFilterLabel(activeValue.value);
        }
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.1) : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryColor : Theme.of(context).dividerColor.withOpacity(0.4),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? primaryColor : textPrimaryColor.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    color: isSelected ? primaryColor : textPrimaryColor,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    activeValue.value = 'all';
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: primaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  String _getDateFilterLabel(String value) {
    switch (value) {
      case '1_day':
        return '1_day_desc'.tr;
      case '2_days':
        return '2_days_desc'.tr;
      case '1_week':
        return '1_week_desc'.tr;
      case '2_weeks':
        return '2_weeks_desc'.tr;
      default:
        return 'sort_date'.tr;
    }
  }

  String _getTypeFilterLabel(String value) {
    if (value == 'all') return 'sort_type'.tr;
    return value.toUpperCase();
  }

  String _getSizeFilterLabel(String value) {
    switch (value) {
      case 'under_1mb':
        return 'under_1mb_desc'.tr;
      case '1to10mb':
        return '1to10mb_desc'.tr;
      case '10to50mb':
        return '10to50mb_desc'.tr;
      case 'over_50mb':
        return 'over_50mb_desc'.tr;
      default:
        return 'sort_size'.tr;
    }
  }

  void _showDateFilterSheet(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('sort_date'.tr, style: TextStyle(color: textPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...[
                  {'key': 'all', 'label': 'all_dates'.tr},
                  {'key': '1_day', 'label': '1_day_desc'.tr},
                  {'key': '2_days', 'label': '2_days_desc'.tr},
                  {'key': '1_week', 'label': '1_week_desc'.tr},
                  {'key': '2_weeks', 'label': '2_weeks_desc'.tr},
                ].map((opt) {
                  final isSelected = controller.selectedDateFilter.value == opt['key'];
                  return ListTile(
                    title: Text(opt['label']!, style: TextStyle(color: textPrimaryColor)),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor) : null,
                    onTap: () {
                      controller.setDateFilter(opt['key']!);
                      Get.back();
                    },
                  );
                }),
              ],
            )),
          ),
        ),
      ),
    );
  }

  void _showTypeFilterSheet(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('sort_type'.tr, style: TextStyle(color: textPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...[
                  {'key': 'all', 'label': 'all_formats'.tr},
                  {'key': 'pdf', 'label': 'PDF'},
                  {'key': 'word', 'label': 'Word'},
                  {'key': 'excel', 'label': 'Excel'},
                  {'key': 'ppt', 'label': 'PPT'},
                  {'key': 'txt', 'label': 'TXT'},
                  {'key': 'html', 'label': 'HTML'},
                ].map((opt) {
                  final isSelected = controller.selectedTypeFilter.value == opt['key'];
                  return ListTile(
                    title: Text(opt['label']!, style: TextStyle(color: textPrimaryColor)),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor) : null,
                    onTap: () {
                      controller.setTypeFilter(opt['key']!);
                      Get.back();
                    },
                  );
                }),
              ],
            )),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showSizeFilterSheet(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('sort_size'.tr, style: TextStyle(color: textPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...[
                  {'key': 'all', 'label': 'all_sizes'.tr},
                  {'key': 'under_1mb', 'label': 'under_1mb_desc'.tr},
                  {'key': '1to10mb', 'label': '1to10mb_desc'.tr},
                  {'key': '10to50mb', 'label': '10to50mb_desc'.tr},
                  {'key': 'over_50mb', 'label': 'over_50mb_desc'.tr},
                ].map((opt) {
                  final isSelected = controller.selectedSizeFilter.value == opt['key'];
                  return ListTile(
                    title: Text(opt['label']!, style: TextStyle(color: textPrimaryColor)),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor) : null,
                    onTap: () {
                      controller.setSizeFilter(opt['key']!);
                      Get.back();
                    },
                  );
                }),
              ],
            )),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
class _SearchListCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onTap;
  final double? progress;

  const _SearchListCard({
    required this.item,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(15),
                bottomStart: Radius.circular(15),
              ),
              child: Container(
                width: 64,
                height: 80,
                color: primaryColor.withOpacity(0.05),
                child: Center(
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: primaryColor,
                    size: 30,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(color: textPrimaryColor, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.extension,
                            style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.size > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            FileUtils.formatSize(item.size),
                            style: TextStyle(color: textSecondaryColor, fontSize: 10),
                          ),
                        ],
                        if (progress != null && progress! > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${(progress! * 100).toInt()}%',
                            style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

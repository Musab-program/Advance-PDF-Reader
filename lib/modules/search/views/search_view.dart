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
            border: Border.all(color: borderCol.withValues(alpha: 0.5)),
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
                    hintStyle: TextStyle(color: textSecondaryColor.withValues(alpha: 0.7), fontSize: 13),
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
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // ── Three Sorting Chips ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderCol.withValues(alpha: 0.4))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        context,
                        labelKey: 'sort_date'.tr,
                        activeValue: controller.selectedDateFilter,
                        icon: Icons.calendar_today_rounded,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _showDateFilterSheet(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        context,
                        labelKey: 'sort_type'.tr,
                        activeValue: controller.selectedTypeFilter,
                        icon: Icons.category_rounded,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _showTypeFilterSheet(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        context,
                        labelKey: 'sort_size'.tr,
                        activeValue: controller.selectedSizeFilter,
                        icon: Icons.data_usage_rounded,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _showSizeFilterSheet(context);
                        },
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
                          Icon(Icons.find_in_page_outlined, size: 72, color: textSecondaryColor.withValues(alpha: 0.3)),
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
        ),
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
      final screenWidth = MediaQuery.of(context).size.width;
      final double hPad = screenWidth < 360 ? 6.0 : 10.0;

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
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withValues(alpha: 0.1) : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryColor : Theme.of(context).dividerColor.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? primaryColor : textPrimaryColor.withValues(alpha: 0.6),
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
                    if (activeValue == controller.selectedDateFilter) {
                      controller.setDateFilter('all');
                    } else if (activeValue == controller.selectedSizeFilter) {
                      controller.setSizeFilter('all');
                    } else {
                      activeValue.value = 'all';
                    }
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
    if (value == 'custom' && controller.customDateRange.value != null) {
      final start = controller.customDateRange.value!.start;
      final end = controller.customDateRange.value!.end;
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return '${start.month}/${start.day}';
      }
      return '${start.month}/${start.day} - ${end.month}/${end.day}';
    }
    switch (value) {
      case '1_day':
        return '1_day_desc'.tr;
      case '2_days':
        return '2_days_desc'.tr;
      case '1_week':
        return '1_week_desc'.tr;
      case '2_weeks':
        return '2_weeks_desc'.tr;
      case 'custom':
        return 'custom'.tr;
      default:
        return 'sort_date'.tr;
    }
  }

  String _getTypeFilterLabel(String value) {
    if (value == 'all') return 'sort_type'.tr;
    return value.toUpperCase();
  }

  String _getSizeFilterLabel(String value) {
    if (value == 'custom') {
      final min = controller.customMinSizeMb.value;
      final max = controller.customMaxSizeMb.value;
      if (min != null && max != null) {
        final minStr = min.truncateToDouble() == min ? min.toInt().toString() : min.toStringAsFixed(1);
        final maxStr = max.truncateToDouble() == max ? max.toInt().toString() : max.toStringAsFixed(1);
        return '$minStr-$maxStr MB';
      } else if (min != null) {
        final minStr = min.truncateToDouble() == min ? min.toInt().toString() : min.toStringAsFixed(1);
        return '>$minStr MB';
      } else if (max != null) {
        final maxStr = max.truncateToDouble() == max ? max.toInt().toString() : max.toStringAsFixed(1);
        return '<$maxStr MB';
      }
      return 'custom'.tr;
    }
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
    FocusScope.of(context).unfocus();
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.bottomSheet(
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 550),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'sort_date'.tr,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    {'key': 'all', 'label': 'all_dates'.tr},
                    {'key': '1_day', 'label': '1_day_desc'.tr},
                    {'key': '2_days', 'label': '2_days_desc'.tr},
                    {'key': '1_week', 'label': '1_week_desc'.tr},
                    {'key': '2_weeks', 'label': '2_weeks_desc'.tr},
                    {'key': 'custom', 'label': 'custom'.tr},
                  ].map((opt) {
                    final isSelected = controller.selectedDateFilter.value == opt['key'];
                    return ListTile(
                      title: Text(
                        opt['label']!,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () async {
                        if (opt['key'] == 'custom') {
                          Get.back();
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: now.add(const Duration(days: 1)),
                            initialDateRange: controller.customDateRange.value ??
                                DateTimeRange(
                                  start: now.subtract(const Duration(days: 7)),
                                  end: now,
                                ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            controller.setCustomDate(picked);
                          }
                        } else {
                          controller.setDateFilter(opt['key']!);
                          Get.back();
                        }
                      },
                    );
                  }),
                ],
              )),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  void _showTypeFilterSheet(BuildContext context) {
    FocusScope.of(context).unfocus();
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.bottomSheet(
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 550),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'sort_type'.tr,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                      title: Text(
                        opt['label']!,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  void _showSizeFilterSheet(BuildContext context) {
    FocusScope.of(context).unfocus();
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.bottomSheet(
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 550),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'sort_size'.tr,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    {'key': 'all', 'label': 'all_sizes'.tr},
                    {'key': 'under_1mb', 'label': 'under_1mb_desc'.tr},
                    {'key': '1to10mb', 'label': '1to10mb_desc'.tr},
                    {'key': '10to50mb', 'label': '10to50mb_desc'.tr},
                    {'key': 'over_50mb', 'label': 'over_50mb_desc'.tr},
                    {'key': 'custom', 'label': 'custom'.tr},
                  ].map((opt) {
                    final isSelected = controller.selectedSizeFilter.value == opt['key'];
                    return ListTile(
                      title: Text(
                        opt['label']!,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        if (opt['key'] == 'custom') {
                          Get.back();
                          _showCustomSizeDialog(context);
                        } else {
                          controller.setSizeFilter(opt['key']!);
                          Get.back();
                        }
                      },
                    );
                  }),
                ],
              )),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  void _showCustomSizeDialog(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    final minController = TextEditingController(
      text: controller.customMinSizeMb.value != null
          ? (controller.customMinSizeMb.value!.truncateToDouble() == controller.customMinSizeMb.value
              ? controller.customMinSizeMb.value!.toInt().toString()
              : controller.customMinSizeMb.value!.toString())
          : '',
    );
    final maxController = TextEditingController(
      text: controller.customMaxSizeMb.value != null
          ? (controller.customMaxSizeMb.value!.truncateToDouble() == controller.customMaxSizeMb.value
              ? controller.customMaxSizeMb.value!.toInt().toString()
              : controller.customMaxSizeMb.value!.toString())
          : '',
    );

    Get.dialog(
      Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'custom_size'.tr,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'size_range_hint'.tr,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textPrimaryColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'min_size_mb'.tr,
                        hintText: '0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textPrimaryColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'max_size_mb'.tr,
                        hintText: '50',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('cancel'.tr, style: TextStyle(color: textSecondaryColor)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final min = double.tryParse(minController.text.trim());
                      final max = double.tryParse(maxController.text.trim());
                      if (min != null || max != null) {
                        controller.setCustomSize(min, max);
                      }
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text('apply'.tr),
                  ),
                ],
              ),
            ],
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
          border: Border.all(color: borderCol.withValues(alpha: 0.5), width: 1),
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
                color: primaryColor.withValues(alpha: 0.05),
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
                            color: primaryColor.withValues(alpha: 0.1),
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

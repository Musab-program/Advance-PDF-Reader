// lib/modules/search/views/search_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_reader/core/utils/app_toast.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/modules/search/controllers/search_controller.dart' as sc;
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

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
                  focusNode: controller.searchFocusNode,
                  autofocus: false,
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
                          controller.searchFocusNode.unfocus();
                          controller.searchFocusNode.canRequestFocus = false;
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
                          controller.searchFocusNode.unfocus();
                          controller.searchFocusNode.canRequestFocus = false;
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
                          controller.searchFocusNode.unfocus();
                          controller.searchFocusNode.canRequestFocus = false;
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
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Get.back(),
        child: GestureDetector(
          onTap: () {},
          child: Align(
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
                              controller.searchFocusNode.unfocus();
                              controller.searchFocusNode.canRequestFocus = false;
                              Get.back();
                              await Future.delayed(const Duration(milliseconds: 100));
                              if (context.mounted) {
                                await _showCustomDateDialog(context);
                                controller.searchFocusNode.canRequestFocus = true;
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
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: true,
      enableDrag: true,
    ).then((_) {
      controller.searchFocusNode.canRequestFocus = true;
    });
  }

  void _showTypeFilterSheet(BuildContext context) {
    FocusScope.of(context).unfocus();
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.bottomSheet(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Get.back(),
        child: GestureDetector(
          onTap: () {},
          child: Align(
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
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: true,
      enableDrag: true,
    ).then((_) {
      controller.searchFocusNode.canRequestFocus = true;
    });
  }

  void _showSizeFilterSheet(BuildContext context) {
    FocusScope.of(context).unfocus();
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Get.bottomSheet(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Get.back(),
        child: GestureDetector(
          onTap: () {},
          child: Align(
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
                          onTap: () async {
                            if (opt['key'] == 'custom') {
                              controller.searchFocusNode.unfocus();
                              controller.searchFocusNode.canRequestFocus = false;
                              Get.back();
                              await Future.delayed(const Duration(milliseconds: 100));
                              if (context.mounted) {
                                await _showCustomSizeDialog(context);
                                controller.searchFocusNode.canRequestFocus = true;
                              }
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
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: true,
      enableDrag: true,
    ).then((_) {
      controller.searchFocusNode.canRequestFocus = true;
    });
  }

  Future<void> _showCustomDateDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final now = DateTime.now();
    final initialStart = controller.customDateRange.value?.start ?? now.subtract(const Duration(days: 7));
    final initialEnd = controller.customDateRange.value?.end ?? now;

    String formatDate(DateTime d) =>
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    final startController = TextEditingController(text: formatDate(initialStart));
    final endController = TextEditingController(text: formatDate(initialEnd));

    return LuxuryDialog.showCustom(
      context,
      builder: (dCtx) => LuxuryDialog(
        compact: true,
        icon: Icons.calendar_month_rounded,
        title: 'تحديد تاريخ مخصص',
        message: 'أدخل التاريخ بالأرقام أو اضغط على أيقونة التقويم للاختيار المباشر.',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: startController,
              autofocus: false,
              keyboardType: TextInputType.number,
              inputFormatters: [_DateAutoSlashFormatter()],
              style: TextStyle(color: textPrimaryColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'من تاريخ (سنة/شهر/يوم)',
                hintText: '2026/01/01',
                hintStyle: TextStyle(color: textSecondaryColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range_rounded, size: 20),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dCtx,
                      initialDate: initialStart,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      startController.text = formatDate(picked);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: endController,
              autofocus: false,
              keyboardType: TextInputType.number,
              inputFormatters: [_DateAutoSlashFormatter()],
              style: TextStyle(color: textPrimaryColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'إلى تاريخ (سنة/شهر/يوم)',
                hintText: '2026/12/31',
                hintStyle: TextStyle(color: textSecondaryColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range_rounded, size: 20),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dCtx,
                      initialDate: initialEnd,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      endController.text = formatDate(picked);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        secondaryButtonText: 'cancel'.tr,
        primaryButtonText: 'apply'.tr,
        primaryButtonIcon: Icons.check_rounded,
        closeOnPrimary: false,
        onPrimaryPressed: () {
          final startDate = _parseDateString(startController.text.trim());
          final endDate = _parseDateString(endController.text.trim());
          if (startDate == null || endDate == null) {
            AppToast.showWarning('يرجى إدخال تاريخ صحيح بصيغة سنة/شهر/يوم');
            return;
          }
          if (startDate.isAfter(endDate)) {
            AppToast.showWarning('تاريخ البداية يجب أن يكون قبل أو يساوي تاريخ النهاية');
            return;
          }
          controller.setCustomDate(DateTimeRange(
            start: startDate,
            end: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
          ));
          Navigator.of(dCtx).pop();
        },
      ),
    );
  }

  Future<void> _showCustomSizeDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

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

    return LuxuryDialog.showCustom(
      context,
      builder: (dCtx) => LuxuryDialog(
        compact: true,
        icon: Icons.tune_rounded,
        title: 'custom_size'.tr,
        message: 'size_range_hint'.tr,
        body: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                autofocus: false,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textPrimaryColor, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'min_size_mb'.tr,
                  hintText: '0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: maxController,
                autofocus: false,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textPrimaryColor, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'max_size_mb'.tr,
                  hintText: '50',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        secondaryButtonText: 'cancel'.tr,
        primaryButtonText: 'apply'.tr,
        primaryButtonIcon: Icons.check_rounded,
        onPrimaryPressed: () {
          final min = double.tryParse(minController.text.trim());
          final max = double.tryParse(maxController.text.trim());
          if (min != null || max != null) {
            controller.setCustomSize(min, max);
          }
        },
      ),
    );
  }

  static DateTime? _parseDateString(String input) {
    if (input.isEmpty) return null;
    final clean = input.replaceAll('-', '/').replaceAll('.', '/');
    final parts = clean.split('/');
    if (parts.length != 3) return null;

    int? year;
    int? month;
    int? day;

    if (parts[0].length == 4) {
      year = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      day = int.tryParse(parts[2]);
    } else if (parts[2].length == 4) {
      day = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      year = int.tryParse(parts[2]);
    } else {
      year = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      day = int.tryParse(parts[2]);
    }

    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}

class _DateAutoSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 8) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 4 || i == 6) {
        buffer.write('/');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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

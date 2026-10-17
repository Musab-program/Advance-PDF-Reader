// lib/modules/folder/views/folder_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/pdf_entity.dart';
import 'package:pdf_reader/modules/folder/controllers/folder_controller.dart';
import 'package:pdf_reader/modules/home/widgets/selection_details_sheet.dart';

class FolderView extends GetView<FolderController> {
  const FolderView({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Obx(() => PopScope(
      canPop: !controller.isSelectionMode.value,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.isSelectionMode.value) {
          controller.clearSelection();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        floatingActionButton: Obx(() {
          final lastFile = controller.lastReadFile.value;
          if (lastFile == null || controller.isSelectionMode.value) return const SizedBox.shrink();
          
          return FloatingActionButton.extended(
            onPressed: controller.resumeReading,
            backgroundColor: primaryColor,
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: Text(
              'continue_reading'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
        bottomNavigationBar: Obx(() {
          if (controller.isSelectionMode.value) {
            return _buildBottomSelectionPanel(context);
          } else {
            return const SizedBox.shrink();
          }
        }),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  // ── App Bar ──
                  Obx(() {
                    if (controller.isSelectionMode.value) {
                      return _buildSelectionBar(context);
                    } else {
                      return _buildAppBar(context);
                    }
                  }),

                  // ── Search Bar ──
                  _buildSearchBar(context),

                  Expanded(
                    child: Obx(() {
                      if (controller.isLoading.value) {
                        return Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: controller.refresh,
                        color: primaryColor,
                        child: controller.filteredPdfFiles.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off_rounded,
                                          size: 56,
                                          color: textSecondaryColor.withOpacity(0.4),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'no_results'.tr,
                                          style: TextStyle(
                                            color: textSecondaryColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                key: const PageStorageKey('folder_pdf_list_view'),
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                                children: [
                                  // ── File count ──
                                  Text(
                                    '${controller.filteredPdfFiles.length} ${"pdf_files".tr.toUpperCase()}',
                                    style: TextStyle(
                                      color: textSecondaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // ── PDF List ──
                                  ...List.generate(controller.filteredPdfFiles.length, (index) {
                                    final pdf = controller.filteredPdfFiles[index];
                                    final isLastRead = controller.lastReadFile.value?.path == pdf.path;
                                    final rxSelected = controller.getRxSelected(pdf.path);
                                    return Obx(() {
                                      final isSelected = rxSelected.value;
                                      final isSelectionMode = controller.isSelectionMode.value;
                                      return _FolderPdfCard(
                                        pdf: pdf,
                                        index: index,
                                        isLastRead: isLastRead,
                                        isSelected: isSelected,
                                        isSelectionMode: isSelectionMode,
                                        onTap: () {
                                          if (isSelectionMode) {
                                            controller.toggleSelection(pdf.path);
                                          } else {
                                            controller.openPdf(pdf);
                                          }
                                        },
                                        onLongPress: () {
                                          controller.toggleSelection(pdf.path);
                                        },
                                      );
                                    });
                                  }),
                                ],
                              ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildSearchBar(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: TextField(
          controller: controller.searchTextController,
          style: TextStyle(color: textPrimaryColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'search_hint'.tr,
            hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.6), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
            suffixIcon: Obx(() {
              if (controller.searchQuery.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondaryColor, size: 18),
                onPressed: () {
                  controller.searchTextController.clear();
                },
              );
            }),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: textPrimaryColor, size: 20),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(
                      controller.folderName.value,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                const SizedBox(height: 2),
                Text('folders'.tr,
                    style: TextStyle(
                        color: textSecondaryColor, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.sort_rounded, color: textPrimaryColor),
            onPressed: () => _showSortOptions(context),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final double systemBottom = MediaQuery.of(context).padding.bottom;
        final double dynamicBottom = systemBottom > 24 ? systemBottom : 12.0;
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: dynamicBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'sort_by'.tr,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(() => IconButton(
                    icon: Icon(
                      controller.isAscending.value 
                        ? Icons.arrow_upward_rounded 
                        : Icons.arrow_downward_rounded,
                      color: primaryColor,
                    ),
                    onPressed: controller.toggleSortDirection,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              _buildSortItem(context, 'name', Icons.sort_by_alpha_rounded, 'name'.tr),
              _buildSortItem(context, 'date', Icons.calendar_today_rounded, 'date_modified'.tr),
              _buildSortItem(context, 'size', Icons.data_usage_rounded, 'size'.tr),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortItem(BuildContext context, String value, IconData icon, String label) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final primaryColor = Theme.of(context).primaryColor;

    return Obx(() {
      final isSelected = controller.sortOrder.value == value;
      return ListTile(
        leading: Icon(icon, color: isSelected ? primaryColor : textSecondaryColor),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? textPrimaryColor : textSecondaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check_circle, color: primaryColor) : null,
        onTap: () {
          controller.setSortOrder(value);
          Get.back();
        },
      );
    });
  }

  Widget _buildSelectionBar(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: primaryColor.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: primaryColor),
                onPressed: controller.clearSelection,
              ),
              const SizedBox(width: 8),
              Obx(() => Text(
                    '${controller.selectedPaths.length} ${"selected".tr}',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
            ],
          ),
          Obx(() {
            bool allSelected = controller.filteredPdfFiles.isNotEmpty;
            for (final pdf in controller.filteredPdfFiles) {
              if (!controller.selectedPaths.contains(pdf.path)) {
                allSelected = false;
                break;
              }
            }

            return IconButton(
              icon: Icon(
                allSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                color: allSelected ? primaryColor : textPrimaryColor.withOpacity(0.4),
                size: 24,
              ),
              onPressed: controller.selectAll,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomSelectionPanel(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderCol = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF22304D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Row(
                children: [
                  // Share
                  Expanded(
                    child: InkWell(
                      onTap: controller.shareSelected,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_rounded, color: primaryColor, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            'share'.tr,
                            style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  VerticalDivider(color: borderCol.withOpacity(0.6), width: 1, indent: 10, endIndent: 10),
                  
                  // Details
                  Expanded(
                    child: InkWell(
                      onTap: () => showSelectionDetailsSheet(context, controller.selectedPaths.toList()),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            'details'.tr,
                            style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  VerticalDivider(color: borderCol.withOpacity(0.6), width: 1, indent: 10, endIndent: 10),
                  
                  // Delete
                  Expanded(
                    child: InkWell(
                      onTap: () => _confirmBulkDelete(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            'remove_title'.tr,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'remove_title'.tr,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'remove_desc'.tr,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.3),
                        ),
                      ),
                      onPressed: () => Get.back(),
                      child: Text(
                        'cancel'.tr,
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        controller.deleteSelected();
                        Get.back();
                      },
                      child: Text(
                        'remove_title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
class _FolderPdfCard extends StatelessWidget {
  final PdfEntity pdf;
  final int index;
  final bool isLastRead;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderPdfCard({
    required this.pdf,
    required this.index,
    required this.isLastRead,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
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
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.06)
              : (isLastRead ? primaryColor.withOpacity(0.04) : cardBg),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isLastRead
                    ? primaryColor.withOpacity(0.65)
                    : (pdf.progress > 0
                        ? primaryColor.withOpacity(0.25)
                        : borderCol.withOpacity(0.4))),
            width: (isLastRead || isSelected) ? 1.5 : 1.0,
          ),
          boxShadow: (isLastRead || isSelected)
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Number
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withOpacity(0.2)
                    : (pdf.progress >= 1.0
                        ? primaryColor.withOpacity(0.15)
                        : borderCol.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: pdf.progress >= 1.0
                    ? Icon(Icons.check_rounded,
                        color: primaryColor, size: 18)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: (isLastRead || pdf.progress > 0 || isSelected)
                              ? primaryColor
                              : textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pdf.name,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 14,
                            fontWeight: isLastRead ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLastRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_rounded, color: primaryColor, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                'last_read'.tr,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (pdf.progress == 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'unread'.tr,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (pdf.progress >= 1.0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                'completed'.tr,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(FileUtils.formatSize(pdf.size),
                          style: TextStyle(
                              color: textSecondaryColor, fontSize: 11)),
                      if (pdf.pageCount > 0) ...[
                        const SizedBox(width: 6),
                        Text('• ${pdf.pageCount} ${"pages".tr}',
                            style: TextStyle(
                                color: textSecondaryColor, fontSize: 11)),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        pdf.progress == 0
                            ? '• ${"unread".tr}'
                            : (pdf.progress >= 1.0
                                ? '• ${"completed".tr}'
                                : '• ${"reading".tr} • ${(pdf.progress * 100).toInt()}%'),
                        style: TextStyle(
                          color: pdf.progress > 0
                              ? primaryColor
                              : textSecondaryColor,
                          fontSize: 11,
                          fontWeight: pdf.progress > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (pdf.progress > 0 && pdf.progress < 1.0) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pdf.progress,
                      backgroundColor: borderCol,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            if (isSelectionMode) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? primaryColor : textSecondaryColor.withOpacity(0.3),
                  size: 22,
                ),
              ),
            ] else ...[
              // Favorite button
              GetBuilder<FolderController>(
                builder: (ctrl) {
                  final isFav = ctrl.isFavorite(pdf.path);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav ? Colors.amber : textSecondaryColor.withOpacity(0.4),
                      size: 22,
                    ),
                    onPressed: () => ctrl.toggleFavorite(pdf),
                  );
                },
              ),
              Icon(Icons.chevron_right, color: textSecondaryColor, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

/*
* نضيف زر اكس للخروح من الدايلوق في المظهر واللغة والخط وحجم الخط
* نغير اصدار هذا التطبيق للاصدار الثاني
* الفرز في صفحة الاخيرة مش ما يشتغل
* عند فتح دايلوق طريقة العرض
*
* */
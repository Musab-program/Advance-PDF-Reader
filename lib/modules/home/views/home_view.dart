// lib/modules/home/views/home_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/modules/home/widgets/main_drawer.dart';
import 'package:pdf_reader/modules/home/widgets/selection_details_sheet.dart';
import 'package:pdf_reader/routes/app_routes.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    // Force synchronization of PageView scroll position with the current tab state on every layout rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.pageController.hasClients) {
        final currentPage = controller.pageController.page?.round();
        if (currentPage != controller.currentTab.value) {
          controller.pageController.jumpToPage(controller.currentTab.value);
        }
      }
    });

    return Obx(() => PopScope(
      canPop: !controller.isSelectionMode.value,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.isSelectionMode.value) {
          controller.clearSelection();
        }
      },
      child: Scaffold(
        key: scaffoldKey,
        drawer: const MainDrawer(),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
              Obx(() {
                if (controller.isSelectionMode.value) {
                  return _buildSelectionBar(context);
                } else {
                  return _buildUnifiedSearchBar(context, scaffoldKey);
                }
              }),
              Expanded(
                child: PageView(
                  key: const PageStorageKey('home_page_view'),
                  controller: controller.pageController,
                  onPageChanged: (index) {
                    controller.currentTab.value = index;
                    if (index == 0) {
                      controller.loadRecentItems();
                    }
                  },
                  children: [
                    _buildRecentsTab(context),
                    _buildFilesTab(context),
                    _buildFoldersTab(context),
                    _buildFavoritesTab(context),
                    _buildToolsTab(context),
                  ],
                ),
              ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Obx(() {
          if (controller.isSelectionMode.value) {
            return _buildBottomSelectionPanel(context);
          } else {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardBg = Theme.of(context).cardColor;
            
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
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        canvasColor: Colors.transparent,
                      ),
                      child: BottomNavigationBar(
                        currentIndex: controller.currentTab.value,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        selectedItemColor: Theme.of(context).primaryColor,
                        unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        unselectedLabelStyle: const TextStyle(fontSize: 11),
                        onTap: (index) {
                          controller.currentTab.value = index;
                          controller.pageController.jumpToPage(index);
                          if (index == 0) {
                            controller.loadRecentItems();
                          }
                        },
                        type: BottomNavigationBarType.fixed,
                        items: [
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.history_rounded),
                            label: 'recents'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: 'files'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.folder_rounded),
                            label: 'folders'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.star_rounded),
                            label: 'favorites'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.handyman_rounded),
                            label: 'tools'.tr,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }),
        floatingActionButton: Obx(() {
          final tab = controller.currentTab.value;
          final isSelection = controller.isSelectionMode.value;
          if (isSelection) return const SizedBox.shrink();
          
          if (tab == 1) {
            return FloatingActionButton(
              heroTag: 'add_file_fab',
              onPressed: controller.pickPdfFile,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add_to_photos_rounded, color: Colors.white),
            );
          } else if (tab == 2) {
            return FloatingActionButton(
              heroTag: 'add_folder_fab',
              onPressed: controller.pickFolder,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
            );
          }
          return const SizedBox.shrink();
        }),
      ),
    ));
  }

  Widget _buildFilesTab(BuildContext context) {
    return Obx(() {
      final files = controller.filteredDeviceFiles;
      final isScanning = controller.isScanningDevice.value;

      return Column(
        children: [
          _buildCategoryFiltersGrid(context),
          if (isScanning && files.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.scanDeviceDocuments,
                child: files.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          _buildEmptyState(
                            context,
                            Icons.picture_as_pdf_outlined,
                            'empty_library'.tr,
                            'empty_files_desc'.tr,
                          ),
                        ],
                      )
                    : _buildItemsList(context, files),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildFoldersTab(BuildContext context) {
    return Obx(() {
      final folders = controller.filteredItems.where((item) => item.isFolder).toList();
      if (folders.isEmpty) {
        return _buildEmptyState(
          context,
          Icons.folder_open_outlined,
          'empty_library'.tr,
          'empty_folders_desc'.tr,
        );
      }
      return _buildItemsList(context, folders);
    });
  }

  Widget _buildToolsTab(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderCol = Theme.of(context).dividerColor;

    final List<Map<String, dynamic>> toolsList = [
      {
        'title': 'Merge PDFs',
        'desc': 'Combine multiple PDF files into one',
        'icon': Icons.merge_type_rounded,
      },
      {
        'title': 'Split PDF',
        'desc': 'Extract specific pages into a new file',
        'icon': Icons.call_split_rounded,
      },
      {
        'title': 'Image to PDF',
        'desc': 'Convert images to high quality PDF',
        'icon': Icons.image_rounded,
      },
      {
        'title': 'PDF to Image',
        'desc': 'Extract pages from PDF to images',
        'icon': Icons.picture_in_picture_rounded,
      },
      {
        'title': 'Extract Text',
        'desc': 'Extract text characters from documents',
        'icon': Icons.text_fields_rounded,
      },
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'tools'.tr,
            style: TextStyle(color: textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: toolsList.length,
          itemBuilder: (context, index) {
            final tool = toolsList[index];
            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tool['icon'], color: primaryColor, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    tool['title'],
                    style: TextStyle(color: textPrimaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool['desc'],
                    style: TextStyle(color: textSecondaryColor, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildFavoritesTab(BuildContext context) {
    return Obx(() {
      final List<LibraryItem> favorites = [];
      favorites.addAll(controller.filteredItems.where((item) => item.isFavorite));
      final globalFavorites = controller.getGlobalFavorites();
      for (final item in globalFavorites) {
        if (!favorites.any((e) => e.path == item.path)) {
          favorites.add(item);
        }
      }

      if (favorites.isEmpty) {
        return _buildEmptyState(
          context,
          Icons.star_outline_rounded,
          'favorites'.tr,
          'empty_favorites_desc'.tr,
        );
      }
      return _buildItemsList(context, favorites);
    });
  }

  Widget _buildRecentsTab(BuildContext context) {
    return Obx(() {
      final recents = controller.recentItems;
      if (recents.isEmpty) {
        return _buildEmptyState(
          context,
          Icons.history_rounded,
          'recents'.tr,
          'empty_recents_desc'.tr,
        );
      }
      return _buildItemsList(context, recents);
    });
  }

  Widget _buildCategoryFiltersGrid(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    final List<Map<String, dynamic>> categories = [
      {'key': 'ALL', 'label': 'all'.tr, 'icon': Icons.grid_view_rounded, 'color': primaryColor},
      {'key': 'PDF', 'label': 'PDF', 'icon': Icons.picture_as_pdf_rounded, 'color': const Color(0xFFE74C3C)}, // PDF Red
      {'key': 'WORD', 'label': 'Word', 'icon': Icons.description_rounded, 'color': const Color(0xFF2B579A)}, // Word Blue
      {'key': 'EXCEL', 'label': 'Excel', 'icon': Icons.table_view_rounded, 'color': const Color(0xFF217346)}, // Excel Green (Changed to table_view)
      {'key': 'PPT', 'label': 'PPT', 'icon': Icons.slideshow_rounded, 'color': const Color(0xFFD24726)}, // PowerPoint Orange
      {'key': 'TXT', 'label': 'Text', 'icon': Icons.text_snippet_rounded, 'color': Colors.grey}, // Text Grey
      {'key': 'HTML', 'label': 'HTML', 'icon': Icons.html_rounded, 'color': const Color(0xFFE34F26)}, // HTML OrangeAccent
      {'key': 'OTHERS', 'label': 'others'.tr, 'icon': Icons.article_rounded, 'color': Colors.deepPurpleAccent}, // Others Purple
    ];

    final width = MediaQuery.of(context).size.width.clamp(0.0, 1000.0);
    final int cols = width > 800 ? 8 : (width > 450 ? 6 : 4);
    final itemWidth = (width - 32 - (8 * (cols - 1))) / cols;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          return Obx(() {
            final isSelected = controller.selectedFormatFilter.value == cat['key'];
            final Color activeColor = cat['color'] as Color;
            final cardBg = Theme.of(context).cardColor;
            final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

            return GestureDetector(
              onTap: () => controller.setFormatFilter(cat['key']),
              child: Container(
                width: itemWidth,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.12) : cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? activeColor : Theme.of(context).dividerColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'],
                      color: isSelected ? activeColor : activeColor.withValues(alpha: 0.65), // Always colored with signature palette!
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat['label'],
                      style: TextStyle(
                        color: isSelected ? activeColor : textPrimaryColor,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, List<LibraryItem> items) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);

    return Obx(() {
      if (controller.isGridView.value) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _LibraryGridCard(
              item: item,
              onTap: () {
                if (item.isFolder) {
                  controller.openFolder(item);
                } else {
                  controller.openFile(item);
                }
              },
              onFavoriteToggle: () => controller.toggleFavorite(item),
              onDelete: () => _confirmDelete(context, item),
              progress: item.isFile ? controller.getFileProgress(item.path) : null,
            );
          },
        );
      } else {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _LibraryListCard(
              item: item,
              onTap: () {
                if (item.isFolder) {
                  controller.openFolder(item);
                } else {
                  controller.openFile(item);
                }
              },
              onFavoriteToggle: () => controller.toggleFavorite(item),
              onDelete: () => _confirmDelete(context, item),
              progress: item.isFile
                  ? controller.getFileProgress(item.path)
                  : null,
            );
          },
        );
      }
    });
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: textSecondaryColor.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondaryColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedSearchBar(BuildContext context, GlobalKey<ScaffoldState> key) {
    final cardBg = Theme.of(context).cardColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final borderCol = Theme.of(context).dividerColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderCol.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: textSecondaryColor),
            onPressed: () => key.currentState?.openDrawer(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Get.toNamed(Routes.SEARCH),
              child: AbsorbPointer(
                child: TextField(
                  controller: controller.searchController,
                  readOnly: true,
                  style: TextStyle(color: textPrimaryColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'search_hint'.tr,
                    hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: textSecondaryColor),
            onPressed: () => _showSortOptions(context),
          ),
        ],
      ),
    );
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
            final activeItems = controller.getActiveTabItems();
            bool allSelected = activeItems.isNotEmpty;
            for (final item in activeItems) {
              if (!controller.selectedPaths.contains(item.path)) {
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

  void _confirmDelete(BuildContext context, LibraryItem item) {
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
                  Icons.delete_forever_rounded,
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
                        controller.removeItem(item);
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

  void _showSortOptions(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final double systemBottom = MediaQuery.of(context).padding.bottom;
        final double dynamicBottom = systemBottom > 24 ? systemBottom : 12.0;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: dynamicBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: textSecondaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // ── Layout Mode Switches ──
                Text(
                  'view_mode'.tr,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Obx(() {
                        final isSelected = !controller.isGridView.value;
                        return InkWell(
                          onTap: () => controller.toggleLayoutMode(false),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.view_list_rounded,
                                  size: 18,
                                  color: isSelected ? Colors.white : textPrimaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'view_list'.tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : textPrimaryColor,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Obx(() {
                        final isSelected = controller.isGridView.value;
                        return InkWell(
                          onTap: () => controller.toggleLayoutMode(true),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  size: 18,
                                  color: isSelected ? Colors.white : textPrimaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'view_grid'.tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : textPrimaryColor,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.6), height: 1),
                const SizedBox(height: 20),

                // ── Sorting ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'sort_by'.tr,
                      style: TextStyle(color: textPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Obx(() => IconButton(
                      icon: Icon(
                        controller.isAscending.value 
                          ? Icons.arrow_upward_rounded 
                          : Icons.arrow_downward_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: controller.toggleSortDirection,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                
                Obx(() => _SortOption(
                  title: 'name'.tr,
                  icon: Icons.sort_by_alpha_rounded,
                  isSelected: controller.sortOrder.value == 'name',
                  onTap: () { controller.setSortOrder('name'); Get.back(); },
                )),
                Obx(() => _SortOption(
                  title: 'date_modified'.tr,
                  icon: Icons.calendar_today_rounded,
                  isSelected: controller.sortOrder.value == 'date',
                  onTap: () { controller.setSortOrder('date'); Get.back(); },
                )),
                Obx(() => _SortOption(
                  title: 'size'.tr,
                  icon: Icons.data_usage_rounded,
                  isSelected: controller.sortOrder.value == 'size',
                  onTap: () { controller.setSortOrder('size'); Get.back(); },
                )),
                Obx(() => _SortOption(
                  title: 'type'.tr,
                  icon: Icons.category_rounded,
                  isSelected: controller.sortOrder.value == 'type',
                  onTap: () { controller.setSortOrder('type'); Get.back(); },
                )),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
class _FileIconInfo {
  final IconData icon;
  final Color color;
  _FileIconInfo(this.icon, this.color);
}

_FileIconInfo _getFileIconInfo(String ext, Color defaultColor) {
  final cleanExt = ext.replaceAll('.', '').toUpperCase();
  switch (cleanExt) {
    case 'PDF':
      return _FileIconInfo(Icons.picture_as_pdf_rounded, const Color(0xFFE74C3C)); // PDF Red
    case 'DOC':
    case 'DOCX':
    case 'WPS':
    case 'WPT':
      return _FileIconInfo(Icons.description_rounded, const Color(0xFF2B579A)); // Word/WPS Blue
    case 'XLS':
    case 'XLSX':
    case 'ET':
    case 'ETT':
      return _FileIconInfo(Icons.table_view_rounded, const Color(0xFF217346)); // Excel/WPS Green
    case 'PPT':
    case 'PPTX':
    case 'DPS':
    case 'DPT':
      return _FileIconInfo(Icons.slideshow_rounded, const Color(0xFFD24726)); // PowerPoint/WPS Orange
    case 'TXT':
      return _FileIconInfo(Icons.text_snippet_rounded, Colors.grey); // Text Grey
    case 'HTML':
      return _FileIconInfo(Icons.html_rounded, const Color(0xFFE34F26)); // HTML OrangeAccent
    default:
      // EPUB, CSV, RTF, XML, ODT, etc.
      return _FileIconInfo(Icons.article_rounded, Colors.deepPurpleAccent); // Purple for Others
  }
}

// ────────────────────────────────────────────────────────────────────────
class _LibraryListCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;
  final double? progress;

  const _LibraryListCard({
    required this.item,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;

    final iconInfo = item.isFolder 
        ? _FileIconInfo(Icons.folder_rounded, primaryColor)
        : _getFileIconInfo(item.extension, primaryColor);

    final rxSelected = controller.getRxSelected(item.path);

    return Obx(() {
      final isSelected = rxSelected.value;
      final isSelectionMode = controller.isSelectionMode.value;

      return GestureDetector(
        onTap: () {
          if (isSelectionMode) {
            controller.toggleSelection(item.path);
          } else {
            onTap();
          }
        },
        onLongPress: () {
          controller.toggleSelection(item.path);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderCol.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon area
              ClipRRect(
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(15),
                  bottomStart: Radius.circular(15),
                ),
                child: Container(
                  width: 72,
                  height: 90,
                  color: isSelected
                      ? primaryColor.withOpacity(0.12)
                      : iconInfo.color.withOpacity(0.08),
                  child: Center(
                    child: isSelected
                        ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 28)
                        : Icon(
                            iconInfo.icon,
                            color: iconInfo.color,
                            size: 36,
                          ),
                  ),
                ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.name,
                                style: TextStyle(
                                    color: textPrimaryColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!item.isFolder) ...[
                            if (progress == null || progress == 0) ...[
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
                            ] else if (progress != null && progress! >= 1.0) ...[
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
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.isFolder ? 'FOLDER'.tr : item.extension,
                              style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (item.isFile && item.size > 0) ...[
                            const SizedBox(width: 8),
                            Text(FileUtils.formatSize(item.size),
                                style: TextStyle(
                                    color: textSecondaryColor,
                                    fontSize: 11)),
                          ],
                          if (progress != null && progress! > 0) ...[
                            const SizedBox(width: 8),
                            Text('${(progress! * 100).toInt()}%',
                                style: TextStyle(
                                    color: primaryColor, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      if (progress != null && progress! > 0) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: borderCol,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Selection checkmark or Actions
              if (!isSelectionMode) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FavoriteStar(
                    isFavorite: item.isFavorite,
                    onTap: onFavoriteToggle,
                    size: 24,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 20),
                  onPressed: onDelete,
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? primaryColor : textSecondaryColor.withOpacity(0.3),
                    size: 22,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ────────────────────────────────────────────────────────────────────────
class _LibraryGridCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;
  final double? progress;

  const _LibraryGridCard({
    required this.item,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final borderCol = Theme.of(context).dividerColor;

    final iconInfo = item.isFolder 
        ? _FileIconInfo(Icons.folder_rounded, primaryColor)
        : _getFileIconInfo(item.extension, primaryColor);

    final rxSelected = controller.getRxSelected(item.path);

    return Obx(() {
      final isSelected = rxSelected.value;
      final isSelectionMode = controller.isSelectionMode.value;

      return GestureDetector(
        onTap: () {
          if (isSelectionMode) {
            controller.toggleSelection(item.path);
          } else {
            onTap();
          }
        },
        onLongPress: () {
          controller.toggleSelection(item.path);
        },
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderCol.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon area
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withOpacity(0.12)
                            : iconInfo.color.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      child: Center(
                        child: Icon(
                          iconInfo.icon,
                          color: iconInfo.color,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  // Text info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                item.isFolder ? 'FOLDER'.tr : item.extension,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (item.isFile && item.size > 0)
                              Text(
                                FileUtils.formatSize(item.size),
                                style: TextStyle(color: textSecondaryColor, fontSize: 9),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Progress & Actions Row
                        Row(
                          children: [
                            Expanded(
                              child: progress != null && progress! > 0
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(1.5),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: borderCol,
                                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                        minHeight: 3,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 4),
                            if (!isSelectionMode) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FavoriteStar(
                                    isFavorite: item.isFavorite,
                                    onTap: onFavoriteToggle,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: onDelete,
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent.withOpacity(0.7),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? primaryColor : textSecondaryColor.withOpacity(0.3),
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Floating grid card selection indicator
              if (isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? primaryColor : Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ────────────────────────────────────────────────────────────────────────
class _SortOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return ListTile(
      leading: Icon(icon, 
          color: isSelected ? primaryColor : textSecondaryColor, 
          size: 22),
      title: Text(title,
          style: TextStyle(
              color: isSelected ? primaryColor : textPrimaryColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedTileColor: primaryColor.withOpacity(0.05),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
class FavoriteStar extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final double size;

  const FavoriteStar({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.size = 24,
  });

  @override
  State<FavoriteStar> createState() => _FavoriteStarState();
}

class _FavoriteStarState extends State<FavoriteStar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant FavoriteStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Icon(
          widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          color: widget.isFavorite ? Colors.amber : textSecondaryColor.withOpacity(0.5),
          size: widget.size,
        ),
      ),
    );
  }
}

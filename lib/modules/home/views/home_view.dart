// lib/modules/home/views/home_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';
import 'package:pdf_reader/modules/home/widgets/main_drawer.dart';
import 'package:pdf_reader/modules/home/widgets/selection_details_sheet.dart';
import 'package:pdf_reader/routes/app_routes.dart';
import 'package:pdf_reader/modules/background_remover/views/remove_background_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/merge_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/split_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/organize_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/image_to_pdf_view.dart';
import 'package:pdf_reader/modules/pdf_tools/views/pdf_to_image_view.dart';


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
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final double systemBottom = MediaQuery.of(context).padding.bottom;
            final double hPadding = screenWidth < 360 ? 10.0 : 20.0;
            final double bPadding = screenHeight < 650 ? 10.0 : (systemBottom > 16 ? systemBottom : 16.0);
            
            return SafeArea(
              top: false,
              child: Center(
                heightFactor: 1.0,
                child: Padding(
                  padding: EdgeInsets.only(left: hPadding, right: hPadding, bottom: bPadding),
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
                        selectedLabelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth < 360 ? 10 : 11,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: screenWidth < 360 ? 9.5 : 11,
                        ),
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
                            icon: const Icon(Icons.history_outlined),
                            activeIcon: const Icon(Icons.history_rounded),
                            label: 'recents'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            activeIcon: const Icon(Icons.picture_as_pdf_rounded),
                            label: 'files'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.folder_outlined),
                            activeIcon: const Icon(Icons.folder_rounded),
                            label: 'folders'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.star_outline_rounded),
                            activeIcon: const Icon(Icons.star_rounded),
                            label: 'favorites'.tr,
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.handyman_outlined),
                            activeIcon: const Icon(Icons.handyman_rounded),
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

  List<Map<String, dynamic>> _getToolsList(BuildContext context) {
    return [
      {
        'id': 'remove_bg',
        'title': 'remove_background'.tr,
        'desc': 'desc_remove_bg'.tr,
        'icon': Icons.auto_fix_high_rounded,
        'isAvailable': true,
        'action': () => Get.to(() => const RemoveBackgroundView()),
      },
      {
        'id': 'merge_pdf',
        'title': 'tool_merge_pdf'.tr,
        'desc': 'desc_merge_pdf'.tr,
        'icon': Icons.merge_type_rounded,
        'isAvailable': true,
        'action': () => Get.to(() => const MergePdfView()),
      },
      {
        'id': 'split_pdf',
        'title': 'tool_split_pdf'.tr,
        'desc': 'desc_split_pdf'.tr,
        'icon': Icons.call_split_rounded,
        'isAvailable': true,
        'action': () => Get.to(() => const SplitPdfView()),
      },
      {
        'id': 'organize_pdf',
        'title': 'tool_organize_pdf'.tr,
        'desc': 'desc_organize_pdf'.tr,
        'icon': Icons.auto_stories_rounded,
        'isAvailable': true,
        'action': () => Get.to(() => const OrganizePdfView()),
      },
      {
        'id': 'img_to_pdf',
        'title': 'tool_img_to_pdf'.tr,
        'desc': 'desc_img_to_pdf'.tr,
        'icon': Icons.add_photo_alternate_rounded,
        'isAvailable': true,
        'action': () => Get.to(() => const ImageToPdfView()),
      },
      {
        'id': 'pdf_to_img',
        'title': 'tool_pdf_to_img'.tr,
        'desc': 'desc_pdf_to_img'.tr,
        'icon': Icons.photo_library_rounded,
        'isAvailable': true,
        'action': () => Get.to(() => const PdfToImageView()),
      },
      {
        'id': 'compress_pdf',
        'title': 'tool_compress_pdf'.tr,
        'desc': 'compress_pdf_desc'.tr,
        'icon': Icons.compress_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonDialog(context, 'tool_compress_pdf'.tr),
      },
      {
        'id': 'protect_pdf',
        'title': 'tool_protect_pdf'.tr,
        'desc': 'tool_coming_soon'.tr,
        'icon': Icons.lock_outline_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonDialog(context, 'tool_protect_pdf'.tr),
      },
      {
        'id': 'watermark',
        'title': 'tool_watermark'.tr,
        'desc': 'add_rotated_watermark_desc'.tr,
        'icon': Icons.branding_watermark_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonDialog(context, 'tool_watermark'.tr),
      },
      {
        'id': 'extract_text',
        'title': 'tool_extract_text'.tr,
        'desc': 'desc_extract_text'.tr,
        'icon': Icons.text_fields_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonDialog(context, 'tool_extract_text'.tr),
      },
    ];
  }

  Widget _buildToolsTab(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderCol = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final toolsList = _getToolsList(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 650 ? 3 : 2;
    final double childAspectRatio = screenWidth > 650
        ? 1.3
        : (screenWidth > 380
            ? 1.15
            : (screenWidth < 340 ? 0.92 : 1.0));

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: toolsList.length,
      itemBuilder: (context, index) {
        final tool = toolsList[index];
        final VoidCallback? onTap = tool['action'] as VoidCallback?;
        final isAvailable = tool['isAvailable'] as bool;

        return Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF22304D)
                      : borderCol.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Stack(
                children: [
                  // Coming Soon badge at top-end
                  if (!isAvailable)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'tool_coming_soon_badge'.tr,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),

                  // Centered Card Content: Icon centered, Title centered underneath
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              tool['icon'] as IconData,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tool['title'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tool['desc'] as String? ?? '',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 10.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ),
          ),
        );
      },
    );
  }

  void _showAddFavoriteToolSheet(BuildContext context, List<Map<String, dynamic>> tools) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final primaryColor = theme.primaryColor;
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Obx(() {
          final favIds = controller.favoriteTools;
          final availableTools = tools.where((t) => !favIds.contains(t['id'])).toList();

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'pin_tool_title'.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'pin_tool_desc'.tr,
                    style: TextStyle(fontSize: 12, color: textSecondaryColor),
                  ),
                  const SizedBox(height: 14),
                  if (availableTools.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'all_tools_pinned'.tr,
                          style: TextStyle(color: textSecondaryColor, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableTools.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final tool = availableTools[i];
                          return ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(tool['icon'] as IconData, color: primaryColor, size: 20),
                            ),
                            title: Text(
                              tool['title'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimaryColor),
                            ),
                            subtitle: Text(
                              tool['desc'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: textSecondaryColor),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              color: primaryColor,
                              onPressed: () {
                                controller.toggleFavoriteTool(tool['id'] as String);
                                if (controller.favoriteTools.length >= 6) {
                                  Navigator.pop(ctx);
                                }
                              },
                            ),
                            onTap: () {
                              controller.toggleFavoriteTool(tool['id'] as String);
                              if (controller.favoriteTools.length >= 6) {
                                Navigator.pop(ctx);
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showShortcutOptionsSheet(BuildContext context, Map<String, dynamic> tool) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final primaryColor = theme.primaryColor;
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tool['icon'] as IconData, color: primaryColor, size: 22),
                  ),
                  title: Text(
                    tool['title'] as String,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimaryColor),
                  ),
                  subtitle: Text(
                    tool['desc'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: textSecondaryColor),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: Text('open_tool'.tr),
                  onTap: () {
                    Navigator.pop(ctx);
                    final VoidCallback? onTap = tool['action'] as VoidCallback?;
                    onTap?.call();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: Text(
                    'remove_shortcut'.tr,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.toggleFavoriteTool(tool['id'] as String);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context, String toolName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(toolName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'coming_soon_dialog_desc'.tr,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('got_it'.tr),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final cardBg = theme.cardColor;
    final borderCol = theme.dividerColor;
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final tools = _getToolsList(context);

    return Obx(() {
      final recents = controller.recentItems;
      final favToolIds = controller.favoriteTools;
      final favTools = tools.where((t) => favToolIds.contains(t['id'])).toList();

      if (recents.isEmpty && favTools.isEmpty) {
        return _buildEmptyState(
          context,
          Icons.history_rounded,
          'recents'.tr,
          'empty_recents_desc'.tr,
        );
      }

      final showAddButton = favTools.length < 6;
      final totalGridItems = favTools.length + (showAddButton ? 1 : 0);

      Widget favoritesSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  'tool_shortcuts'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: MediaQuery.of(context).size.width < 360 ? 1.25 : 1.4, // Responsive ratio for compact & standard screens
              ),
              itemCount: totalGridItems,
              itemBuilder: (ctx, idx) {
                if (idx < favTools.length) {
                  final tool = favTools[idx];
                  final VoidCallback? onTap = tool['action'] as VoidCallback?;

                  return Material(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onTap,
                      onLongPress: () => _showShortcutOptionsSheet(context, tool),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF22304D) : borderCol.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              tool['icon'] as IconData,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                tool['title'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  // (+) Add pinned tool button
                  return Material(
                    color: isDark ? const Color(0xFF162032) : primaryColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showAddFavoriteToolSheet(context, tools),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'add_tool'.tr,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      );

      if (favTools.isEmpty && recents.isEmpty) {
        return _buildEmptyState(
          context,
          Icons.history_rounded,
          'recents'.tr,
          'empty_recents_desc'.tr,
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          favoritesSection,
          if (recents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'recents'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ),
            Expanded(child: _buildItemsList(context, recents)),
          ],
        ],
      );
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
            childAspectRatio: width < 360 ? 0.82 : (width > 600 ? 0.95 : 0.88),
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
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: primaryColor),
                  onPressed: controller.clearSelection,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Obx(() => Text(
                        '${controller.selectedPaths.length} ${"selected".tr}',
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                ),
              ],
            ),
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

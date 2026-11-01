import 'dart:io';

void main() {
  final file = File('lib/modules/home/views/home_view.dart');
  var content = file.readAsStringSync();

  final startIdx = content.indexOf('Widget _buildToolsTab(BuildContext context) {');
  final endIdx = content.indexOf('Widget _buildFavoritesTab(BuildContext context) {');

  if (startIdx == -1 || endIdx == -1) {
    print('Failed to locate _buildToolsTab');
    return;
  }

  const newCode = '''Widget _buildToolsTab(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondaryColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderCol = Theme.of(context).dividerColor;

    final List<Map<String, dynamic>> toolsList = [
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
        'title': 'merge_documents'.tr,
        'desc': 'desc_merge_pdf'.tr,
        'icon': Icons.merge_type_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonSheet(context, 'merge_documents'.tr, 'desc_merge_pdf'.tr, Icons.merge_type_rounded),
      },
      {
        'id': 'split_pdf',
        'title': 'split_pdf_pages'.tr,
        'desc': 'desc_split_pdf'.tr,
        'icon': Icons.call_split_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonSheet(context, 'split_pdf_pages'.tr, 'desc_split_pdf'.tr, Icons.call_split_rounded),
      },
      {
        'id': 'img_to_pdf',
        'title': 'Image to PDF',
        'desc': 'desc_img_to_pdf'.tr,
        'icon': Icons.image_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonSheet(context, 'Image to PDF', 'desc_img_to_pdf'.tr, Icons.image_rounded),
      },
      {
        'id': 'pdf_to_img',
        'title': 'convert_to_png'.tr,
        'desc': 'desc_pdf_to_img'.tr,
        'icon': Icons.picture_in_picture_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonSheet(context, 'convert_to_png'.tr, 'desc_pdf_to_img'.tr, Icons.picture_in_picture_rounded),
      },
      {
        'id': 'extract_text',
        'title': 'extract_text'.tr,
        'desc': 'desc_extract_text'.tr,
        'icon': Icons.text_fields_rounded,
        'isAvailable': false,
        'action': () => _showComingSoonSheet(context, 'extract_text'.tr, 'desc_extract_text'.tr, Icons.text_fields_rounded),
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 650 ? 3 : 2;
    final double aspectRatio = screenWidth > 400 ? 1.25 : 1.15;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Text(
                'tools'.tr,
                style: TextStyle(color: textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Aura Toolbox',
                  style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: toolsList.length,
          itemBuilder: (context, index) {
            final tool = toolsList[index];
            final bool isAvailable = tool['isAvailable'] as bool;
            final VoidCallback? onTap = tool['action'] as VoidCallback?;

            return Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAvailable
                          ? primaryColor.withValues(alpha: 0.3)
                          : borderCol.withValues(alpha: 0.4),
                      width: isAvailable ? 1.5 : 1.0,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Icon and Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? primaryColor.withValues(alpha: 0.12)
                                  : borderCol.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              tool['icon'] as IconData,
                              color: isAvailable ? primaryColor : textSecondaryColor,
                              size: 22,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : textSecondaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isAvailable) ...[
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isAvailable ? 'tool_available'.tr : 'tool_coming_soon_badge'.tr,
                                  style: TextStyle(
                                    color: isAvailable ? Colors.green : textSecondaryColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Tool Title and Description
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tool['title'] as String,
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
                            tool['desc'] as String,
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
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  void _showComingSoonSheet(BuildContext context, String title, String desc, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: theme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'coming_soon_title'.tr,
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'coming_soon_dialog_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Get.back(),
                child: Text('got_it'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
''';

  content = content.substring(0, startIdx) + newCode + content.substring(endIdx);
  file.writeAsStringSync(content);
  print('Successfully updated tools in home_view.dart');
}

import 'dart:io';

void main() {
  final file = File('lib/modules/home/views/home_view.dart');
  var content = file.readAsStringSync();

  // Add import if not present
  const importLine = "import 'package:pdf_reader/modules/background_remover/views/remove_background_view.dart';\n";
  if (!content.contains('remove_background_view.dart')) {
    content = content.replaceFirst(
      "import 'package:pdf_reader/routes/app_routes.dart';",
      "import 'package:pdf_reader/routes/app_routes.dart';\n$importLine",
    );
  }

  // Replace _buildToolsTab
  final startIdx = content.indexOf('Widget _buildToolsTab(BuildContext context) {');
  final endIdx = content.indexOf('Widget _buildFavoritesTab(BuildContext context) {');

  if (startIdx == -1 || endIdx == -1) {
    print('Failed to locate _buildToolsTab in home_view.dart');
    return;
  }

  final newToolsTab = '''Widget _buildToolsTab(BuildContext context) {
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderCol = Theme.of(context).dividerColor;

    final List<Map<String, dynamic>> toolsList = [
      {
        'id': 'remove_bg',
        'title': 'remove_background'.tr,
        'icon': Icons.auto_fix_high_rounded,
        'action': () => Get.to(() => const RemoveBackgroundView()),
      },
      {
        'id': 'merge_pdf',
        'title': 'Merge PDFs',
        'icon': Icons.merge_type_rounded,
        'action': () => Get.snackbar('tools'.tr, 'tool_coming_soon'.tr, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2)),
      },
      {
        'id': 'split_pdf',
        'title': 'Split PDF',
        'icon': Icons.call_split_rounded,
        'action': () => Get.snackbar('tools'.tr, 'tool_coming_soon'.tr, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2)),
      },
      {
        'id': 'img_to_pdf',
        'title': 'Image to PDF',
        'icon': Icons.image_rounded,
        'action': () => Get.snackbar('tools'.tr, 'tool_coming_soon'.tr, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2)),
      },
      {
        'id': 'pdf_to_img',
        'title': 'PDF to Image',
        'icon': Icons.picture_in_picture_rounded,
        'action': () => Get.snackbar('tools'.tr, 'tool_coming_soon'.tr, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2)),
      },
      {
        'id': 'extract_text',
        'title': 'Extract Text',
        'icon': Icons.text_fields_rounded,
        'action': () => Get.snackbar('tools'.tr, 'tool_coming_soon'.tr, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2)),
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 5 : 3;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: toolsList.length,
          itemBuilder: (context, index) {
            final tool = toolsList[index];
            final VoidCallback? onTap = tool['action'] as VoidCallback?;

            return Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol.withValues(alpha: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(tool['icon'] as IconData, color: primaryColor, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tool['title'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
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

  ''';

  content = content.substring(0, startIdx) + newToolsTab + content.substring(endIdx);
  file.writeAsStringSync(content);
  print('Successfully updated _buildToolsTab in home_view.dart');
}

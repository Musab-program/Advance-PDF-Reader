import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:xml/xml.dart';
import 'package:pdf_reader/modules/xml_reader/controllers/xml_reader_controller.dart';

class XmlReaderView extends GetView<XmlReaderController> {
  const XmlReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardBg = theme.cardColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimaryColor, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Obx(() => Text(
              controller.fileName.value,
              style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
        actions: [
          IconButton(
            icon: Icon(Icons.copy_rounded, color: textPrimaryColor, size: 20),
            onPressed: () {
              final text = controller.viewMode.value == 'raw'
                  ? controller.rawContent.value
                  : controller.formattedContent.value;
              Clipboard.setData(ClipboardData(text: text));
              Get.snackbar(
                'copied_to_clipboard'.tr,
                controller.fileName.value,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
            tooltip: 'Copy',
          ),
          IconButton(
            icon: Icon(Icons.text_decrease_rounded, color: textPrimaryColor, size: 20),
            onPressed: controller.decreaseFontSize,
            tooltip: 'Decrease font size',
          ),
          IconButton(
            icon: Icon(Icons.text_increase_rounded, color: textPrimaryColor, size: 20),
            onPressed: controller.increaseFontSize,
            tooltip: 'Increase font size',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
            ),
            child: Obx(() {
              final mode = controller.viewMode.value;
              final hasError = controller.hasParseError.value;

              return Row(
                children: [
                  _buildTabButton(
                    context: context,
                    label: 'xml_formatted'.tr,
                    icon: Icons.format_align_left_rounded,
                    isActive: mode == 'formatted',
                    isDisabled: hasError,
                    onTap: () => controller.setViewMode('formatted'),
                  ),
                  const SizedBox(width: 8),
                  _buildTabButton(
                    context: context,
                    label: 'xml_tree'.tr,
                    icon: Icons.account_tree_rounded,
                    isActive: mode == 'tree',
                    isDisabled: hasError,
                    onTap: () => controller.setViewMode('tree'),
                  ),
                  const SizedBox(width: 8),
                  _buildTabButton(
                    context: context,
                    label: 'xml_raw'.tr,
                    icon: Icons.raw_on_rounded,
                    isActive: mode == 'raw',
                    isDisabled: false,
                    onTap: () => controller.setViewMode('raw'),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          return Column(
            children: [
              if (controller.hasParseError.value)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.amber.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'xml_invalid_notice'.tr,
                          style: const TextStyle(fontSize: 12.5, color: Colors.deepOrange),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _buildContent(context),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Expanded(
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? primaryColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? primaryColor : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDisabled
                    ? Colors.grey.shade400
                    : (isActive ? primaryColor : textPrimaryColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isDisabled
                      ? Colors.grey.shade400
                      : (isActive ? primaryColor : textPrimaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimaryColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final mode = controller.viewMode.value;

    if (mode == 'tree' && controller.xmlDocument.value != null) {
      final root = controller.xmlDocument.value!.rootElement;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: _XmlTreeNode(element: root, level: 0, fontSize: controller.fontSize.value),
          ),
        ],
      );
    }

    final text = mode == 'raw'
        ? controller.rawContent.value
        : controller.formattedContent.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: controller.fontSize.value,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _XmlTreeNode extends StatefulWidget {
  final XmlElement element;
  final int level;
  final double fontSize;

  const _XmlTreeNode({
    required this.element,
    required this.level,
    required this.fontSize,
  });

  @override
  State<_XmlTreeNode> createState() => _XmlTreeNodeState();
}

class _XmlTreeNodeState extends State<_XmlTreeNode> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childElements = widget.element.childElements.toList();
    final hasChildren = childElements.isNotEmpty;
    final hasAttributes = widget.element.attributes.isNotEmpty;
    final directText = widget.element.children
        .whereType<XmlText>()
        .map((e) => e.value.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');

    return Padding(
      padding: EdgeInsetsDirectional.only(start: widget.level > 0 ? 12.0 : 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasChildren ? () => setState(() => _isExpanded = !_isExpanded) : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasChildren)
                    Icon(
                      _isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.primaryColor,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 4),
                  // Tag Name
                  Flexible(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          '<${widget.element.name.local}>',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: widget.fontSize,
                            fontFamily: 'monospace',
                          ),
                        ),
                        // Attributes Chips
                        if (hasAttributes)
                          ...widget.element.attributes.map((attr) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${attr.name.local}="${attr.value}"',
                                style: TextStyle(
                                  fontSize: widget.fontSize * 0.85,
                                  color: Colors.amber.shade900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }),
                        // Direct Text
                        if (directText.isNotEmpty)
                          Text(
                            directText,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: widget.fontSize,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasChildren && _isExpanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: childElements.map((child) {
                    return _XmlTreeNode(
                      element: child,
                      level: widget.level + 1,
                      fontSize: widget.fontSize,
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

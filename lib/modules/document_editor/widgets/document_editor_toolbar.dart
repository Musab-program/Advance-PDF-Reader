import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/document_editor_controller.dart';
import '../models/editor_models.dart';
import '../../pdf_tools/views/pdf_to_image_view.dart';

class DocumentEditorToolbar extends StatelessWidget {
  final DocumentEditorController controller;

  const DocumentEditorToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final dividerCol = theme.dividerColor;

    return Obx(() {
      final activeTab = controller.activeTab.value;

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: dividerCol.withValues(alpha: 0.6))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Sub-Toolbar Tier (Setting Bar / Sub-tools) ───
            if (activeTab != EditorTab.none)
              _buildSubToolbar(context, activeTab, theme, isDark),

            // ─── Main Tabs Tier (WPS 4-tab Layout) ───
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _mainTabButton(
                      context: context,
                      icon: Icons.draw_rounded,
                      label: 'wps_tab_annotate'.tr,
                      isActive: activeTab == EditorTab.annotate,
                      onTap: () => controller.switchTab(EditorTab.annotate),
                    ),
                    _mainTabButton(
                      context: context,
                      icon: Icons.assignment_turned_in_rounded,
                      label: 'wps_tab_fill_sign'.tr,
                      isActive: activeTab == EditorTab.fillSign,
                      onTap: () => controller.switchTab(EditorTab.fillSign),
                    ),
                    _mainTabButton(
                      context: context,
                      icon: Icons.edit_note_rounded,
                      label: 'wps_tab_edit'.tr,
                      isActive: activeTab == EditorTab.edit,
                      onTap: () => controller.switchTab(EditorTab.edit),
                    ),
                    _mainTabButton(
                      context: context,
                      icon: Icons.transform_rounded,
                      label: 'wps_tab_convert'.tr,
                      isActive: activeTab == EditorTab.convert,
                      onTap: () => controller.switchTab(EditorTab.convert),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSubToolbar(BuildContext context, EditorTab tab, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.scaffoldBackgroundColor.withValues(alpha: 0.65) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4))),
      ),
      child: () {
        switch (tab) {
          case EditorTab.annotate:
            return _buildAnnotateSubBar(context, theme);
          case EditorTab.fillSign:
            return _buildFillSignSubBar(context, theme);
          case EditorTab.edit:
            return _buildEditSubBar(context, theme);
          case EditorTab.convert:
            return _buildConvertSubBar(context, theme);
          default:
            return const SizedBox.shrink();
        }
      }(),
    );
  }

  // 1. Annotate Sub-bar: Pen, Highlighter, Eraser, Shapes, Thickness, Colors
  Widget _buildAnnotateSubBar(BuildContext context, ThemeData theme) {
    return Obx(() {
      final currentTool = controller.activeAnnotateTool.value;
      final currentColor = controller.selectedColor.value;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Tools (Select, Pen, Highlighter, Underline, Strikeout, Eraser, Shapes)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _subToolChip(
                  context: context,
                  icon: Icons.near_me_rounded,
                  label: 'wps_tool_select'.tr,
                  isSelected: currentTool == AnnotateTool.select,
                  onTap: () => controller.selectAnnotateTool(AnnotateTool.select),
                ),
                const SizedBox(width: 8),
                _subToolChip(
                  context: context,
                  icon: Icons.edit_rounded,
                  label: 'wps_tool_pen'.tr,
                  isSelected: currentTool == AnnotateTool.pen,
                  onTap: () => controller.selectAnnotateTool(AnnotateTool.pen),
                ),
                const SizedBox(width: 8),
                _subToolChip(
                  context: context,
                  icon: Icons.border_color_rounded,
                  label: 'wps_tool_highlighter'.tr,
                  isSelected: currentTool == AnnotateTool.highlighter,
                  onTap: () => controller.selectAnnotateTool(AnnotateTool.highlighter),
                ),
                const SizedBox(width: 8),
                _subToolChip(
                  context: context,
                  icon: Icons.format_underlined_rounded,
                  label: 'wps_tool_underline'.tr,
                  isSelected: currentTool == AnnotateTool.underline,
                  onTap: () => controller.selectAnnotateTool(AnnotateTool.underline),
                ),
                const SizedBox(width: 8),
                _subToolChip(
                  context: context,
                  icon: Icons.strikethrough_s_rounded,
                  label: 'wps_tool_strikeout'.tr,
                  isSelected: currentTool == AnnotateTool.strikeout,
                  onTap: () => controller.selectAnnotateTool(AnnotateTool.strikeout),
                ),
                const SizedBox(width: 8),
                _subToolChip(
                  context: context,
                  icon: Icons.auto_fix_normal_rounded,
                  label: 'wps_tool_eraser'.tr,
                  isSelected: currentTool == AnnotateTool.eraser,
                  onTap: () => controller.selectAnnotateTool(AnnotateTool.eraser),
                ),
                const SizedBox(width: 8),
                _buildShapesMenu(context, theme),
              ],
            ),
          ),

          // Row 2: Colors Palette + Stroke Thickness Slider (When not using eraser)
          if (currentTool != AnnotateTool.eraser) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Color Circles
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _colorCircle(context, const Color(0xFFDC2626), currentColor),
                    const SizedBox(width: 4),
                    _colorCircle(context, const Color(0xFF2563EB), currentColor),
                    const SizedBox(width: 4),
                    _colorCircle(context, const Color(0xFF16A34A), currentColor),
                    const SizedBox(width: 4),
                    _colorCircle(context, const Color(0xFFEAB308), currentColor),
                    const SizedBox(width: 4),
                    _colorCircle(context, const Color(0xFF0F172A), currentColor),
                  ],
                ),
                const SizedBox(width: 6),
                Container(
                  height: 16,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      activeTrackColor: theme.primaryColor,
                      inactiveTrackColor: theme.dividerColor,
                      thumbColor: theme.primaryColor,
                      padding: EdgeInsets.zero,
                    ),
                    child: Slider(
                      value: controller.strokeWidth.value.clamp(1.0, 24.0),
                      min: 1.0,
                      max: 24.0,
                      onChanged: (val) => controller.setStrokeWidth(val),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 25,
                  child: Text(
                    '${controller.strokeWidth.value.toInt()}p',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _buildShapesMenu(BuildContext context, ThemeData theme) {
    return PopupMenuButton<StampType>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.dividerColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 14, color: theme.colorScheme.onSurface),
            const SizedBox(width: 3),
            Text(
              'wps_tool_shapes'.tr,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (type) => controller.addShape(type),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: StampType.rectShape,
          child: Row(
            children: [
              Icon(Icons.crop_square_rounded, size: 18),
              SizedBox(width: 8),
              Text('مستطيل (Rectangle)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: StampType.circleShape,
          child: Row(
            children: [
              Icon(Icons.circle_outlined, size: 18),
              SizedBox(width: 8),
              Text('دائرة (Circle)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: StampType.lineShape,
          child: Row(
            children: [
              Icon(Icons.horizontal_rule_rounded, size: 18),
              SizedBox(width: 8),
              Text('خط مستقيم (Line)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: StampType.arrowShape,
          child: Row(
            children: [
              Icon(Icons.arrow_right_alt_rounded, size: 18),
              SizedBox(width: 8),
              Text('سهم توضيحي (Arrow)'),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Fill & Sign Sub-bar: Signature, Quick Text, Check, Cross, Dot, Date
  Widget _buildFillSignSubBar(BuildContext context, ThemeData theme) {
    final primary = theme.primaryColor;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _actionChip(
            context: context,
            icon: Icons.draw_rounded,
            label: 'wps_tool_signature'.tr,
            color: primary,
            onTap: () => controller.handleFillSignAction(FillSignTool.signature, context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.title_rounded,
            label: 'wps_tool_quick_text'.tr,
            onTap: () => controller.handleFillSignAction(FillSignTool.quickText, context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.check_circle_outline_rounded,
            label: '✔ ${'wps_tool_check'.tr}',
            color: const Color(0xFF16A34A),
            onTap: () => controller.handleFillSignAction(FillSignTool.check, context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.cancel_outlined,
            label: '✖ ${'wps_tool_cross'.tr}',
            color: const Color(0xFFDC2626),
            onTap: () => controller.handleFillSignAction(FillSignTool.cross, context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.circle,
            label: '● ${'wps_tool_dot'.tr}',
            color: const Color(0xFF2563EB),
            onTap: () => controller.handleFillSignAction(FillSignTool.dot, context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.today_rounded,
            label: '📅 ${'wps_tool_date'.tr}',
            color: primary,
            onTap: () => controller.handleFillSignAction(FillSignTool.dateStamp, context),
          ),
        ],
      ),
    );
  }

  // 3. Edit Sub-bar: Formatted Text Box & Smart Whiteout
  Widget _buildEditSubBar(BuildContext context, ThemeData theme) {
    final primary = theme.primaryColor;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _actionChip(
            context: context,
            icon: Icons.text_fields_rounded,
            label: 'wps_tool_formatted_text'.tr,
            color: primary,
            onTap: () => controller.handleEditAction(EditTool.formattedText, context),
          ),
          const SizedBox(width: 10),
          _actionChip(
            context: context,
            icon: Icons.layers_clear_rounded,
            label: 'wps_tool_whiteout_smart'.tr,
            color: const Color(0xFFD97706),
            onTap: () => controller.handleEditAction(EditTool.whiteout, context),
          ),
        ],
      ),
    );
  }

  // 4. Convert Sub-bar: PDF to Images, Export Text File, Copy Page Text
  Widget _buildConvertSubBar(BuildContext context, ThemeData theme) {
    final primary = theme.primaryColor;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _actionChip(
            context: context,
            icon: Icons.photo_library_rounded,
            label: 'wps_tool_pdf_to_images'.tr,
            color: primary,
            onTap: () {
              if (controller.filePath.value.isNotEmpty) {
                Get.to(() => PdfToImageView(initialFilePath: controller.filePath.value));
              }
            },
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.description_rounded,
            label: 'wps_tool_extract_text'.tr,
            color: const Color(0xFF16A34A),
            onTap: () => controller.extractText(context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            context: context,
            icon: Icons.copy_rounded,
            label: 'wps_tool_copy_page_text'.tr,
            color: const Color(0xFF2563EB),
            onTap: () => controller.copyCurrentPageText(),
          ),
        ],
      ),
    );
  }

  Widget _mainTabButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? primary : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? primary : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subToolChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primary : theme.dividerColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorCircle(BuildContext context, Color color, Color selectedColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = color.toARGB32() == selectedColor.toARGB32();
    final isDarkColor = color.computeLuminance() < 0.2;

    return GestureDetector(
      onTap: () => controller.setDrawingColor(color),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : (isDarkColor
                    ? (isDark ? Colors.white60 : Colors.black26)
                    : Colors.transparent),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

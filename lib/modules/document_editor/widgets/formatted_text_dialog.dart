import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';

class FormattedTextConfig {
  final String text;
  final double fontSize;
  final bool isBold;
  final TextAlign alignment;
  final Color textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool pickBackgroundFromPage;

  const FormattedTextConfig({
    required this.text,
    required this.fontSize,
    required this.isBold,
    required this.alignment,
    required this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.pickBackgroundFromPage = false,
  });
}

class FormattedTextDialog extends StatefulWidget {
  final FormattedTextConfig? initialConfig;

  const FormattedTextDialog({super.key, this.initialConfig});

  static Future<FormattedTextConfig?> show(
    BuildContext context, {
    FormattedTextConfig? initialConfig,
  }) {
    return LuxuryDialog.showCustom<FormattedTextConfig>(
      context,
      builder: (_) => FormattedTextDialog(initialConfig: initialConfig),
    );
  }

  @override
  State<FormattedTextDialog> createState() => _FormattedTextDialogState();
}

class _FormattedTextDialogState extends State<FormattedTextDialog> {
  late final TextEditingController _controller;
  late double _fontSize;
  late bool _isBold;
  late TextAlign _alignment;
  late Color _textColor;
  late Color? _backgroundColor;
  late Color? _borderColor;

  final List<Color> _textColors = const [
    Color(0xFF0F172A), // Slate black
    Color(0xFF1D4ED8), // Blue
    Color(0xFFDC2626), // Red
    Color(0xFF16A34A), // Green
    Color(0xFFD97706), // Amber
  ];

  final List<Color?> _bgColors = const [
    null, // Transparent
    Color(0xFFFFFFFF), // White
    Color(0xFFFEF3C7), // Light yellow
    Color(0xFFEFF6FF), // Light blue
    Color(0xFFF3F4F6), // Light gray
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialConfig;
    _controller = TextEditingController(text: init?.text ?? '');
    _fontSize = init?.fontSize ?? 16.0;
    _isBold = init?.isBold ?? false;
    _alignment = init?.alignment ?? TextAlign.right;
    _textColor = init?.textColor ?? const Color(0xFF0F172A);
    _backgroundColor = init?.backgroundColor ?? const Color(0xFFFFFFFF);
    _borderColor = init?.borderColor ?? const Color(0xFFCBD5E1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({bool pickBackgroundFromPage = false}) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (pickBackgroundFromPage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('wps_enter_text_first'.tr)),
        );
      }
      return;
    }
    Navigator.of(context).pop(FormattedTextConfig(
      text: text,
      fontSize: _fontSize,
      isBold: _isBold,
      alignment: _alignment,
      textColor: _textColor,
      backgroundColor: _backgroundColor,
      borderColor: _borderColor,
      pickBackgroundFromPage: pickBackgroundFromPage,
    ));
  }

  Color _unselectedOutlineColor(Color c, bool isDark) {
    final lum = c.computeLuminance();
    if (isDark) {
      return lum < 0.25 ? Colors.white.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.24);
    }
    return lum > 0.85 ? Colors.grey.shade400 : Colors.black.withValues(alpha: 0.16);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        decoration: LuxuryDialog.cardDecoration(context, borderRadius: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, color: primary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.initialConfig == null
                                ? 'wps_insert_formatted_box'.tr
                                : 'wps_edit_formatted_box'.tr,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Preview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _backgroundColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: _borderColor != null
                      ? Border.all(color: _borderColor!, width: 1.5)
                      : Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 0.5),
                ),
                child: Text(
                  _controller.text.isEmpty ? 'wps_text_preview_hint'.tr : _controller.text,
                  textAlign: _alignment,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                    color: _textColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Text Field
              TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 2,
                autofocus: widget.initialConfig == null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'wps_write_text_here'.tr,
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Row 1: Bold toggle + Font size counter
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        isSelected: _isBold,
                        icon: const Icon(Icons.format_bold_rounded, size: 20),
                        onPressed: () => setState(() => _isBold = !_isBold),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'wps_bold'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                        onPressed: () {
                          if (_fontSize > 10) setState(() => _fontSize -= 2);
                        },
                      ),
                      Text(
                        '${_fontSize.toInt()}pt',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        onPressed: () {
                          if (_fontSize < 48) setState(() => _fontSize += 2);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Text alignment toggles
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text('wps_alignment'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton.filledTonal(
                    isSelected: _alignment == TextAlign.right,
                    icon: const Icon(Icons.format_align_right_rounded, size: 18),
                    onPressed: () => setState(() => _alignment = TextAlign.right),
                  ),
                  IconButton.filledTonal(
                    isSelected: _alignment == TextAlign.center,
                    icon: const Icon(Icons.format_align_center_rounded, size: 18),
                    onPressed: () => setState(() => _alignment = TextAlign.center),
                  ),
                  IconButton.filledTonal(
                    isSelected: _alignment == TextAlign.left,
                    icon: const Icon(Icons.format_align_left_rounded, size: 18),
                    onPressed: () => setState(() => _alignment = TextAlign.left),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Text Color Row
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('wps_text_color'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  for (final c in _textColors)
                    GestureDetector(
                      onTap: () => setState(() => _textColor = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _textColor == c ? primary : _unselectedOutlineColor(c, isDark),
                            width: _textColor == c ? 2.5 : 1.3,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Background Fill + Page Eyedropper + Frame Toggle
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('wps_bg_color'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  for (final bg in _bgColors)
                    GestureDetector(
                      onTap: () => setState(() => _backgroundColor = bg),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: bg ?? Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _backgroundColor == bg
                                ? primary
                                : _unselectedOutlineColor(bg ?? Colors.grey, isDark),
                            width: _backgroundColor == bg ? 2.5 : 1.2,
                          ),
                        ),
                        child: bg == null
                            ? const Icon(Icons.block_rounded, size: 14, color: Colors.grey)
                            : null,
                      ),
                    ),
                  if (_backgroundColor != null && !_bgColors.contains(_backgroundColor))
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: primary, width: 2.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _submit(pickBackgroundFromPage: true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.colorize_rounded, size: 16, color: primary),
                    label: Text(
                      'wps_pick_from_page'.tr,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _borderColor = _borderColor == null ? const Color(0xFF94A3B8) : null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      _borderColor != null ? Icons.border_outer_rounded : Icons.border_clear_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _borderColor != null ? 'wps_remove_border'.tr : 'wps_add_border'.tr,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('cancel'.tr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: LuxuryDialog.gradientButton(
                      context: context,
                      label: widget.initialConfig == null ? 'wps_insert'.tr : 'wps_save_changes'.tr,
                      icon: Icons.check_rounded,
                      height: 44,
                      borderRadius: 13,
                      onTap: () => _submit(),
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

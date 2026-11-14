import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/modules/reader/controllers/reader_controller.dart';

class SpeedPickerSheet extends StatefulWidget {
  const SpeedPickerSheet({super.key});

  @override
  State<SpeedPickerSheet> createState() => _SpeedPickerSheetState();
}

class _SpeedPickerSheetState extends State<SpeedPickerSheet> {
  late final TextEditingController _textController;
  late final ReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ReaderController>();
    _textController = TextEditingController(
      text: _formatSpeed(_controller.autoScrollSpeed.value),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _formatSpeed(double speed) {
    if (speed % 1 == 0) {
      return speed >= 10.0 ? '${speed.toInt()}' : speed.toStringAsFixed(1);
    }
    if ((speed * 10) % 1 == 0) {
      return speed.toStringAsFixed(1);
    }
    return speed.toStringAsFixed(2);
  }

  void _applyTextSpeed() {
    final val = double.tryParse(_textController.text.trim());
    if (val != null && val >= 0.1 && val <= 20.0) {
      _controller.setCustomAutoScrollSpeed(val);
      Get.back();
    } else {
      Get.snackbar(
        'error'.tr,
        'enter_speed_hint'.tr,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    // Luxurious neutral titanium / amber palette
    const accentColor = Color(0xFF7C4DFF); // Unified app brand violet
    final sheetBg = isDark ? const Color(0xFF18181C) : Colors.white;
    final cardBg = isDark ? const Color(0xFF222228) : const Color(0xFFF3F3F6);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: bottomInset > 0 ? bottomInset + 16 : paddingBottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Icon + Title + Current Speed Badge + Close
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Icon(
                      Icons.speed_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'scroll_speed'.tr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Current speed badge
                  Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 0.8),
                        ),
                        child: Text(
                          '${_formatSpeed(_controller.autoScrollSpeed.value)}x',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      )),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Direct Speed Number Input & Apply Button (supports e.g. 11.25, 11.5, 15, 20)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _applyTextSpeed(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        labelText: 'custom_speed'.tr,
                        hintText: 'enter_speed_hint'.tr,
                        prefixIcon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        suffixText: 'x',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white70 : Colors.black87,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF18181C),
                      foregroundColor: isDark ? const Color(0xFF18181C) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: _applyTextSpeed,
                    child: Text(
                      'apply'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Quick Presets Chips (1x, 2.5x, 5x, 10x, 15x, 20x)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [1.0, 2.5, 5.0, 10.0, 15.0, 20.0].map((preset) {
                  return Obx(() {
                    final isSelected = (_controller.autoScrollSpeed.value - preset).abs() < 0.05;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        _controller.setCustomAutoScrollSpeed(preset);
                        _textController.text = _formatSpeed(preset);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor.withValues(alpha: 0.18) : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? accentColor : borderColor,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                        ),
                        child: Text(
                          '${_formatSpeed(preset)}x',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? accentColor
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  });
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Smooth Slider with 0.25 Steps up to 20.0x
              Obx(() {
                final current = _controller.autoScrollSpeed.value.clamp(0.25, 20.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accentColor,
                        thumbColor: accentColor,
                        inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      ),
                      child: Slider(
                        value: current,
                        min: 0.25,
                        max: 20.0,
                        divisions: 79, // Exact 0.25 steps from 0.25 to 20.0
                        label: '${_formatSpeed(current)}x',
                        onChanged: (val) {
                          _controller.setCustomAutoScrollSpeed(val);
                          _textController.text = _formatSpeed(val);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.25x', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                          Text('5x', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                          Text('10x', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                          Text('15x', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                          Text('20x', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 12),

              // Quick Reset Button (1.0x)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: isDark ? Colors.white70 : Colors.black54,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    '${'reset'.tr} (1.0x)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    _controller.resetAutoScrollSpeed();
                    _textController.text = '1.0';
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

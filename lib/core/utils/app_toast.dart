import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A modern, compact top-centered floating toast/snackbar designed
/// to take around ~55-65% of the screen width with sleek pill styling.
class AppToast {
  AppToast._();

  static void showSuccess(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF10B981),
      duration: duration ?? const Duration(milliseconds: 2200),
    );
  }

  static void showError(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.error_rounded,
      iconColor: const Color(0xFFEF4444),
      duration: duration ?? const Duration(milliseconds: 3000),
    );
  }

  static void showWarning(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFF59E0B),
      duration: duration ?? const Duration(milliseconds: 2500),
    );
  }

  static void showInfo(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF3B82F6),
      duration: duration ?? const Duration(milliseconds: 2200),
    );
  }

  static void _show({
    required String message,
    required IconData icon,
    required Color iconColor,
    required Duration duration,
  }) {
    if (Get.overlayContext == null && Get.context == null) {
      return;
    }

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    final context = Get.context;
    final double screenWidth = context != null ? MediaQuery.of(context).size.width : 400.0;
    // Keep width ~55-65% of screen, capped between 220 and 360 px
    final double targetWidth = (screenWidth * 0.62).clamp(230.0, 360.0);
    final double horizontalMargin = ((screenWidth - targetWidth) / 2).clamp(16.0, 120.0);

    Get.rawSnackbar(
      messageText: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xEB161822),
      borderRadius: 26,
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      duration: duration,
      animationDuration: const Duration(milliseconds: 320),
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInCubic,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      borderColor: Colors.white.withValues(alpha: 0.12),
      borderWidth: 1,
      barBlur: 10,
      isDismissible: true,
      snackStyle: SnackStyle.FLOATING,
    );
  }
}

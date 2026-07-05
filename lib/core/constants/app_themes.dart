// lib/core/constants/app_themes.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static ThemeData getTheme({
    required bool isDark,
    required String fontFamily,
    required double fontScale,
  }) {
    final Color primaryColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final Color scaffoldBg = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF151D30) : const Color(0xFFFFFFFF);
    final Color dividerCol = isDark ? const Color(0xFF22304D) : const Color(0xFFE2E8F0);
    final Brightness brightness = isDark ? Brightness.dark : Brightness.light;

    // Define base TextTheme
    final Color textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    final TextTheme baseTextTheme = TextTheme(
      bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      bodySmall: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 11),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
    );

    // Apply google font family if not system
    TextTheme fontTheme;
    String? resolvedFontFamily;
    if (fontFamily.toLowerCase() == 'system') {
      fontTheme = baseTextTheme;
    } else {
      try {
        fontTheme = GoogleFonts.getTextTheme(fontFamily, baseTextTheme);
        resolvedFontFamily = GoogleFonts.getFont(fontFamily).fontFamily;
      } catch (_) {
        fontTheme = baseTextTheme;
      }
    }

    // Apply font scale
    final scaledTheme = scaleTextTheme(fontTheme, fontScale);

    return ThemeData(
      brightness: brightness,
      fontFamily: resolvedFontFamily,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      dividerColor: dividerCol,
      useMaterial3: true,
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: Color(0xFF818CF8),
              secondary: Color(0xFFC7D2FE),
              surface: Color(0xFF151D30),
              background: Color(0xFF0B0F19),
              onSurface: Color(0xFFF8FAFC),
            )
          : const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              secondary: Color(0xFF818CF8),
              surface: Color(0xFFFFFFFF),
              background: Color(0xFFF8FAFC),
              onSurface: Color(0xFF0F172A),
            ),
      textTheme: scaledTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        elevation: 8,
      ),
    );
  }

  static TextTheme scaleTextTheme(TextTheme baseTheme, double scale) {
    if (scale == 1.0) return baseTheme;
    return baseTheme.copyWith(
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: (baseTheme.bodyLarge?.fontSize ?? 15.0) * scale),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: (baseTheme.bodyMedium?.fontSize ?? 13.0) * scale),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: (baseTheme.bodySmall?.fontSize ?? 11.0) * scale),
      titleLarge: baseTheme.titleLarge?.copyWith(fontSize: (baseTheme.titleLarge?.fontSize ?? 20.0) * scale),
      titleMedium: baseTheme.titleMedium?.copyWith(fontSize: (baseTheme.titleMedium?.fontSize ?? 16.0) * scale),
      titleSmall: baseTheme.titleSmall?.copyWith(fontSize: (baseTheme.titleSmall?.fontSize ?? 14.0) * scale),
      labelLarge: baseTheme.labelLarge?.copyWith(fontSize: (baseTheme.labelLarge?.fontSize ?? 14.0) * scale),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: (baseTheme.labelMedium?.fontSize ?? 12.0) * scale),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: (baseTheme.labelSmall?.fontSize ?? 10.0) * scale),
    );
  }

  // Keep compatibility for static references if any, pointing to default system settings
  static final lightTheme = getTheme(isDark: false, fontFamily: 'System', fontScale: 1.0);
  static final darkTheme = getTheme(isDark: true, fontFamily: 'System', fontScale: 1.0);
}

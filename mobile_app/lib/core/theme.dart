import 'package:flutter/material.dart';

class KiwiTheme {
  // Color Palette
  static const Color bgSlate = Color(0xFFE9EDF0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textCharcoal = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color borderSubtle = Color(0xFFE5E7EB);

  // Emerald (Verified State)
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldSoft = Color(0xFFDCFCE7);
  static const Color emeraldDark = Color(0xFF047857);

  // Crimson (Iron Gate / Threat State)
  static const Color crimson = Color(0xFFEF4444);
  static const Color crimsonSoft = Color(0xFFFEE2E2);
  static const Color crimsonDark = Color(0xFFB91C1C);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgSlate,
      colorScheme: const ColorScheme.light(
        surface: bgSlate,
        onSurface: textCharcoal,
        primary: textCharcoal,
        secondary: emerald,
        error: crimson,
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x0A111827), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSlate,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textCharcoal,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textCharcoal),
      ),
    );
  }
}

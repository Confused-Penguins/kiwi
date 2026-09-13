import 'package:flutter/material.dart';

class KiwiTheme {
  // Canvas & Surfaces (Matching exact Tailwind palette #DCE0E5)
  static const Color appBg = Color(0xFFDCE0E5);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color iconBoxBg = Color(0xFFF1F5F9);
  static const Color charcoal = Color(0xFF111827);
  static const Color brandDark = Color(0xFF111827);
  static const Color searchBg = Color(0xFFFFFFFF);

  // Status Colors
  static const Color verifiedMint = Color(0xFF8CE2A8);
  static const Color verifiedDark = Color(0xFF10B981);
  static const Color verifiedBg = Color(0xFFECFDF5);
  static const Color hostileRose = Color(0xFFFECDD3);
  static const Color hostileRed = Color(0xFFEF4444);
  static const Color hostileBg = Color(0xFFFEF2F2);
  static const Color telemetryBlue = Color(0xFF0284C7);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: appBg,
      colorScheme: const ColorScheme.light(
        primary: brandDark,
        secondary: verifiedDark,
        surface: cardBg,
        error: hostileRed,
      ),
      fontFamily: 'Plus Jakarta Sans',
    );
  }
}

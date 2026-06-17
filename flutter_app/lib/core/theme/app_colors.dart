import 'package:flutter/material.dart';

// These are the single source of truth; [AppTheme] maps them into M3
// ColorSchemes. Do not hardcode hex anywhere else... reference these.
class AppColors {
  const AppColors._();

  // Google brand 4-color palette (logo + accents)
  static const Color googleBlue = Color(0xFF1A73E8); // primary / CTAs
  static const Color googleBlueBright = Color(0xFF4285F4); // lighter accent
  static const Color googleRed = Color(0xFFEA4335); // error / destructive
  static const Color googleYellow = Color(0xFFFBBC04);
  static const Color googleGreen = Color(0xFF34A853); // success / connected

  // Advanced LG control tiles (screen 19)
  static const Color tileRelaunch = googleGreen;
  static const Color tileShutdown = googleRed;
  static const Color tileReboot = googleBlueBright;
  static const Color tileSendLogos = googleYellow;
  static const Color tileSetRefresh = Color(0xFFFB8C00); // orange
  static const Color tileClearLogo = Color(0xFFA142F4); // purple
  static const Color tileResetRefresh = Color(0xFF00897B); // teal

  // Neutrals / surfaces (light)
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F4); // chips / input fills
  static const Color outline = Color(0xFFDADCE0);

  // Text (light)
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textTertiary = Color(0xFF80868B);

  // Neutrals / surfaces (dark) : derived to pair with the M3 dark scheme
  static const Color backgroundDark = Color(0xFF121316);
  static const Color surfaceDark = Color(0xFF1E1F22);
  static const Color surfaceVariantDark = Color(0xFF2A2B2E);
  static const Color outlineDark = Color(0xFF44474E);

  // Semantic status
  static const Color connected = googleGreen;
  static const Color disconnected = googleRed;
}

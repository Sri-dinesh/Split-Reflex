import 'package:flutter/material.dart';

/// Split Reflex High-Contrast procedural color palette.
/// Absolutely 0 external image or vector assets.
class SplitPalette {
  // Standard High-Contrast Monochrome
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF222222);
  static const Color lightBg = Color(0xFFF8F8F8);
  static const Color lightSurface = Color(0xFFF1F3F5);

  // Hazard & Accent Colors
  static const Color hazardCrimson = Color(0xFFFF1E42);
  static const Color nearMissCyan = Color(0xFF00F0FF);

  // 1% Hero Overdrive Palette (<10% Battery Unplugged)
  static const Color overdriveDark = Color(0xFF080204);
  static const Color overdriveRed = Color(0xFFFF003C);
  static const Color godModeGold = Color(0xFFFFD700);

  // 1984 Synthwave Neon Palette
  static const Color synthwaveDark = Color(0xFF130924);
  static const Color synthwavePink = Color(0xFFFF2A85);
  static const Color synthwaveCyan = Color(0xFF00F0FF);

  // Matrix Emerald Terminal Palette
  static const Color matrixDark = Color(0xFF021206);
  static const Color matrixGreen = Color(0xFF00FF66);
  static const Color matrixFaint = Color(0xFF0A3314);

  // Cyber-Gold Luxury 24K Palette
  static const Color goldDark = Color(0xFF120F06);
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldAccent = Color(0xFFDAA520);

  // Semantic mappings with Theme support
  static Color getThemeDark({
    required bool isOverdrive,
    required bool isGodMode,
    String themeName = 'monochrome',
  }) {
    if (isGodMode) return const Color(0xFF050002);
    if (isOverdrive) return overdriveDark;
    switch (themeName) {
      case 'synthwave':
        return synthwaveDark;
      case 'matrix':
        return matrixDark;
      case 'cyberGold':
        return goldDark;
      default:
        return darkBg;
    }
  }

  static Color getThemeLight({
    required bool isOverdrive,
    required bool isGodMode,
    String themeName = 'monochrome',
  }) {
    if (isGodMode) return godModeGold;
    if (isOverdrive) return overdriveRed;
    switch (themeName) {
      case 'synthwave':
        return synthwavePink;
      case 'matrix':
        return matrixGreen;
      case 'cyberGold':
        return goldBright;
      default:
        return lightBg;
    }
  }

  static Color getActiveDark(bool isOverdrive, bool isGodMode) {
    if (isGodMode) return const Color(0xFF050002);
    if (isOverdrive) return overdriveDark;
    return darkBg;
  }

  static Color getActiveLight(bool isOverdrive, bool isGodMode) {
    if (isGodMode) return godModeGold;
    if (isOverdrive) return overdriveRed;
    return lightBg;
  }
}

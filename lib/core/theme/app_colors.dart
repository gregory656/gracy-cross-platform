import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Industrial Elite Palette - Onyx, White, Electric Blue
  static const Color onyx = Color(0xFF000000); // Deep Onyx
  static const Color pureWhite = Color(0xFFFFFFFF); // Pure White
  static const Color electricBlue = Color(0xFF007AFF); // Electric Blue
  
  // Industrial Grays
  static const Color industrialGray = Color(0xFF333333);
  static const Color lightGray = Color(0xFF666666);
  static const Color borderGray = Color(0xFFE5E5E5);
  
  // Status Colors
  static const Color sentGray = Color(0xFF8E8E93);
  static const Color deliveredGray = Color(0xFF8E8E93);
  static const Color readCyan = Color(0xFF30D158);
  
  // Accent Colors (minimal use)
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  
  // Legacy support
  static const Color background = onyx;
  static const Color backgroundAlt = onyx;
  static const Color surface = onyx;
  static const Color surfaceElevated = onyx;
  static const Color outline = borderGray;
  static const Color textPrimary = pureWhite;
  static const Color textSecondary = lightGray;
  static const Color accentCyan = electricBlue;
  static const Color accentMagenta = electricBlue;
  static const Color accentBlue = electricBlue;
  static const Color accentAmber = warning;
  static const Color errorRed = error;
}

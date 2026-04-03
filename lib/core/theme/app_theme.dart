import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get classicTheme => _buildTheme(
    background: AppColors.background,
    surface: AppColors.surface,
    primary: AppColors.accentCyan,
  );

  static ThemeData get midnightTheme => _buildTheme(
    background: const Color(0xFF0B0F19),
    surface: const Color(0xFF141B2D),
    primary: const Color(0xFF00E5FF),
  );

  static ThemeData get sunsetTheme => _buildTheme(
    background: const Color(0xFF1C1326),
    surface: const Color(0xFF2A1A36),
    primary: const Color(0xFFFF7B54),
  );

  static ThemeData get forestTheme => _buildTheme(
    background: const Color(0xFF0B1A14),
    surface: const Color(0xFF122A21),
    primary: const Color(0xFF00E676),
  );

  static ThemeData getThemeFromString(String theme) {
    switch (theme.toLowerCase()) {
      case 'sunset':
        return sunsetTheme;
      case 'forest':
        return forestTheme;
      case 'classic':
        return classicTheme;
      case 'midnight':
      default:
        return midnightTheme;
    }
  }

  static ThemeData _buildTheme({
    required Color background,
    required Color surface,
    required Color primary,
  }) {
    final ThemeData base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: AppColors.accentBlue,
        surface: surface,
        onSurface: AppColors.textPrimary,
        error: const Color(0xFFFF6B6B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: 0.86),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primary),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface.withValues(alpha: 0.75),
        selectedColor: primary.withValues(alpha: 0.18),
        side: const BorderSide(color: AppColors.outline),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: AppColors.outline),
        ),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get darkTheme {
    final ThemeData base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentCyan,
        secondary: AppColors.accentBlue,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: Color(0xFFFF6B6B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ).copyWith(
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
        fillColor: AppColors.surface.withValues(alpha: 0.65),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.accentCyan),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface.withValues(alpha: 0.75),
        selectedColor: AppColors.accentCyan.withValues(alpha: 0.18),
        side: const BorderSide(color: AppColors.outline),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: AppColors.outline),
        ),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentCyan,
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


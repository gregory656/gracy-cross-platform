import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static bool isLightThemeName(String themeName) {
    final String normalized = themeName.toLowerCase();
    return normalized == 'light' || normalized == 'classic';
  }

  static List<BoxShadow> get glassmorphismShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        )
      ];

  static Border get glassBorder => Border.all(
        color: AppColors.borderGray.withValues(alpha: 0.1),
        width: 1,
      );

  static ThemeData resolveTheme(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'light':
        return eliteLightTheme();
      case 'classic':
        return classicTheme();
      case 'sunset':
        return sunsetTheme();
      case 'forest':
        return forestTheme();
      case 'midnight':
      case 'dark':
      default:
        return eliteTheme();
    }
  }

  // Industrial Elite Theme - Dark mode
  static ThemeData eliteTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.onyx,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricBlue,
        secondary: AppColors.electricBlue,
        surface: AppColors.onyx,
        onSurface: AppColors.pureWhite,
        onSurfaceVariant: AppColors.lightGray,
        error: AppColors.error,
        onError: AppColors.pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.onyx,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.onyx,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Max 4px radius for industrial look
          side: const BorderSide(
            color: AppColors.borderGray,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: AppColors.pureWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          side: const BorderSide(color: AppColors.electricBlue, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.onyx,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderGray,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue;
          }
          return AppColors.lightGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue.withValues(alpha: 0.3);
          }
          return AppColors.industrialGray;
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: AppColors.pureWhite,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.pureWhite,
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.electricBlue,
        textColor: AppColors.pureWhite,
      ),
    );
  }

  // Industrial Elite Theme - Light mode
  static ThemeData eliteLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pureWhite,
      colorScheme: const ColorScheme.light(
        primary: AppColors.electricBlue,
        secondary: AppColors.electricBlue,
        surface: AppColors.pureWhite,
        onSurface: AppColors.onyx,
        onSurfaceVariant: AppColors.industrialGray,
        error: AppColors.error,
        onError: AppColors.pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.onyx,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.onyx,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Max 4px radius for industrial look
          side: const BorderSide(
            color: AppColors.borderGray,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: AppColors.pureWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          side: const BorderSide(color: AppColors.electricBlue, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pureWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderGray,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue;
          }
          return AppColors.lightGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue.withValues(alpha: 0.3);
          }
          return AppColors.industrialGray;
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.onyx,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          color: AppColors.onyx,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          color: AppColors.onyx,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          color: AppColors.onyx,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: AppColors.onyx,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.onyx,
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.electricBlue,
        textColor: AppColors.onyx,
      ),
    );
  }

  // Legacy support - map to elite themes
  static ThemeData sunsetTheme() {
    return eliteTheme().copyWith(
      colorScheme: eliteTheme().colorScheme.copyWith(
        primary: const Color(0xFFFF7B54),
        secondary: const Color(0xFFFFB26B),
        onSurfaceVariant: const Color(0xFFB9A7A1),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFFF7B54),
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFFF7B54),
        textColor: AppColors.pureWhite,
      ),
    );
  }

  static ThemeData forestTheme() {
    return eliteTheme().copyWith(
      colorScheme: eliteTheme().colorScheme.copyWith(
        primary: const Color(0xFF00E676),
        secondary: const Color(0xFF69F0AE),
        onSurfaceVariant: const Color(0xFF97B5A4),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF00E676),
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF00E676),
        textColor: AppColors.pureWhite,
      ),
    );
  }

  static ThemeData classicTheme() {
    return eliteLightTheme().copyWith(
      colorScheme: eliteLightTheme().colorScheme.copyWith(
        primary: const Color(0xFF5DE4C7),
        secondary: const Color(0xFF0F8B8D),
        onSurfaceVariant: const Color(0xFF4D5B68),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF0F8B8D),
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF0F8B8D),
        textColor: AppColors.onyx,
      ),
    );
  }

  static ThemeData darkTheme() => eliteTheme();
  static ThemeData lightTheme() => eliteLightTheme();
}

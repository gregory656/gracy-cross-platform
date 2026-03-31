import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  const AppGradients._();

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.background,
      AppColors.backgroundAlt,
      Color(0xFF091725),
    ],
  );

  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1FFFFFFF),
      Color(0x0DFFFFFF),
    ],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.accentCyan,
      AppColors.accentBlue,
    ],
  );
}


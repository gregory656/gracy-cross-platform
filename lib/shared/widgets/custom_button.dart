import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: filled ? AppGradients.accent : null,
            color: filled ? null : AppColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: filled ? Colors.transparent : AppColors.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    color: filled ? AppColors.background : AppColors.textPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? AppColors.background : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!fullWidth) {
      return content;
    }

    return SizedBox(width: double.infinity, child: content);
  }
}


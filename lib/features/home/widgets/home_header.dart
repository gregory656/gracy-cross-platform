import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/theme_toggle.dart';
import 'notification_bell.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.user,
    this.action,
  });

  final UserModel user;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  final bool isLight =
                      Theme.of(context).brightness == Brightness.light;
                  return LinearGradient(
                    colors: isLight
                        ? <Color>[
                            const Color(0xFF0F1720),
                            const Color(0xFF0F8B8D),
                          ]
                        : <Color>[
                            Colors.white,
                            AppColors.electricBlue,
                          ],
                  ).createShader(bounds);
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'GRACY',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                      color: Colors.white,
                      shadows: <Shadow>[
                        Shadow(
                          color: AppColors.electricBlue.withValues(alpha: 0.20),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const ThemeToggle(),
            const Spacer(),
            if (action != null) ...<Widget>[
              action!,
              const SizedBox(width: 10),
            ],
            const NotificationBell(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'A private academic network for students and alumni.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

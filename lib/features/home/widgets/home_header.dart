import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  Text(
                    'GRACY',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const ThemeToggle(),
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
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                if (action != null) ...[
                  action!,
                  const SizedBox(width: 12),
                ],
                const NotificationBell(),
                const SizedBox(width: 12),
                UserAvatar(user: user, size: 48, fontSize: 16, showRing: true),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              user.isOnline ? 'Online now' : 'Away',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: user.isOnline
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

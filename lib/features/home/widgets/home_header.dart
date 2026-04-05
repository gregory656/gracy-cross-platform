import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/theme_toggle.dart';
import '../../../shared/widgets/user_avatar.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'GRACY',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
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
        );

        final actionsBlock = Column(
          crossAxisAlignment:
              isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
                color:
                    user.isOnline ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              titleBlock,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: actionsBlock,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actionsBlock,
          ],
        );
      },
    );
  }
}

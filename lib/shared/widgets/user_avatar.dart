import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/avatar_palette.dart';
import '../models/user_model.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    required this.size,
    this.showOnlineIndicator = true,
    this.showRing = true,
    this.fontSize,
  });

  final UserModel user;
  final double size;
  final bool showOnlineIndicator;
  final bool showRing;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final AvatarPalette palette = SeededAvatarPalette.paletteFor(user.avatarSeed);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[palette.start, palette.end],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.start.withValues(alpha: 0.24),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: size * 0.15,
                top: size * 0.18,
                child: _Orb(color: palette.accent.withValues(alpha: 0.22), diameter: size * 0.28),
              ),
              Positioned(
                right: size * 0.10,
                bottom: size * 0.16,
                child: _Orb(color: Colors.white.withValues(alpha: 0.18), diameter: size * 0.18),
              ),
              Center(
                child: Text(
                  user.initials,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: AppColors.background,
                        letterSpacing: 1.1,
                      ),
                ),
              ),
            ],
          ),
        ),
        if (showRing)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.2,
                ),
              ),
            ),
          ),
        if (showOnlineIndicator)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: user.isOnline ? AppColors.success : AppColors.warning,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.color,
    required this.diameter,
  });

  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

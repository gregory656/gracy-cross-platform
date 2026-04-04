import 'package:flutter/material.dart';

class BlueVerifiedBadge extends StatelessWidget {
  const BlueVerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1DA1F2), // Twitter blue
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}

class AlumniBadge extends StatelessWidget {
  const AlumniBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.school,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}

class UserBadges extends StatelessWidget {
  const UserBadges({
    super.key,
    this.isBlueVerified = false,
    this.isAlumni = false,
    this.spacing = 4.0,
    this.badgeSize = 16.0,
  });

  final bool isBlueVerified;
  final bool isAlumni;
  final double spacing;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    if (!isBlueVerified && !isAlumni) {
      return const SizedBox.shrink();
    }

    final List<Widget> badges = [];
    if (isBlueVerified) {
      badges.add(const BlueVerifiedBadge());
    }
    if (isAlumni) {
      badges.add(const AlumniBadge());
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges
          .map((badge) => Padding(
                padding: EdgeInsets.only(right: spacing),
                child: badge,
              ))
          .toList(),
    );
  }
}

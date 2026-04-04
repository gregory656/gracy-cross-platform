import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../../core/theme/app_colors.dart';

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    super.key,
    required this.verificationLevel,
    this.size = 16,
  });

  final VerificationLevel verificationLevel;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (verificationLevel) {
      case VerificationLevel.blueVerified:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.electricBlue,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.pureWhite,
              width: 1,
            ),
          ),
          child: Icon(
            Icons.check,
            color: AppColors.pureWhite,
            size: size * 0.6,
          ),
        );
      case VerificationLevel.none:
        return const SizedBox.shrink();
    }
  }
}

class UserVerificationRow extends StatelessWidget {
  const UserVerificationRow({
    super.key,
    required this.user,
    this.showRole = true,
  });

  final UserModel user;
  final bool showRole;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.isBlueVerified) ...[
          VerificationBadge(verificationLevel: user.verificationLevel),
          const SizedBox(width: 4),
        ],
        if (showRole && user.isAlumni) ...[
          Icon(
            Icons.school,
            size: 16,
            color: AppColors.electricBlue,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          user.fullName,
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

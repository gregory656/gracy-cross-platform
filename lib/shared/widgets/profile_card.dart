import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verification_badges.dart';

class ProfileCard extends ConsumerWidget {
  const ProfileCard({
    super.key,
    required this.user,
    required this.onTap,
    required this.onPrimaryAction,
  });

  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? myId = ref.watch(authNotifierProvider).userId;

    String ctaLabel = 'Connect';
    bool isDisabled = false;
    VoidCallback? action = onPrimaryAction;

    // Simplified connection logic - always show connect button
    ctaLabel = 'Connect';
    action = () async {
      // Connection request functionality would go here
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection request sent to ${user.fullName}'),
            backgroundColor: AppColors.accentBlue,
          ),
        );
      }
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  UserAvatar(user: user, size: 74, fontSize: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.fullName,
                                      style: Theme.of(context).textTheme.titleLarge
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  UserBadges(
                                    isBlueVerified: user.isBlueVerified,
                                    isAlumni: user.isAlumni,
                                  ),
                                ],
                              ),
                            ),
                            _StatusPill(
                              label: user.isOnline ? 'Online' : 'Offline',
                              online: user.isOnline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (user.age > 0) _InfoChip(label: '${user.age} yrs'),
                            _InfoChip(label: user.role.label),
                            _InfoChip(label: user.year),
                            if (user.gracyId != null)
                              _InfoChip(label: user.gracyId!),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                user.bio,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.courses
                    .take(3)
                    .map((String course) => _InfoChip(label: course))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (myId != user.id) ...[
                    Expanded(
                      child: _CardAction(
                        label: ctaLabel,
                        onTap: action,
                        filled: !isDisabled,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _CardAction(
                      label: 'Profile',
                      onTap: onTap,
                      filled: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.online});

  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (online ? AppColors.success : AppColors.warning).withValues(
          alpha: 0.16,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: online ? AppColors.success : AppColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.grey,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: filled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled 
                  ? Colors.transparent 
                  : Theme.of(context).dividerTheme.color ?? Colors.grey,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: filled 
                  ? const Color(0xFFFFFFFF)
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

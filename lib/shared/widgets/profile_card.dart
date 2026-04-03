import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/social_providers.dart';
import 'glass_card.dart';
import 'user_avatar.dart';

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
    final String? connectionStatus = ref.watch(
      connectionStatusProvider(user.id),
    );

    String ctaLabel = 'Connect';
    bool isDisabled = false;
    VoidCallback? action = onPrimaryAction;

    if (connectionStatus == 'connected') {
      ctaLabel = 'Connected ✅';
    } else if (connectionStatus == 'pending') {
      ctaLabel = 'Pending...';
      isDisabled = true;
      action = null;
    } else {
      ctaLabel = 'Connect';
      action = () async {
        await ref.read(socialServiceProvider).sendConnectionRequest(user.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection request sent to ${user.fullName}'),
              backgroundColor: AppColors.accentBlue,
            ),
          );
        }
      };
    }

    // fallback for the original UserRole check if it's alumni and no connection info
    if (connectionStatus == null && user.role == UserRole.alumni) {
      ctaLabel = 'Connect';
    }

    return GlassCard(
      onTap: onTap,
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
                          child: Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
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
                    onTap: action ?? () {},
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
        color: AppColors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: filled
                ? AppColors.accentCyan
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled ? Colors.transparent : AppColors.outline,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: filled ? AppColors.background : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

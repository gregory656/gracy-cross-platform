import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/user_avatar.dart';

class ProfileQuickActionsPanel extends StatelessWidget {
  const ProfileQuickActionsPanel({
    super.key,
    required this.user,
    required this.onChat,
    required this.onConnect,
    required this.onShare,
    required this.onSave,
    required this.onReport,
  });

  final UserModel user;
  final VoidCallback onChat;
  final VoidCallback onConnect;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              _MiniStatus(label: user.isOnline ? 'Online' : 'Offline', online: user.isOnline),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Start a conversation or manage this profile without leaving the page.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.chat_rounded,
            label: 'Message',
            description: 'Open the current chat thread',
            onTap: onChat,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.link_rounded,
            label: 'Connect',
            description: 'Send a connection request',
            onTap: onConnect,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.share_rounded,
            label: 'Share profile',
            description: 'Copy a link or share card',
            onTap: onShare,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.bookmark_add_rounded,
            label: 'Save contact',
            description: 'Keep this profile in your contacts',
            onTap: onSave,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.flag_outlined,
            label: 'Report',
            description: 'Flag inappropriate content',
            onTap: onReport,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class ProfileQuickActionsSheet extends StatelessWidget {
  const ProfileQuickActionsSheet({
    super.key,
    required this.user,
    required this.onChat,
    required this.onConnect,
    required this.onShare,
    required this.onSave,
    required this.onReport,
  });

  final UserModel user;
  final VoidCallback onChat;
  final VoidCallback onConnect;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  UserAvatar(user: user, size: 52, fontSize: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ActionTile(
                icon: Icons.chat_rounded,
                label: 'Message',
                description: 'Open the current chat thread',
                onTap: onChat,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.link_rounded,
                label: 'Connect',
                description: 'Send a connection request',
                onTap: onConnect,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.share_rounded,
                label: 'Share profile',
                description: 'Copy a link or share card',
                onTap: onShare,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.bookmark_add_rounded,
                label: 'Save contact',
                description: 'Keep this profile in your contacts',
                onTap: onSave,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.flag_outlined,
                label: 'Report',
                description: 'Flag inappropriate content',
                onTap: onReport,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color foreground = danger ? const Color(0xFFFF8585) : AppColors.textPrimary;
    final Color background = danger
        ? const Color(0x33FF8585)
        : AppColors.surface.withValues(alpha: 0.62);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: foreground, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label, required this.online});

  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (online ? AppColors.success : AppColors.warning).withValues(alpha: 0.16),
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

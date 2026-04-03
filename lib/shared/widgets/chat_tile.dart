import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'glass_card.dart';
import 'user_avatar.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.user,
    required this.onTap,
  });

  final ChatModel chat;
  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.surface.withValues(alpha: 0.92),
          const Color(0xFF10203A).withValues(alpha: 0.9),
        ],
      ),
      child: Row(
        children: <Widget>[
          UserAvatar(user: user, size: 56, fontSize: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              user.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (chat.isOfficial) ...<Widget>[
                            const SizedBox(width: 8),
                            const _VerifiedPill(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormatters.chatPreviewTime.format(chat.lastMessageAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (chat.gracyId != null && chat.gracyId!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _CodePill(code: chat.gracyId!),
                ],
              ],
            ),
          ),
          if (chat.unreadCount > 0) ...<Widget>[
            const SizedBox(width: 12),
            _UnreadBadge(count: chat.unreadCount),
          ],
        ],
      ),
    );
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Verified',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentAmber,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.accentBlue,
            AppColors.accentCyan,
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.background,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

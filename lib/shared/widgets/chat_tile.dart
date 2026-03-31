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
      padding: const EdgeInsets.all(14),
      borderRadius: 22,
      child: Row(
        children: <Widget>[
          UserAvatar(user: user, size: 54, fontSize: 16),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Text(
                      DateFormatters.chatPreviewTime.format(chat.lastMessageAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.accentCyan,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_model.dart';
import '../models/user_model.dart';

class ChatTile extends ConsumerWidget {
  final String chatId;
  final UserModel participant;
  final String lastMessage;
  final int unreadCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  ChatTile({
    super.key,
    ChatModel? chat,
    UserModel? user,
    String? chatId,
    UserModel? participant,
    String? lastMessage,
    int? unreadCount,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  }) : chatId = chatId ?? chat?.id ?? '',
       participant = participant ?? user ?? UserModel(id: '', fullName: 'Unknown User', username: '@unknown'),
       lastMessage = lastMessage ?? chat?.lastMessage ?? '',
       unreadCount = unreadCount ?? chat?.unreadCount ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: participant.avatarUrl != null ? NetworkImage(participant.avatarUrl!) : null,
              child: participant.avatarUrl == null ? Text(participant.initials) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    lastMessage,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

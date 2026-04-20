import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/providers/social_providers.dart';
import '../../../shared/widgets/user_avatar.dart';

class NotificationsOverlay extends ConsumerWidget {
  const NotificationsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('No notifications')),
              data: (notifications) => _NotificationsBody(
                unreadNotifications: notifications.take(10).toList(),
                unreadChats: <ChatModel>[],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.unreadNotifications,
    required this.unreadChats,
  });

  final List<NotificationModel> unreadNotifications;
  final List<ChatModel> unreadChats;

  @override
  Widget build(BuildContext context) {
    if (unreadNotifications.isEmpty && unreadChats.isEmpty) {
      return const Center(
        child: Text(
          'No new notifications.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (unreadChats.isNotEmpty) ...<Widget>[
          const _SectionTitle(title: 'Unread messages'),
          const SizedBox(height: 12),
          for (final ChatModel chat in unreadChats) _UnreadChatTile(chat: chat),
          const SizedBox(height: 16),
        ],
        if (unreadNotifications.isNotEmpty) ...<Widget>[
          const _SectionTitle(title: 'Requests'),
          const SizedBox(height: 12),
          for (final NotificationModel notif in unreadNotifications)
            _NotificationTile(notif: notif),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _UnreadChatTile extends ConsumerWidget {
  const _UnreadChatTile({required this.chat});

  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantAsync = ref.watch(profileByIdProvider(chat.participantId));

    return participantAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (participant) {
        if (participant == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: ListTile(
            onTap: () {
              ref.read(localReadChatsProvider.notifier).markRead(chat.id);
              Navigator.of(context).pop();
              context.push(
                AppRoutePaths.chatByRoom(
                  chatId: chat.id,
                  userId: participant.id,
                  receiverName: participant.fullName,
                  receiverAvatar: participant.avatarUrl,
                ),
              );
            },
            leading: UserAvatar(user: participant, size: 42),
            title: Text(
              participant.fullName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentCyan,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                style: const TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notif});

  final NotificationModel notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderAsync = ref.watch(profileByIdProvider(notif.senderId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notif.isRead
            ? AppColors.surface.withValues(alpha: 0.4)
            : AppColors.accentCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notif.isRead
              ? AppColors.outline
              : AppColors.accentCyan.withValues(alpha: 0.3),
        ),
      ),
      child: senderAsync.when(
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Text('Error loading sender info'),
        data: (sender) {
          if (sender == null) {
            return const SizedBox.shrink();
          }
          final bool isConnectionRequest = notif.type == 'connection_request';
          final String message = isConnectionRequest
              ? 'wants to connect with you!'
              : (notif.content?.trim().isNotEmpty ?? false)
                  ? notif.content!.trim()
                  : 'sent you a new message.';

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isConnectionRequest
                ? null
                : () async {
                    ref
                        .read(locallyReadNotificationIdsProvider.notifier)
                        .markRead(notif.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      context.push(
                        AppRoutePaths.chatByUser(
                          userId: notif.senderId,
                          receiverName: sender.fullName,
                          receiverAvatar: sender.avatarUrl,
                        ),
                      );
                    }
                    await ref
                        .read(socialServiceProvider)
                        .markNotificationAsRead(notif.id);
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(user: sender, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: sender.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: ' $message'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isConnectionRequest && !notif.isRead) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(socialServiceProvider)
                                .declineConnection(notif);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          onPressed: () async {
                            await ref
                                .read(socialServiceProvider)
                                .acceptConnection(notif);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'You are now connected with ${sender.fullName}!',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Accept',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

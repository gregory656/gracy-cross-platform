import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/shell_ui_provider.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/widgets/chat_tile.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/disappearing_messages_dialog.dart';
import '../../../shared/widgets/report_reason_sheet.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../widgets/industrial_chat_composer.dart';
import '../widgets/industrial_message_bubble.dart';
import '../widgets/date_header.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.chatId, this.userId});

  final String? chatId;
  final String? userId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _botTypingTimer;
  bool _isBotTyping = false;
  int _lastMessageCount = 0;
  String? _replyToMessage;
  Timer? _readReceiptTimer;
  Timer? _deliveryReceiptTimer;
  String? _lastDeliverySignature;
  String? _lastReadSignature;

  void _syncShellNavigation(bool showThread) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final notifier = ref.read(shellNavigationVisibleProvider.notifier);
      if (showThread) {
        notifier.hide();
      } else {
        notifier.show();
      }
    });
  }

  @override
  void dispose() {
    _botTypingTimer?.cancel();
    _readReceiptTimer?.cancel();
    _deliveryReceiptTimer?.cancel();
    _composerController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    ref.read(shellNavigationVisibleProvider.notifier).show();
    super.dispose();
  }

  Future<void> _startChatByCode() async {
    final String code = _searchController.text.trim();
    if (code.isEmpty) {
      _showFeedback('Paste a Gracy code to start a chat.');
      return;
    }

    try {
      final ChatThread thread = await ref
          .read(startChatControllerProvider.notifier)
          .startByCode(code);
      if (!mounted) {
        return;
      }
      _searchController.clear();
      context.go('${AppRoutePaths.chat}?chatId=${thread.roomId}');
    } catch (error) {
      _showFeedback(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sendMessage(ChatThread thread) async {
    final String? currentUserId = ref.read(authNotifierProvider).userId;
    final String content = _composerController.text.trim();
    if (currentUserId == null || content.isEmpty) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            roomId: thread.roomId,
            senderId: currentUserId,
            content: content,
          );
      _composerController.clear();
      _replyToMessage = null;
      ref.invalidate(recentChatsProvider);

      if (thread.participant.id == ChatRepository.botUserId) {
        _triggerFakeTyping();
      }
    } catch (error) {
      _showFeedback('Message failed: $error');
    }
  }

  void _markMessagesAsRead(ChatThread thread) {
    _readReceiptTimer?.cancel();
    _readReceiptTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await ref
            .read(chatRepositoryProvider)
            .markMessagesAsRead(
              roomId: thread.roomId,
              userId: thread.participant.id,
            );
      } catch (error) {
        // Silently fail for read receipts
      }
    });
  }

  void _markMessagesAsDelivered(ChatThread thread) {
    _deliveryReceiptTimer?.cancel();
    _deliveryReceiptTimer = Timer(const Duration(milliseconds: 120), () async {
      try {
        await ref
            .read(chatRepositoryProvider)
            .markMessagesAsDelivered(
              roomId: thread.roomId,
              userId: thread.participant.id,
            );
      } catch (_) {
        // Silently fail for delivery receipts.
      }
    });
  }

  void _syncReceiptState(ChatThread thread, List<MessageModel> messages) {
    final Iterable<MessageModel> incomingMessages = messages.where(
      (MessageModel message) => !message.isMe,
    );
    final int sentIncomingCount = incomingMessages
        .where((MessageModel message) => message.status == MessageStatus.sent)
        .length;
    final int unreadIncomingCount = incomingMessages
        .where((MessageModel message) => message.status != MessageStatus.read)
        .length;

    final String deliverySignature = '${thread.roomId}:$sentIncomingCount';
    if (sentIncomingCount > 0 && deliverySignature != _lastDeliverySignature) {
      _lastDeliverySignature = deliverySignature;
      _markMessagesAsDelivered(thread);
    } else if (sentIncomingCount == 0) {
      _lastDeliverySignature = deliverySignature;
    }

    final String readSignature = '${thread.roomId}:$unreadIncomingCount';
    if (unreadIncomingCount > 0 && readSignature != _lastReadSignature) {
      _lastReadSignature = readSignature;
      _markMessagesAsRead(thread);
    } else if (unreadIncomingCount == 0) {
      _lastReadSignature = readSignature;
    }
  }

  void _handleReply(MessageModel message) {
    setState(() {
      _replyToMessage = message.text;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _handleForward(MessageModel message) {
    _showFeedback('Forward feature coming soon');
  }

  void _handleDelete(MessageModel message) {
    _showFeedback('Delete feature coming soon');
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _triggerFakeTyping() {
    _botTypingTimer?.cancel();
    setState(() {
      _isBotTyping = true;
    });

    _botTypingTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBotTyping = false;
      });
    });
  }

  void _maybeScrollToBottom(int messageCount) {
    if (_lastMessageCount == messageCount && !_isBotTyping) {
      return;
    }
    _lastMessageCount = messageCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showFeedback(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authNotifierProvider);
    final String? currentUserId = authState.userId;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ChatThreadRequest request = ChatThreadRequest(
      roomId: widget.chatId,
      userId: widget.userId,
    );
    final bool showThread = request.roomId != null || request.userId != null;
    _syncShellNavigation(showThread);
    final AsyncValue<List<ChatModel>> recentChatsAsync = ref.watch(
      recentChatsProvider,
    );

    if (!showThread) {
      return Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: _ChatShell(
          currentUserName: authState.fullName ?? 'Gracy User',
          currentUserCode: authState.gracyId,
          recentChatsAsync: recentChatsAsync,
          startChatController: _searchController,
          onStartChat: _startChatByCode,
        ),
      );
    }

    final AsyncValue<ChatThread?> threadAsync = ref.watch(
      chatThreadProvider(request),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showSidebar = constraints.maxWidth >= 980;

          return SafeArea(
            child: Row(
              children: <Widget>[
                if (showSidebar)
                  SizedBox(
                    width: 390,
                    child: _ChatShell(
                      currentUserName: authState.fullName ?? 'Gracy User',
                      currentUserCode: authState.gracyId,
                      recentChatsAsync: recentChatsAsync,
                      startChatController: _searchController,
                      onStartChat: _startChatByCode,
                      dense: true,
                    ),
                  ),
                Expanded(
                  child: threadAsync.when(
                    data: (ChatThread? thread) {
                      if (thread == null) {
                        return const _CenteredMessage(
                          title: 'Chat unavailable',
                          subtitle:
                              'The selected conversation could not be loaded.',
                        );
                      }

                      final AsyncValue<List<MessageModel>> messagesAsync = ref
                          .watch(messagesProvider(thread.roomId));

                      return messagesAsync.when(
                        data: (List<MessageModel> messages) {
                          _syncReceiptState(thread, messages);
                          _maybeScrollToBottom(
                            messages.length + (_isBotTyping ? 1 : 0),
                          );
                          return _ThreadView(
                            thread: thread,
                            messages: messages,
                            composerController: _composerController,
                            scrollController: _scrollController,
                            isBotTyping:
                                _isBotTyping &&
                                thread.participant.id ==
                                    ChatRepository.botUserId,
                            replyToMessage: _replyToMessage,
                            onBack: showSidebar
                                ? null
                                : () {
                                    context.go(AppRoutePaths.chat);
                                  },
                            onSend: () => _sendMessage(thread),
                            onReply: _handleReply,
                            onForward: _handleForward,
                            onDelete: _handleDelete,
                            onCancelReply: _cancelReply,
                            onViewProfile: () {
                              context.go(
                                '${AppRoutePaths.profile}?userId=${thread.participant.id}',
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (Object error, StackTrace stackTrace) {
                          return _CenteredMessage(
                            title: 'Messages failed to load',
                            subtitle: error.toString(),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object error, StackTrace stackTrace) {
                      return _CenteredMessage(
                        title: 'Chat unavailable',
                        subtitle: error.toString(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChatShell extends ConsumerWidget {
  const _ChatShell({
    required this.currentUserName,
    required this.currentUserCode,
    required this.recentChatsAsync,
    required this.startChatController,
    required this.onStartChat,
    this.dense = false,
  });

  final String currentUserName;
  final String? currentUserCode;
  final AsyncValue<List<ChatModel>> recentChatsAsync;
  final TextEditingController startChatController;
  final VoidCallback onStartChat;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isStarting = ref.watch(startChatControllerProvider).isLoading;
    final AsyncValue<List<UserModel>> profilesAsync = ref.watch(
      profilesDirectoryProvider,
    );
    final List<UserModel> profiles =
        profilesAsync.asData?.value ?? const <UserModel>[];
    final Map<String, UserModel> profilesById = <String, UserModel>{
      for (final UserModel profile in profiles) profile.id: profile,
    };

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(dense ? 18 : AppConstants.pagePadding),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Recent chats',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Live',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF14171C),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: CustomTextField(
                      controller: startChatController,
                      hintText:
                          currentUserCode == null
                          ? 'Enter a Gracy code'
                          : 'Invite with a Gracy code',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isStarting ? null : onStartChat,
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF00C2FF),
                              Color(0xFF007AFF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isStarting
                              ? Icons.hourglass_top_rounded
                              : Icons.add_rounded,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentUserCode == null
                  ? currentUserName
                  : '$currentUserName • $currentUserCode',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 14),
            recentChatsAsync.when(
              data: (List<ChatModel> chats) {
                if (chats.isEmpty) {
                  return const _CenteredMessage(
                    title: 'No chats yet',
                    subtitle:
                        'Use a Gracy code above to create the first room.',
                  );
                }

                return Column(
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < chats.length;
                      index++
                    ) ...<Widget>[
                      Builder(
                        builder: (BuildContext context) {
                          final ChatModel chat = chats[index];
                          final UserModel? user =
                              profilesById[chat.participantId];
                          if (user == null) {
                            return const SizedBox.shrink();
                          }

                          return ChatTile(
                            chat: chat,
                            user: user,
                            onTap: () {
                              context.go(
                                '${AppRoutePaths.chat}?chatId=${chat.id}',
                              );
                            },
                          );
                        },
                      ),
                      if (index != chats.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.8,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace stackTrace) {
                return _CenteredMessage(
                  title: 'Recent chats failed to load',
                  subtitle: error.toString(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({
    required this.thread,
    required this.messages,
    required this.composerController,
    required this.scrollController,
    required this.isBotTyping,
    required this.onSend,
    required this.onViewProfile,
    required this.onReply,
    required this.onForward,
    required this.onDelete,
    required this.onCancelReply,
    this.replyToMessage,
    this.onBack,
  });

  final ChatThread thread;
  final List<MessageModel> messages;
  final TextEditingController composerController;
  final ScrollController scrollController;
  final bool isBotTyping;
  final VoidCallback onSend;
  final VoidCallback onViewProfile;
  final Function(MessageModel) onReply;
  final Function(MessageModel) onForward;
  final Function(MessageModel) onDelete;
  final VoidCallback onCancelReply;
  final String? replyToMessage;
  final VoidCallback? onBack;

  List<Widget> _buildMessageGroup() {
    if (messages.isEmpty) return [];

    final List<Widget> widgets = [];
    DateTime? lastDate;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final messageDate = DateTime(
        message.sentAt.year,
        message.sentAt.month,
        message.sentAt.day,
      );

      // Add date header if date changed
      if (lastDate == null || messageDate.isAfter(lastDate)) {
        widgets.add(DateHeader(date: message.sentAt));
        lastDate = messageDate;
      }

      // Add message bubble
      widgets.add(
        IndustrialMessageBubble(
          message: message,
          onReply: () => onReply(message),
          onForward: () => onForward(message),
          onDelete: () => onDelete(message),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: <Widget>[
          _ThreadHeader(
            participant: thread.participant,
            onBack: onBack,
            onViewProfile: onViewProfile,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF090B0F).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(painter: _ChatWallpaperPainter()),
                        ),
                        ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                          children: <Widget>[
                            ..._buildMessageGroup(),
                            if (isBotTyping)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _TypingIndicator(
                                  name: thread.participant.fullName,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom
                          : MediaQuery.of(context).viewPadding.bottom,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    child: IndustrialChatComposer(
                      controller: composerController,
                      onSend: onSend,
                      replyToMessage: replyToMessage,
                      onCancelReply: onCancelReply,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.participant,
    required this.onViewProfile,
    this.onBack,
  });

  final UserModel participant;
  final VoidCallback onViewProfile;
  final VoidCallback? onBack;

  Future<void> _showThreadMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: const Color(0xFF14181D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  _ThreadActionTile(
                    icon: Icons.account_circle_outlined,
                    label: 'View Profile',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onViewProfile();
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF2A2E34)),
                  _ThreadActionTile(
                    icon: Icons.search_rounded,
                    label: 'Search Conversation',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conversation search is queued next.'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF2A2E34)),
                  _ThreadActionTile(
                    icon: Icons.notifications_off_outlined,
                    label: 'Mute Notifications',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Notifications muted for ${participant.fullName}.',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF2A2E34)),
                  _ThreadActionTile(
                    icon: Icons.outlined_flag_rounded,
                    label: 'Block / Report',
                    color: const Color(0xFFFF5C5C),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final String? reason = await showReportReasonSheet(
                        context,
                        title: 'Report Profile',
                        subtitle:
                            'Choose what feels wrong so we can review this profile.',
                      );
                      if (reason != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Reported ${participant.fullName} for "$reason".',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOfficial = participant.id == ChatRepository.botUserId;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D10),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: onViewProfile,
            child: UserAvatar(
              user: participant,
              size: 38,
              fontSize: 14,
              showRing: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        participant.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                    ),
                    if (isOfficial) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.cyan,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Official',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onViewProfile,
                  child: Text(
                    isOfficial ? 'Gracy Assistant' : 'Tap to view profile',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showThreadMenu(context),
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
          ),
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => const DisappearingMessagesDialog(),
                  );
                },
                icon: const Icon(Icons.timer_outlined),
                color: Colors.grey.shade500,
                tooltip: 'Disappearing Messages',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThreadActionTile extends StatelessWidget {
  const _ThreadActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        UserAvatar(
          user: const UserModel(
            id: 'bot',
            fullName: 'Gracy Bot',
            username: 'bot',
            age: 25,
            role: UserRole.staff,
            courses: [],
            bio: 'AI Assistant',
            isOnline: true,
            location: 'Virtual',
            avatarSeed: 'bot',
            year: '2024',
          ),
          size: 32,
          fontSize: 12,
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF171B20),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$name is typing',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.028)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Paint bubblePaint = Paint()
      ..color = const Color(0xFF007AFF).withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    const double step = 92;
    for (double x = -20; x < size.width + step; x += step) {
      for (double y = -10; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x + 18, y + 18), 10, bubblePaint);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(x + 54, y + 56), radius: 13),
          0.5,
          4.6,
          false,
          linePaint,
        );
        canvas.drawLine(
          Offset(x + 8, y + 68),
          Offset(x + 30, y + 46),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

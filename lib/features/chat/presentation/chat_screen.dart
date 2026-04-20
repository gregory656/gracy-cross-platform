import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/shell_ui_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/local_first_data.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/chat_providers.dart';
import '../../../shared/providers/auth_provider.dart'
    show AuthState, authNotifierProvider;
import '../../../shared/providers/offline_banner_provider.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/widgets/disappearing_messages_dialog.dart';
import '../../../shared/widgets/report_reason_sheet.dart';
import '../../../shared/widgets/top_overlay_sheet.dart';
import '../../../shared/widgets/chat_tile.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/services/gemini_service.dart';
import '../../../shared/enums/user_role.dart';
import '../data/chat_repository.dart';
import '../providers/elite_chat_providers.dart';
import '../../../shared/models/chat_thread.dart';
import '../widgets/industrial_chat_composer.dart';
import '../widgets/industrial_message_bubble.dart';
import '../widgets/date_header.dart';
import '../widgets/neural_background.dart';
import '../widgets/glassmorphism_bubble.dart';
import '../widgets/neural_thinking_indicator.dart';
import '../widgets/gracy_ai_logo.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.chatId,
    this.userId,
    this.receiverName,
    this.receiverAvatar,
  });

  final String? chatId;
  final String? userId;
  final String? receiverName;
  final String? receiverAvatar;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _botTypingTimer;
  Timer? _hideTimer;
  bool _isBotTyping = false;
  bool _isAiThinking = false;
  bool _isNavVisible = false;
  int _lastMessageCount = 0;
  String? _replyToMessage;
  Timer? _readReceiptTimer;
  Timer? _deliveryReceiptTimer;
  String? _lastDeliverySignature;
  String? _lastReadSignature;
  final List<MessageModel> _optimisticMessages = <MessageModel>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load chat visibility from database
      ref.read(chatVisibilityProvider.notifier).loadVisibilityFromDatabase();

      if (widget.chatId != null || widget.userId != null) {
        // Check if this is a new GracyAI conversation (timestamp-based ID)
        final isNewGracyConversation =
            widget.chatId != null &&
            ChatRepository.isBotParticipant(widget.userId ?? '') &&
            _isTimestampId(widget.chatId!);

        if (isNewGracyConversation) {
          debugPrint('Starting new GracyAI conversation with fresh start');
        }

        // Atomic load
        ref.read(activeChatProvider.notifier).openChat(widget.chatId);
      }
    });
  }

  bool _isTimestampId(String chatId) {
    try {
      final timestamp = int.parse(chatId);
      // If it's a recent timestamp (within last 24 hours), consider it new
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneDayAgo = now - (24 * 60 * 60 * 1000);
      return timestamp > oneDayAgo;
    } catch (e) {
      return false;
    }
  }

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

  void _resetOfflineBannerSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(offlineBannerProvider.notifier)
          .resetOfflineCachedContentNotice();
    });
  }

  @override
  void dispose() {
    _botTypingTimer?.cancel();
    _hideTimer?.cancel();
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
      context.push('${AppRoutePaths.chat}?chatId=${thread.roomId}');
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

    final MessageModel optimisticMessage = MessageModel(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      chatId: thread.roomId,
      senderId: currentUserId,
      text: content,
      sentAt: DateTime.now(),
      isMe: true,
      senderName: 'You',
      status: MessageStatus.pending,
      isPending: true,
    );

    setState(() {
      _optimisticMessages.add(optimisticMessage);
    });
    _composerController.clear();
    _replyToMessage = null;

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            roomId: thread.roomId,
            senderId: currentUserId,
            content: content,
          );
      if (!mounted) return;
      ref.invalidate(messagesProvider(thread.roomId));
      ref.invalidate(recentChatsProvider);

      // Check if this is a message to GracyAI
      if (ChatRepository.isBotParticipant(thread.participant.id)) {
        await _handleAiResponse(thread, content);
      } else {
        _triggerFakeTyping();
      }
    } catch (error) {
      setState(() {
        _optimisticMessages.removeWhere(
          (MessageModel message) => message.id == optimisticMessage.id,
        );
      });
      _showFeedback('Message failed: $error');
    }
  }

  Future<void> _handleAiResponse(ChatThread thread, String userMessage) async {
    setState(() {
      _isAiThinking = true;
    });

    try {
      // Get conversation history for context
      final AsyncValue<LocalFirstData<List<MessageModel>>> messagesAsync = ref
          .read(messagesProvider(thread.roomId));
      final List<MessageModel> conversationHistory = <MessageModel>[
        ...?messagesAsync.asData?.value.data,
      ];

      // Generate AI response
      final aiResponse = await GeminiService().generateResponse(
        userMessage,
        userMessage: userMessage,
        conversationHistory: conversationHistory,
      );

      if (mounted) {
        // Send AI response as a message
        await ref
            .read(chatRepositoryProvider)
            .sendMessage(
              roomId: thread.roomId,
              senderId: ChatRepository.officialBotUserId,
              content: aiResponse,
              fallbackToCacheOnRemoteFailure: true,
            );
        ref.invalidate(messagesProvider(thread.roomId));
        ref.invalidate(recentChatsProvider);
      }
    } catch (error) {
      debugPrint('AI response error: $error');
      if (mounted) {
        // Send fallback message
        await ref
            .read(chatRepositoryProvider)
            .sendMessage(
              roomId: thread.roomId,
              senderId: ChatRepository.officialBotUserId,
              content:
                  'Sorry, I\'m having trouble connecting right now. Please try again in a moment.',
              fallbackToCacheOnRemoteFailure: true,
            );
        ref.invalidate(messagesProvider(thread.roomId));
        ref.invalidate(recentChatsProvider);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiThinking = false;
        });
      }
    }
  }

  List<MessageModel> _mergeMessages(List<MessageModel> liveMessages) {
    final List<MessageModel> merged = List<MessageModel>.from(liveMessages);

    for (final MessageModel optimistic in _optimisticMessages) {
      final bool confirmed = liveMessages.any((MessageModel serverMessage) {
        final Duration ageGap = serverMessage.sentAt.difference(
          optimistic.sentAt,
        );
        return serverMessage.isMe &&
            serverMessage.text == optimistic.text &&
            ageGap.inSeconds.abs() <= 120;
      });

      if (!confirmed) {
        merged.add(optimistic);
      }
    }

    merged.sort(
      (MessageModel a, MessageModel b) => a.sentAt.compareTo(b.sentAt),
    );

    final Set<String> confirmedIds = liveMessages
        .where((MessageModel serverMessage) {
          return _optimisticMessages.any((MessageModel optimistic) {
            final Duration ageGap = serverMessage.sentAt.difference(
              optimistic.sentAt,
            );
            return serverMessage.isMe &&
                serverMessage.text == optimistic.text &&
                ageGap.inSeconds.abs() <= 120;
          });
        })
        .map((MessageModel message) => message.id)
        .toSet();

    if (confirmedIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _optimisticMessages.removeWhere((MessageModel optimistic) {
            return liveMessages.any((MessageModel serverMessage) {
              final Duration ageGap = serverMessage.sentAt.difference(
                optimistic.sentAt,
              );
              return serverMessage.isMe &&
                  serverMessage.text == optimistic.text &&
                  ageGap.inSeconds.abs() <= 120;
            });
          });
        });
      });
    }

    return merged;
  }

  void _markMessagesAsRead(ChatThread thread) {
    _readReceiptTimer?.cancel();
    _readReceiptTimer = Timer(const Duration(milliseconds: 1000), () async {
      final String? currentUserId = ref.read(authNotifierProvider).userId;
      if (currentUserId == null) {
        return;
      }
      try {
        await ref
            .read(chatRepositoryProvider)
            .markMessagesAsRead(
              roomId: thread.roomId,
              currentUserId: currentUserId,
              participantId: thread.participant.id,
            );
        // local update is now handled by the ActiveChatNotifier or here safely
        ref.read(localReadChatsProvider.notifier).markRead(thread.roomId);
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

  Future<void> _handleDelete(MessageModel message) async {
    final String? currentUserId = ref.read(authNotifierProvider).userId;
    if (currentUserId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D29),
        title: const Text(
          'Delete Message',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This message will be permanently deleted. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.electricBlue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ref
            .read(chatRepositoryProvider)
            .deleteMessage(messageId: message.id, currentUserId: currentUserId);
        if (!mounted) return;
        _showFeedback('Message deleted');
      } catch (error) {
        _showFeedback('Failed to delete message: $error');
      }
    }
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
    if (_lastMessageCount == messageCount && !_isBotTyping && !_isAiThinking) {
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

  void _handlePointerActivity(PointerDownEvent _) {
    _showNavigationTemporarily();
  }

  void _showNavigationTemporarily() {
    _hideTimer?.cancel();

    if (!_isNavVisible && mounted) {
      setState(() {
        _isNavVisible = true;
      });
    }

    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isNavVisible = false;
      });
    });
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
      receiverId: widget.userId ?? ChatRepository.officialBotUserId,
      receiverName: widget.receiverName,
      receiverAvatar: widget.receiverAvatar,
    );

    // Guard: If we are in thread mode but essential data is missing, show loading
    final bool isThreadExpected =
        widget.chatId != null || widget.userId != null;
    if (isThreadExpected && widget.chatId == null && widget.userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.cyan)),
      );
    }

    final bool showThread = request.roomId != null || request.userId != null;
    _syncShellNavigation(showThread);
    final AsyncValue<LocalFirstData<List<ChatModel>>> recentChatsAsync = ref
        .watch(recentChatsProvider);

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

    if (widget.userId != null && widget.userId == currentUserId) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _CenteredMessage(
          title: 'Chat unavailable',
          subtitle: 'You cannot start a chat with yourself.',
        ),
      );
    }

    final AsyncValue<ChatThread?> threadAsync = ref.watch(
      chatThreadProvider(request),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerActivity,
        child: LayoutBuilder(
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

                        final AsyncValue<LocalFirstData<List<MessageModel>>>
                        messagesAsync = ref.watch(
                          messagesProvider(thread.roomId),
                        );

                        return messagesAsync.when(
                          data: (LocalFirstData<List<MessageModel>> snapshot) {
                            _resetOfflineBannerSoon();
                            final List<MessageModel> messages = _mergeMessages(
                              snapshot.data,
                            );
                            _syncReceiptState(thread, messages);
                            _maybeScrollToBottom(
                              messages.length +
                                  ((_isBotTyping || _isAiThinking) ? 1 : 0),
                            );
                            return _ThreadView(
                              thread: thread,
                              messages: messages,
                              composerController: _composerController,
                              scrollController: _scrollController,
                              isBotTyping:
                                  (_isBotTyping || _isAiThinking) &&
                                  ChatRepository.isBotParticipant(
                                    thread.participant.id,
                                  ),
                              isNavVisible: _isNavVisible,
                              replyToMessage: _replyToMessage,
                              onBack: showSidebar
                                  ? null
                                  : () {
                                      if (context.canPop()) {
                                        context.pop();
                                        return;
                                      }
                                      context.go(AppRoutePaths.chat);
                                    },
                              onClose: () => context.go(AppRoutePaths.chat),
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
  final AsyncValue<LocalFirstData<List<ChatModel>>> recentChatsAsync;
  final TextEditingController startChatController;
  final VoidCallback onStartChat;
  final bool dense;

  Future<void> _showChatActions(
    BuildContext context,
    WidgetRef ref,
    ChatModel chat,
    UserModel user,
  ) {
    return showTopOverlaySheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return Material(
          color: const Color(0xFF14181D),
          borderRadius: BorderRadius.circular(24),
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
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: Color(0xFFFFD27A),
                ),
                title: Text(
                  'Remove From View',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Hide ${user.fullName} from this chat list.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref
                      .read(chatVisibilityProvider.notifier)
                      .setVisibility(chat.id, ChatVisibility.hidden);
                  if (!context.mounted) {
                    return;
                  }
                  ref.read(localReadChatsProvider.notifier).markRead(chat.id);
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${user.fullName} removed from view.'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await ref
                                .read(chatVisibilityProvider.notifier)
                                .setVisibility(chat.id, ChatVisibility.visible);
                          },
                        ),
                      ),
                    );
                },
              ),
              const Divider(height: 1, color: Color(0xFF2A2E34)),
              ListTile(
                leading: const Icon(
                  Icons.archive_outlined,
                  color: Color(0xFF7AD7FF),
                ),
                title: Text(
                  'Archive',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Move ${user.fullName} into archived chats.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref
                      .read(chatVisibilityProvider.notifier)
                      .setVisibility(chat.id, ChatVisibility.archived);
                  if (!context.mounted) {
                    return;
                  }
                  ref.read(localReadChatsProvider.notifier).markRead(chat.id);
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${user.fullName} archived.'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await ref
                                .read(chatVisibilityProvider.notifier)
                                .setVisibility(chat.id, ChatVisibility.visible);
                          },
                        ),
                      ),
                    );
                },
              ),
              const Divider(height: 1, color: Color(0xFF2A2E34)),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Color(0xFFFF7A7A),
                ),
                title: Text(
                  'Delete Permanently',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Remove ${user.fullName} from this device list.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref
                      .read(chatVisibilityProvider.notifier)
                      .setVisibility(chat.id, ChatVisibility.deleted);
                  if (!context.mounted) {
                    return;
                  }
                  ref.read(localReadChatsProvider.notifier).markRead(chat.id);
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${user.fullName} deleted from view.'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await ref
                                .read(chatVisibilityProvider.notifier)
                                .setVisibility(chat.id, ChatVisibility.visible);
                          },
                        ),
                      ),
                    );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isStarting = ref.watch(startChatControllerProvider).isLoading;
    final Map<String, ChatVisibility> chatVisibility = ref.watch(
      chatVisibilityProvider,
    );
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
                      hintText: currentUserCode == null
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            recentChatsAsync.when(
              data: (LocalFirstData<List<ChatModel>> snapshot) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(offlineBannerProvider.notifier)
                      .resetOfflineCachedContentNotice();
                });
                final List<ChatModel> chats = snapshot.data
                    .where(
                      (ChatModel chat) =>
                          chatVisibility[chat.id] == null ||
                          chatVisibility[chat.id] == ChatVisibility.visible,
                    )
                    .toList(growable: false);
                final List<ChatModel> archivedChats = snapshot.data
                    .where(
                      (ChatModel chat) =>
                          chatVisibility[chat.id] == ChatVisibility.archived,
                    )
                    .toList(growable: false);
                if (chats.isEmpty) {
                  if (archivedChats.isEmpty) {
                    return const _CenteredMessage(
                      title: 'No chats yet',
                      subtitle:
                          'Use a Gracy code above to create the first room.',
                    );
                  }
                }

                return Column(
                  children: <Widget>[
                    // GracyAI - Always at top
                    Builder(
                      builder: (BuildContext context) {
                        final UserModel gracyAi = UserModel(
                          id: ChatRepository.officialBotUserId,
                          fullName: 'GracyAI',
                          username: '@gracyai',
                          age: 0,
                          role: UserRole.staff,
                          courses: const <String>[],
                          bio:
                              'The Official Brain of Gracy. Powered by Gemini 1.5 Pro.',
                          isOnline: true,
                          location: 'Digital Campus',
                          avatarSeed: 'GracyAI',
                          year: 'Always Active',
                          gracyId: ChatRepository.botGracyCode,
                        );

                        final ChatModel gracyAiChat = ChatModel(
                          id: 'gracy-ai-chat',
                          participantId: ChatRepository.officialBotUserId,
                          lastMessage: 'GracyAI: The Official Brain of Gracy ⚡',
                          lastMessageAt: DateTime.now(),
                          unreadCount: 0,
                          roomHash: '',
                          isOfficial: true,
                          gracyId: ChatRepository.botGracyCode,
                          isOnline: true,
                        );

                        return ChatTile(
                          chat: gracyAiChat,
                          user: gracyAi,
                          onTap: () {
                            context.go(
                              AppRoutePaths.chatByUser(
                                userId: ChatRepository.officialBotUserId,
                                receiverName: gracyAi.fullName,
                                receiverAvatar: gracyAi.avatarUrl,
                              ),
                            );
                          },
                          onLongPress: () {
                            _showChatActions(
                              context,
                              ref,
                              gracyAiChat,
                              gracyAi,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
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
                                AppRoutePaths.chatByRoom(
                                  chatId: chat.id,
                                  userId: user.id,
                                  receiverName: user.fullName,
                                  receiverAvatar: user.avatarUrl,
                                ),
                              );
                            },
                            onLongPress: () {
                              _showChatActions(context, ref, chat, user);
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
                    if (archivedChats.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Archived',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final ChatModel archivedChat in archivedChats)
                        Builder(
                          builder: (BuildContext context) {
                            final UserModel? user =
                                profilesById[archivedChat.participantId];
                            if (user == null) {
                              return const SizedBox.shrink();
                            }
                            return ChatTile(
                              chat: archivedChat,
                              user: user,
                              onTap: () {
                                ref
                                    .read(chatVisibilityProvider.notifier)
                                    .setVisibility(
                                      archivedChat.id,
                                      ChatVisibility.visible,
                                    );
                                context.go(
                                  AppRoutePaths.chatByRoom(
                                    chatId: archivedChat.id,
                                    userId: user.id,
                                    receiverName: user.fullName,
                                    receiverAvatar: user.avatarUrl,
                                  ),
                                );
                              },
                              onLongPress: () {
                                ref
                                    .read(chatVisibilityProvider.notifier)
                                    .setVisibility(
                                      archivedChat.id,
                                      ChatVisibility.visible,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${user.fullName} restored from archive.',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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
    required this.isNavVisible,
    required this.onSend,
    required this.onClose,
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
  final bool isNavVisible;
  final VoidCallback onSend;
  final VoidCallback onClose;
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

      // Add message bubble - use GlassmorphismBubble for AI messages
      if (ChatRepository.isBotParticipant(message.senderId)) {
        widgets.add(
          GlassmorphismBubble(
            message: message,
            onReply: () => onReply(message),
            onForward: () => onForward(message),
            onDelete: () => onDelete(message),
          ),
        );
      } else {
        widgets.add(
          IndustrialMessageBubble(
            message: message,
            onReply: () => onReply(message),
            onForward: () => onForward(message),
            onDelete: () => onDelete(message),
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final isGracyAI = ChatRepository.isBotParticipant(thread.participant.id);

    return Container(
      color: Colors.black,
      child: Column(
        children: <Widget>[
          // Header - Always visible (24/7) as per user request
          _ThreadHeader(
            participant: thread.participant,
            isVisible: true, // Permanent visibility
            onBack: onBack,
            onClose: onClose,
            onViewProfile: onViewProfile,
          ),
          Expanded(
            child: isGracyAI
                ? _buildNeuralChatInterface(context)
                : _buildStandardChatInterface(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNeuralChatInterface(BuildContext context) {
    final isGracyAI = ChatRepository.isBotParticipant(thread.participant.id);
    final hasMessages = messages.isNotEmpty;

    return NeuralBackground(
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
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (hasMessages) {
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 80),
                      itemCount: messages.length + (isBotTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && isBotTyping) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: NeuralThinkingIndicator(),
                          );
                        }

                        if (index >= messages.length) {
                          return const SizedBox.shrink();
                        }

                        final message = messages[index];
                        return GlassmorphismBubble(
                          message: message,
                          onReply: () => onReply(message),
                          onForward: () => onForward(message),
                          onDelete: () => onDelete(message),
                        );
                      },
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 24
                            ? constraints.maxHeight - 24
                            : 0,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isGracyAI) ...<Widget>[
                              const GracyAILogo(size: 80, glowing: true),
                              const SizedBox(height: 24),
                              const Text(
                                'How can I help you today?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.electricBlue.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'Ask me anything about campus life, studies, or just chat!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            if (isBotTyping) ...<Widget>[
                              const SizedBox(height: 20),
                              const SizedBox(
                                width: 320,
                                child: NeuralThinkingIndicator(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Composer
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(color: Colors.black),
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
    );
  }

  Widget _buildStandardChatInterface(BuildContext context) {
    return Container(
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
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(color: Colors.black),
            child: IndustrialChatComposer(
              controller: composerController,
              onSend: onSend,
              replyToMessage: replyToMessage,
              onCancelReply: onCancelReply,
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
    required this.isVisible,
    required this.onViewProfile,
    required this.onClose,
    this.onBack,
  });

  final UserModel participant;
  final bool isVisible;
  final VoidCallback onViewProfile;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  Future<void> _showThreadMenu(BuildContext context) async {
    await showTopOverlaySheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return Material(
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
              // Only show profile features for human users, not GracyAI
              if (!ChatRepository.isBotParticipant(participant.id)) ...[
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
              ],
              const Divider(height: 1, color: Color(0xFF2A2E34)),
              if (ChatRepository.isBotParticipant(participant.id)) ...[
                _ThreadActionTile(
                  icon: Icons.refresh_rounded,
                  label: 'New Conversation',
                  color: const Color(0xFF007AFF),
                  onTap: () async {
                    final GoRouter router = GoRouter.of(context);
                    Navigator.of(sheetContext).pop();
                    // Start new conversation with GracyAI
                    final String newRoomId = DateTime.now()
                        .millisecondsSinceEpoch
                        .toString();
                    router.go(
                      AppRoutePaths.chatByRoom(
                        chatId: newRoomId,
                        userId: ChatRepository.officialBotUserId,
                        receiverName: participant.fullName,
                        receiverAvatar: participant.avatarUrl,
                      ),
                    );
                  },
                ),
              ],
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserModel safeParticipant = participant.id.isEmpty
        ? participant.copyWith(
            id: 'unknown-user',
            fullName: participant.fullName.trim().isEmpty
                ? 'Gracy User'
                : participant.fullName,
          )
        : participant;
    final bool isOfficial = ChatRepository.isBotParticipant(safeParticipant.id);

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
            const SizedBox(width: 2),
          ],
          GestureDetector(
            onTap: onViewProfile,
            child: isOfficial
                ? const SizedBox(
                    width: 38,
                    height: 38,
                    child: GracyAILogo(size: 38, glowing: true),
                  )
                : UserAvatar(
                    user: safeParticipant,
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
                        safeParticipant.fullName.trim().isEmpty
                            ? 'Gracy User'
                            : safeParticipant.fullName,
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
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white70,
            tooltip: 'Close conversation',
          ),
          IconButton(
            onPressed: () => _showThreadMenu(context),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white70,
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) =>
                        const DisappearingMessagesDialog(),
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

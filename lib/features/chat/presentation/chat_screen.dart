import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/widgets/chat_tile.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/disappearing_messages_dialog.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_composer.dart';

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

  @override
  void dispose() {
    _botTypingTimer?.cancel();
    _composerController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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
      ref.invalidate(recentChatsProvider);

      if (thread.participant.id == ChatRepository.botUserId) {
        _triggerFakeTyping();
      }
    } catch (error) {
      _showFeedback('Message failed: $error');
    }
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
    final AsyncValue<List<ChatModel>> recentChatsAsync = ref.watch(
      recentChatsProvider,
    );

    if (!showThread) {
      return Scaffold(
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
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showSidebar = constraints.maxWidth >= 980;

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF060D18),
                  AppColors.background,
                  AppColors.backgroundAlt,
                ],
              ),
            ),
            child: SafeArea(
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
                              onBack: showSidebar
                                  ? null
                                  : () {
                                      context.go(AppRoutePaths.chat);
                                    },
                              onSend: () => _sendMessage(thread),
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF060D18),
            AppColors.background,
            AppColors.backgroundAlt,
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(dense ? 18 : AppConstants.pagePadding),
          children: <Widget>[
            Text(
              'Direct line',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start one-on-one chats by Gracy code. Rooms are stable, so the bot and real users land in the same recent chats flow.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: Theme.of(context).dividerTheme.color ?? Colors.grey,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              currentUserName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currentUserCode == null
                                  ? 'Your Gracy code will appear here after onboarding.'
                                  : 'Your code: $currentUserCode',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: startChatController,
                    hintText:
                        'Paste a Gracy code, e.g. ${ChatRepository.botGracyCode}',
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: CustomButton(
                          label: isStarting ? 'Opening...' : 'Start Chat',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: isStarting ? () {} : onStartChat,
                          fullWidth: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Text(
                  'Recent chats',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    'Live',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
                  children: chats.map((ChatModel chat) {
                    final UserModel? user = profilesById[chat.participantId];
                    if (user == null) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ChatTile(
                        chat: chat,
                        user: user,
                        onTap: () {
                          context.go('${AppRoutePaths.chat}?chatId=${chat.id}');
                        },
                      ),
                    );
                  }).toList(),
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
    this.onBack,
  });

  final ChatThread thread;
  final List<MessageModel> messages;
  final TextEditingController composerController;
  final ScrollController scrollController;
  final bool isBotTyping;
  final VoidCallback onSend;
  final VoidCallback onViewProfile;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: <Widget>[
          _ThreadHeader(
            participant: thread.participant,
            onBack: onBack,
            onViewProfile: onViewProfile,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    const Color(0xFF0A1322).withValues(alpha: 0.94),
                    const Color(0xFF0D182B).withValues(alpha: 0.94),
                  ],
                ),
                border: Border.all(color: AppColors.outline),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                children: <Widget>[
                  ...messages.map(
                    (MessageModel message) => MessageBubble(message: message),
                  ),
                  if (isBotTyping)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _TypingIndicator(
                        name: thread.participant.fullName,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ChatComposer(controller: composerController, onSend: onSend),
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

  @override
  Widget build(BuildContext context) {
    final bool isOfficial = participant.id == ChatRepository.botUserId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            if (onBack != null) ...<Widget>[
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
            ],
            UserAvatar(user: participant, size: 40, fontSize: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: [
                      Text(
                        participant.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
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
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Official',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOfficial ? 'Gracy Assistant' : 'Tap to view profile',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Consumer(
              builder: (context, ref, child) {
                return IconButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => const DisappearingMessagesDialog(),
                    );
                  },
                  icon: const Icon(Icons.timer_rounded),
                  tooltip: 'Disappearing Messages',
                );
              },
            ),
          ],
        ),
      ),
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? Colors.grey,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$name is typing',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

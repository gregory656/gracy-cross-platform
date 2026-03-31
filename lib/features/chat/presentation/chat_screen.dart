import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/mock_providers.dart';
import '../../../shared/widgets/chat_tile.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../widgets/chat_composer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.chatId,
  });

  final String? chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, List<MessageModel>> _draftMessages = <String, List<MessageModel>>{};
  String _query = '';

  @override
  void dispose() {
    _composerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _sendMessage(String chatId) {
    final String text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      final List<MessageModel> messages = _draftMessages.putIfAbsent(chatId, () => <MessageModel>[]);
      messages.add(
        MessageModel(
          id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
          chatId: chatId,
          senderId: 'me',
          text: text,
          sentAt: DateTime.now(),
          isMe: true,
        ),
      );
      _composerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ChatModel> chats = ref.watch(mockChatsProvider);
    final List<UserModel> users = ref.watch(mockUsersProvider);
    final String? selectedChatId = widget.chatId;

    if (selectedChatId == null) {
      final List<ChatModel> filteredChats = chats.where((ChatModel chat) {
        final String query = _query.toLowerCase().trim();
        if (query.isEmpty) {
          return true;
        }
        final UserModel? participant = users.where((UserModel user) => user.id == chat.participantId).isNotEmpty
            ? users.firstWhere((UserModel user) => user.id == chat.participantId)
            : null;
        final String name = participant?.fullName.toLowerCase() ?? '';
        return name.contains(query) || chat.lastMessage.toLowerCase().contains(query);
      }).toList();

      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.background,
                AppColors.backgroundAlt,
              ],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: AppConstants.screenPadding,
              children: <Widget>[
                Text(
                  'Conversations',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Static mock messages now. Realtime wiring comes later.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _searchController,
                  hintText: 'Search chats',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (String value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
                ...filteredChats.map((ChatModel chat) {
                  final UserModel user = users.firstWhere((UserModel entry) => entry.id == chat.participantId);
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
                }),
              ],
            ),
          ),
        ),
      );
    }

    final ChatModel chat = ref.watch(chatByIdProvider(selectedChatId)) ?? chats.firstWhere((ChatModel entry) => entry.id == selectedChatId);
    final UserModel user = ref.watch(userByIdProvider(chat.participantId)) ?? users.firstWhere((UserModel entry) => entry.id == chat.participantId);
    final List<MessageModel> baseMessages = ref.watch(messagesForChatProvider(chat.id));
    final List<MessageModel> draftMessages = _draftMessages[chat.id] ?? <MessageModel>[];
    final List<MessageModel> messages = <MessageModel>[
      ...baseMessages,
      ...draftMessages,
    ]..sort((MessageModel a, MessageModel b) => a.sentAt.compareTo(b.sentAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(user.fullName),
        leading: IconButton(
          onPressed: () {
            context.go(AppRoutePaths.chat);
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              context.go('${AppRoutePaths.profile}?userId=${user.id}');
            },
            icon: const Icon(Icons.person_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= 900) {
            final List<Widget> sidebarItems = chats
                .map(
                  (ChatModel entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ChatTile(
                      chat: entry,
                      user: users.firstWhere((UserModel person) => person.id == entry.participantId),
                      onTap: () {
                        context.go('${AppRoutePaths.chat}?chatId=${entry.id}');
                      },
                    ),
                  ),
                )
                .toList();

            return Row(
              children: <Widget>[
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: AppConstants.screenPadding,
                    children: <Widget>[
                      Text(
                        'Conversations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ...sidebarItems,
                    ],
                  ),
                ),
                Expanded(
                  child: _ChatThread(
                    user: user,
                    messages: messages,
                    composerController: _composerController,
                    onSend: () => _sendMessage(chat.id),
                  ),
                ),
              ],
            );
          }

          return _ChatThread(
            user: user,
            messages: messages,
            composerController: _composerController,
            onSend: () => _sendMessage(chat.id),
          );
        },
      ),
    );
  }
}

class _ChatThread extends StatelessWidget {
  const _ChatThread({
    required this.user,
    required this.messages,
    required this.composerController,
    required this.onSend,
  });

  final UserModel user;
  final List<MessageModel> messages;
  final TextEditingController composerController;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 24,
            child: Row(
              children: <Widget>[
                _ThreadAvatar(initials: user.initials, online: user.isOnline),
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
                      const SizedBox(height: 4),
                      Text(
                        '${user.role.label} • ${user.location}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            itemCount: messages.length,
            itemBuilder: (BuildContext context, int index) {
              return MessageBubble(message: messages[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ChatComposer(
            controller: composerController,
            onSend: onSend,
          ),
        ),
      ],
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({
    required this.initials,
    required this.online,
  });

  final String initials;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.accentBlue,
                AppColors.accentCyan,
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: online ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}


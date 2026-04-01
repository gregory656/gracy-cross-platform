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
import '../../../shared/providers/mock_providers.dart';
import '../../../shared/providers/profiles_provider.dart';
import '../../../shared/widgets/chat_tile.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../widgets/chat_composer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.chatId,
    this.userId,
  });

  final String? chatId;
  final String? userId;

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

  void _sendMessage(String threadId) {
    final String text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      final List<MessageModel> messages = _draftMessages.putIfAbsent(threadId, () => <MessageModel>[]);
      messages.add(
        MessageModel(
          id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
          chatId: threadId,
          senderId: 'me',
          text: text,
          sentAt: DateTime.now(),
          isMe: true,
        ),
      );
      _composerController.clear();
    });
  }

  ChatModel _syntheticChatForUser(UserModel user) {
    return ChatModel(
      id: 'live-${user.id}',
      participantId: user.id,
      lastMessage: user.gracyId != null ? 'Gracy code: ${user.gracyId}' : user.bio,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<UserModel>> profilesAsync = ref.watch(profilesDirectoryProvider);
    final List<UserModel> fallbackUsers = ref.watch(mockUsersProvider);
    final UserModel? currentUser = ref.watch(currentUserProvider);
    final List<UserModel> directory = profilesAsync.when(
      data: (List<UserModel> users) => users,
      loading: () => fallbackUsers,
      error: (Object error, StackTrace stackTrace) => fallbackUsers,
    );
    final List<UserModel> visibleDirectory = directory
        .where((UserModel user) => currentUser == null || user.id != currentUser.id)
        .toList();
    final String? selectedChatId = widget.chatId;
    final String? selectedUserId = widget.userId;

    if (selectedChatId == null && selectedUserId == null) {
      final List<UserModel> filteredUsers = visibleDirectory.where((UserModel user) {
        final String query = _query.toLowerCase().trim();
        if (query.isEmpty) {
          return true;
        }
        return user.fullName.toLowerCase().contains(query) ||
            user.username.toLowerCase().contains(query) ||
            user.bio.toLowerCase().contains(query) ||
            user.year.toLowerCase().contains(query) ||
            (user.gracyId?.toLowerCase().contains(query) ?? false);
      }).toList();

      final List<ChatModel> chats = filteredUsers.map(_syntheticChatForUser).toList();

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
                  'Everyone with a Gracy profile shows up here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _searchController,
                  hintText: 'Search by name or Gracy code',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (String value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
                ...chats.map((ChatModel chat) {
                  final UserModel user = filteredUsers.firstWhere((UserModel entry) => entry.id == chat.participantId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ChatTile(
                      chat: chat,
                      user: user,
                      onTap: () {
                        context.go('${AppRoutePaths.chat}?userId=${user.id}');
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

    final UserModel? selectedUser = selectedUserId == null
        ? null
        : visibleDirectory.where((UserModel user) => user.id == selectedUserId).isNotEmpty
            ? visibleDirectory.firstWhere((UserModel user) => user.id == selectedUserId)
            : null;
    final ChatModel? mockChat = selectedChatId == null ? null : ref.watch(chatByIdProvider(selectedChatId));
    final UserModel user = selectedUser ??
        (mockChat == null
            ? (visibleDirectory.isNotEmpty ? visibleDirectory.first : fallbackUsers.first)
            : ref.watch(userByIdProvider(mockChat.participantId)) ??
                fallbackUsers.firstWhere((UserModel entry) => entry.id == mockChat.participantId));
    final String threadId = mockChat?.id ?? 'live-${user.id}';
    final List<MessageModel> baseMessages = mockChat == null ? <MessageModel>[] : ref.watch(messagesForChatProvider(mockChat.id));
    final List<MessageModel> draftMessages = _draftMessages[threadId] ?? <MessageModel>[];
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
            final List<Widget> sidebarItems = visibleDirectory
                .map(
                  (UserModel person) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ChatTile(
                      chat: _syntheticChatForUser(person),
                      user: person,
                      onTap: () {
                        context.go('${AppRoutePaths.chat}?userId=${person.id}');
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
                    onSend: () => _sendMessage(threadId),
                  ),
                ),
              ],
            );
          }

          return _ChatThread(
            user: user,
            messages: messages,
            composerController: _composerController,
            onSend: () => _sendMessage(threadId),
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
                        user.gracyId != null
                            ? 'Gracy ID: ${user.gracyId!}'
                            : '${user.role.label} • ${user.location}',
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

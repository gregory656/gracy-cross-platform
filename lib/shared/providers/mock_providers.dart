import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock_data/mock_chats.dart';
import '../mock_data/mock_messages.dart';
import '../mock_data/mock_users.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

// ⚠️ DO NOT MODIFY: Core architecture logic
// This file is the single mock-data entry point so backend sources can swap in
// later without touching presentation code.
final mockUsersProvider = Provider<List<UserModel>>((Ref<List<UserModel>> ref) => mockUsers);

final mockChatsProvider = Provider<List<ChatModel>>((Ref<List<ChatModel>> ref) => mockChats);

final mockMessagesProvider = Provider<List<MessageModel>>((Ref<List<MessageModel>> ref) => mockMessages);

final userByIdProvider = Provider.family<UserModel?, String>(
  (Ref<UserModel?> ref, String userId) {
    final List<UserModel> users = ref.watch(mockUsersProvider);
    for (final UserModel user in users) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  },
);

final chatByIdProvider = Provider.family<ChatModel?, String>(
  (Ref<ChatModel?> ref, String chatId) {
    final List<ChatModel> chats = ref.watch(mockChatsProvider);
    for (final ChatModel chat in chats) {
      if (chat.id == chatId) {
        return chat;
      }
    }
    return null;
  },
);

final messagesForChatProvider = Provider.family<List<MessageModel>, String>(
  (Ref<List<MessageModel>> ref, String chatId) {
    final List<MessageModel> messages = ref.watch(mockMessagesProvider);
    final List<MessageModel> filtered = messages
        .where((MessageModel message) => message.chatId == chatId)
        .toList()
      ..sort((MessageModel a, MessageModel b) => a.sentAt.compareTo(b.sentAt));
    return filtered;
  },
);


import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/mock_data/mock_chats.dart';
import '../../../shared/mock_data/mock_messages.dart';
import '../../../shared/mock_data/mock_users.dart';
import '../../../shared/enums/user_role.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/chat_thread.dart';
import '../../../shared/models/local_first_data.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/database_service.dart';

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatRepository {
  ChatRepository({
    SupabaseClient? supabase,
    DatabaseService? databaseService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _databaseService = databaseService ?? DatabaseService.instance;

  static const String botUserId = 'gracy-ai-bot';
  static const String botGracyCode = 'gracy-ai-001';

  final SupabaseClient _supabase;
  final DatabaseService _databaseService;

  Stream<LocalFirstData<List<ChatModel>>> watchRecentChats(String currentUserId) async* {
    final List<ChatModel> cachedChats = await _databaseService.getCachedRecentChats(currentUserId);
    if (cachedChats.isNotEmpty) {
      yield LocalFirstData<List<ChatModel>>(data: cachedChats, isFromCache: true);
    } else {
      yield LocalFirstData<List<ChatModel>>(data: mockChats, isFromCache: true);
    }
  }

  Stream<LocalFirstData<List<MessageModel>>> watchMessages({
    required String roomId,
    required String currentUserId,
  }) async* {
    final List<MessageModel> cachedMessages = await _databaseService.getCachedMessages(
      roomId: roomId,
      currentUserId: currentUserId,
    );
    if (cachedMessages.isNotEmpty) {
      yield LocalFirstData<List<MessageModel>>(data: cachedMessages, isFromCache: true);
      return;
    }

    final List<MessageModel> fallback = mockMessages
        .where((MessageModel message) => message.chatId == roomId)
        .toList(growable: false);
    yield LocalFirstData<List<MessageModel>>(data: fallback, isFromCache: true);
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    final String senderName = senderId == botUserId
        ? 'Gracy AI'
        : _findUser(senderId)?.fullName ?? 'Gracy User';
    final MessageModel message = MessageModel(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      chatId: roomId,
      senderId: senderId,
      text: content,
      sentAt: DateTime.now(),
      isMe: _supabase.auth.currentUser?.id == senderId,
      senderName: senderName,
      status: MessageStatus.sent,
    );

    final String ownerId = _supabase.auth.currentUser?.id ?? senderId;
    final List<MessageModel> existing = await _databaseService.getCachedMessages(
      roomId: roomId,
      currentUserId: ownerId,
    );
    await _databaseService.cacheMessages(
      roomId: roomId,
      ownerId: ownerId,
      messages: <MessageModel>[...existing, message],
    );
  }

  Future<void> markMessagesAsRead({
    required String roomId,
    required String currentUserId,
    required String participantId,
  }) => _databaseService.markCachedMessagesAsRead(
        roomId: roomId,
        ownerId: currentUserId,
        senderId: participantId,
      );

  Future<void> markMessagesAsDelivered({
    required String roomId,
    required String userId,
  }) async {}

  Future<void> deleteMessage({
    required String messageId,
    required String currentUserId,
  }) async {}

  Future<ChatThread?> resolveThread({
    required String currentUserId,
    String? roomId,
    String? userId,
    String? receiverName,
    String? receiverAvatar,
  }) async {
    final String participantId = userId ?? botUserId;
    final UserModel participant =
        _findUser(participantId) ??
        UserModel(
          id: participantId,
          fullName: receiverName ?? 'Gracy User',
          username: receiverName == null ? '@gracyuser' : '@${receiverName.toLowerCase().replaceAll(' ', '')}',
          role: participantId == botUserId ? UserRole.staff : UserRole.student,
          courses: const <String>[],
          bio: participantId == botUserId ? 'AI Assistant' : 'Gracy user',
          isOnline: true,
          avatarUrl: receiverAvatar,
        );

    return ChatThread(
      id: roomId ?? _roomIdFor(currentUserId, participantId),
      participantId: participantId,
      roomId: roomId ?? _roomIdFor(currentUserId, participantId),
      participant: participant,
    );
  }

  Future<ChatThread> findOrCreateRoomByCode({
    required String currentUserId,
    required String gracyId,
  }) async {
    if (gracyId == botGracyCode) {
      return (await resolveThread(
        currentUserId: currentUserId,
        userId: botUserId,
        receiverName: 'Gracy AI',
      ))!;
    }

    final UserModel? participant = mockUsers.cast<UserModel?>().firstWhere(
      (UserModel? user) => user?.gracyId == gracyId,
      orElse: () => null,
    );

    if (participant == null) {
      throw const ChatRepositoryException('No user found for that Gracy code.');
    }

    return (await resolveThread(
      currentUserId: currentUserId,
      userId: participant.id,
      receiverName: participant.fullName,
      receiverAvatar: participant.avatarUrl,
    ))!;
  }

  UserModel? _findUser(String userId) {
    for (final UserModel user in mockUsers) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  String _roomIdFor(String left, String right) {
    final List<String> ids = <String>[left, right]..sort();
    return ids.join('_');
  }
}

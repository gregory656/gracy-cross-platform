import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
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
  ChatRepository({SupabaseClient? supabase, DatabaseService? databaseService})
    : _supabase = supabase ?? Supabase.instance.client,
      _databaseService = databaseService ?? DatabaseService.instance;

  static const String botUserId = 'gracy-ai-bot';
  static const String officialBotUserId = 'gracy_ai_official';
  static const String botGracyCode = 'gracy-ai-001';

  final SupabaseClient _supabase;
  final DatabaseService _databaseService;

  static bool isBotParticipant(String userId) {
    return userId == botUserId || userId == officialBotUserId;
  }

  Stream<LocalFirstData<List<ChatModel>>> watchRecentChats(
    String currentUserId,
  ) async* {
    final List<ChatModel> cachedChats = await _databaseService
        .getCachedRecentChats(currentUserId);
    if (cachedChats.isNotEmpty) {
      yield LocalFirstData<List<ChatModel>>(
        data: cachedChats,
        isFromCache: true,
      );
    } else {
      yield LocalFirstData<List<ChatModel>>(data: mockChats, isFromCache: true);
    }
  }

  Stream<LocalFirstData<List<MessageModel>>> watchMessages({
    required String roomId,
    required String currentUserId,
  }) async* {
    final List<MessageModel> cachedMessages = await _databaseService
        .getCachedMessages(roomId: roomId, currentUserId: currentUserId);
    if (cachedMessages.isNotEmpty) {
      yield LocalFirstData<List<MessageModel>>(
        data: cachedMessages,
        isFromCache: true,
      );
    }

    if (_canUseRemoteMessages(roomId)) {
      try {
        yield* _supabase
            .from('messages')
            .stream(primaryKey: <String>['id'])
            .eq('room_id', roomId)
            .order('created_at', ascending: true)
            .asyncMap((List<Map<String, dynamic>> rows) async {
              final List<MessageModel> rawMessages = rows
                  .map(
                    (Map<String, dynamic> row) => _messageFromRemoteRow(
                      row,
                      currentUserId: currentUserId,
                      roomId: roomId,
                    ),
                  )
                  .toList();
              
              // DEDUPLICATION FIX: Ensure unique messages by ID
              final Map<String, MessageModel> uniqueMap = {
                for (var m in rawMessages) m.id: m,
              };
              final List<MessageModel> messages = uniqueMap.values.toList();
              messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

              await _databaseService.clearCachedMessages(roomId, currentUserId);
              if (messages.isNotEmpty) {
                await _databaseService.cacheMessages(
                  roomId: roomId,
                  ownerId: currentUserId,
                  messages: messages,
                );
              }

              return LocalFirstData<List<MessageModel>>(data: messages);
            });
        return;
      } catch (error) {
        debugPrint('watchMessages remote fallback for $roomId: $error');
      }
    }

    if (cachedMessages.isNotEmpty) {
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
    bool fallbackToCacheOnRemoteFailure = false,
  }) async {
    if (_canUseRemoteMessages(roomId)) {
      try {
        await _supabase.from('messages').insert(<String, dynamic>{
          'room_id': roomId,
          'sender_id': senderId,
          'content': content,
        });
        return;
      } catch (error) {
        debugPrint('sendMessage remote failure for $roomId: $error');
        if (!fallbackToCacheOnRemoteFailure) {
          rethrow;
        }
      }
    }

    await _cacheMessageLocally(
      roomId: roomId,
      senderId: senderId,
      content: content,
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
    final String participantId = _normalizeParticipantId(
      userId ?? officialBotUserId,
    );
    final UserModel participant =
        _findUser(participantId) ??
        UserModel(
          id: participantId,
          fullName: receiverName ?? 'Gracy User',
          username: receiverName == null
              ? '@gracyuser'
              : '@${receiverName.toLowerCase().replaceAll(' ', '')}',
          role: isBotParticipant(participantId)
              ? UserRole.staff
              : UserRole.student,
          courses: const <String>[],
          bio: isBotParticipant(participantId) ? 'AI Assistant' : 'Gracy user',
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
        userId: officialBotUserId,
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

  bool _canUseRemoteMessages(String roomId) {
    return SupabaseConfig.isConfigured &&
        _supabase.auth.currentUser != null &&
        _isUuidLike(roomId);
  }

  bool _isUuidLike(String value) {
    final RegExp uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value);
  }

  String _normalizeParticipantId(String userId) {
    if (userId == botUserId) {
      return officialBotUserId;
    }
    return userId;
  }

  Future<void> _cacheMessageLocally({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    final MessageModel message = MessageModel(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      chatId: roomId,
      senderId: senderId,
      text: content,
      sentAt: DateTime.now(),
      isMe: _supabase.auth.currentUser?.id == senderId,
      senderName: _senderNameFor(senderId),
      isOfficial: isBotParticipant(senderId),
      status: MessageStatus.sent,
    );

    final String ownerId = _supabase.auth.currentUser?.id ?? senderId;
    final List<MessageModel> existing = await _databaseService
        .getCachedMessages(roomId: roomId, currentUserId: ownerId);
    await _databaseService.cacheMessages(
      roomId: roomId,
      ownerId: ownerId,
      messages: <MessageModel>[...existing, message],
    );
  }

  MessageModel _messageFromRemoteRow(
    Map<String, dynamic> row, {
    required String currentUserId,
    required String roomId,
  }) {
    final String senderId = row['sender_id']?.toString() ?? '';
    final DateTime sentAt =
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();

    return MessageModel(
      id: row['id']?.toString() ?? 'remote-${sentAt.microsecondsSinceEpoch}',
      chatId: row['room_id']?.toString() ?? roomId,
      senderId: senderId,
      text: row['content']?.toString() ?? '',
      sentAt: sentAt,
      isMe: senderId == currentUserId,
      senderName: row['sender_name']?.toString() ?? _senderNameFor(senderId),
      isOfficial: isBotParticipant(senderId),
      status: _messageStatusFromString(row['status']?.toString()),
    );
  }

  String _senderNameFor(String senderId) {
    if (isBotParticipant(senderId)) {
      return 'Gracy AI';
    }

    return _findUser(senderId)?.fullName ?? 'Gracy User';
  }

  MessageStatus _messageStatusFromString(String? value) {
    return switch (value) {
      'pending' => MessageStatus.pending,
      'delivered' => MessageStatus.delivered,
      'read' => MessageStatus.read,
      _ => MessageStatus.sent,
    };
  }
}

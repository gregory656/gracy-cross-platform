import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/local_first_data.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/database_service.dart';
import '../../../shared/services/local_notification_service.dart';
import '../../../shared/services/timezone_service.dart';

class ChatThread {
  const ChatThread({
    required this.roomId,
    required this.roomHash,
    required this.participant,
  });

  final String roomId;
  final String roomHash;
  final UserModel participant;
}

class ChatRepository {
  ChatRepository(this._client, {DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance {
    TimezoneService.initialize();
  }

  static const String botUserId = 'gracy_ai_official';
  static const String botGracyCode = 'GRACY-AI';

  static const String _profilesTable = 'profiles';
  static const String _roomsTable = 'chat_rooms';
  static const String _messagesTable = 'messages';
  static const String _chatMembersTable = 'chat_members';

  final SupabaseClient _client;
  final DatabaseService _databaseService;

  String buildRoomHash(String myId, String friendId) {
    final List<String> ids = <String>[myId, friendId]..sort();
    return ids.join('_');
  }

  Future<UserModel?> findProfileByGracyCode(String gracyId) async {
    final String normalizedCode = gracyId.trim();
    if (normalizedCode.isEmpty) {
      return null;
    }

    // Special handling for GracyAI bot
    if (normalizedCode.toUpperCase() == botGracyCode) {
      return _createGracyAiBot();
    }

    final Map<String, dynamic>? row = await _client
        .from(_profilesTable)
        .select('id,username,gracy_id,full_name,avatar_url,is_online')
        .ilike('gracy_id', normalizedCode)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _userFromProfile(row);
  }

  Future<ChatThread> findOrCreateRoomByCode({
    required String currentUserId,
    required String gracyId,
  }) async {
    final UserModel? participant = await findProfileByGracyCode(gracyId);
    if (participant == null) {
      throw const ChatRepositoryException(
        'No profile was found for that Gracy code.',
      );
    }

    return findOrCreateRoom(
      currentUserId: currentUserId,
      participantId: participant.id,
      participant: participant,
    );
  }

  Future<ChatThread> findOrCreateRoom({
    required String currentUserId,
    required String participantId,
    UserModel? participant,
  }) async {
    if (currentUserId == participantId) {
      throw const ChatRepositoryException(
        'You cannot start a chat with yourself.',
      );
    }

    final String roomHash = buildRoomHash(currentUserId, participantId);
    
    final Map<String, dynamic>? existingRoom = await _client
        .from(_roomsTable)
        .select('id,room_hash')
        .eq('room_hash', roomHash)
        .maybeSingle();

    final Map<String, dynamic> roomRow;
    if (existingRoom != null) {
      roomRow = existingRoom;
    } else {
      roomRow = await _client
          .from(_roomsTable)
          .insert(<String, dynamic>{
            'room_hash': roomHash,
          })
          .select('id,room_hash')
          .single();
    }

    final String roomId = roomRow['id']?.toString() ?? '';
    if (roomId.isEmpty) {
      throw const ChatRepositoryException('Room creation failed.');
    }

    await _ensureRoomMembers(
      roomId: roomId,
      userIds: <String>[currentUserId, participantId],
    );

    final UserModel resolvedParticipant =
        participant ?? await _fetchRequiredProfile(participantId);

    return ChatThread(
      roomId: roomId,
      roomHash: roomRow['room_hash']?.toString() ?? roomHash,
      participant: resolvedParticipant,
    );
  }

  Future<ChatThread> resolveThread({
    required String currentUserId,
    String? roomId,
    String? userId,
    String? receiverName,
    String? receiverAvatar,
  }) async {
    if (roomId != null && roomId.trim().isNotEmpty) {
      final Map<String, dynamic>? roomRow = await _client
          .from(_roomsTable)
          .select('id,room_hash')
          .eq('id', roomId)
          .maybeSingle();
      if (roomRow == null) {
        throw const ChatRepositoryException(
          'This conversation is no longer available.',
        );
      }
      final String roomHash = roomRow['room_hash']?.toString() ?? '';
      final String participantId = await _resolveParticipantId(
        roomId: roomId,
        currentUserId: currentUserId,
        roomHash: roomHash,
      );
      final String safeParticipantId = participantId.trim().isNotEmpty
          ? participantId
          : (userId ?? '');
      await _ensureRoomMembers(
        roomId: roomId,
        userIds: <String>[
          currentUserId,
          if (safeParticipantId.isNotEmpty) safeParticipantId,
        ],
      );

      final UserModel participant =
          safeParticipantId.isNotEmpty
          ? await _fetchRequiredProfile(
              safeParticipantId,
              fallbackName: receiverName,
              fallbackAvatarUrl: receiverAvatar,
            )
          : _fallbackUser(
              userId ?? roomId,
              fallbackName: receiverName,
              fallbackAvatarUrl: receiverAvatar,
            );

      return ChatThread(
        roomId: roomRow['id']?.toString() ?? roomId,
        roomHash: roomHash,
        participant: participant,
      );
    }

    if (userId != null && userId.trim().isNotEmpty) {
      if (userId == currentUserId) {
        throw const ChatRepositoryException(
          'You cannot start a chat with yourself.',
        );
      }
      return findOrCreateRoom(
        currentUserId: currentUserId,
        participantId: userId,
        participant: await _fetchRequiredProfile(
          userId,
          fallbackName: receiverName,
          fallbackAvatarUrl: receiverAvatar,
        ),
      );
    }

    throw const ChatRepositoryException('No chat target was provided.');
  }

  Stream<LocalFirstData<List<MessageModel>>> watchMessages({
    required String roomId,
    required String currentUserId,
  }) {
    final StreamController<LocalFirstData<List<MessageModel>>> controller =
        StreamController<LocalFirstData<List<MessageModel>>>();
    StreamSubscription<List<Map<String, dynamic>>>? messageSubscription;
    final Set<String> notifiedIncomingIds = <String>{};

    Future<void> emitCachedMessages() async {
      final List<MessageModel> cachedMessages = await _databaseService
          .getCachedMessages(roomId: roomId, currentUserId: currentUserId);

      if (cachedMessages.isNotEmpty && !controller.isClosed) {
        controller.add(
          LocalFirstData<List<MessageModel>>(
            data: cachedMessages,
            isFromCache: true,
          ),
        );
      }
    }

    Future<void> emitRealtimeMessages(List<Map<String, dynamic>> rows) async {
      final Set<String> senderIds = rows
          .map((Map<String, dynamic> row) => row['sender_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet();
      final Map<String, UserModel> senderMap = await _fetchProfilesByIds(
        senderIds,
      );

      final List<MessageModel> messages = rows
          .map(
            (Map<String, dynamic> row) => MessageModel.fromDatabase(
              row: row,
              currentUserId: currentUserId,
              senderName:
                  senderMap[row['sender_id']]?.fullName ?? 'Gracy User',
              senderUsername: senderMap[row['sender_id']]?.username,
              isOfficial: row['sender_id']?.toString() == botUserId,
            ),
          )
          .toList()
        ..sort(
          (MessageModel a, MessageModel b) => a.sentAt.compareTo(b.sentAt),
        );

      await _databaseService.cacheMessages(
        roomId: roomId,
        messages: messages,
        ownerId: currentUserId,
      );

      for (final MessageModel message in messages) {
        if (message.isMe || !notifiedIncomingIds.add(message.id)) {
          continue;
        }
        await LocalNotificationService.instance.showIncomingMessageNotification(
          title: 'New Message from ${message.senderName}',
          body: message.text,
        );
      }

      if (!controller.isClosed) {
        controller.add(LocalFirstData<List<MessageModel>>(data: messages));
      }
    }

    Future<void>(() async {
      try {
        await emitCachedMessages();
        messageSubscription = _client
            .from(_messagesTable)
            .stream(primaryKey: <String>['id'])
            .eq('room_id', roomId)
            .order('created_at')
            .map(
              (List<Map<String, dynamic>> rows) =>
                  rows
                      .map(
                        (Map<String, dynamic> row) =>
                            Map<String, dynamic>.from(row),
                      )
                      .toList(growable: false),
            )
            .listen(
              emitRealtimeMessages,
              onError: (Object error, StackTrace stackTrace) async {
                await emitCachedMessages();
              },
            );
      } catch (_) {
        await emitCachedMessages();
      }
    });

    controller.onCancel = () async {
      await messageSubscription?.cancel();
    };

    return controller.stream;
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final String resolvedSenderId = _client.auth.currentUser?.id ?? senderId;
    await _ensureRoomMembers(
      roomId: roomId,
      userIds: <String>[resolvedSenderId],
    );
    await _client.rpc(
      'send_message',
      params: <String, dynamic>{'p_room_id': roomId, 'p_content': trimmed},
    );
    try {
      final String roomHash = await _fetchRoomHash(roomId);
      final String recipientId = await _resolveParticipantId(
        roomId: roomId,
        currentUserId: resolvedSenderId,
        roomHash: roomHash,
      );
      if (recipientId.isNotEmpty) {
        await _client.from('notifications').insert(<String, dynamic>{
          'receiver_id': recipientId,
          'sender_id': resolvedSenderId,
          'type': 'message',
          'content': trimmed,
          'is_read': false,
        });
      }
    } catch (_) {
      // Keep message delivery independent from notification fan-out.
    }
  }

  Stream<LocalFirstData<List<ChatModel>>> watchRecentChats(
    String currentUserId,
  ) {
    final StreamController<LocalFirstData<List<ChatModel>>> controller =
        StreamController<LocalFirstData<List<ChatModel>>>();
    final Set<String> notifiedChatSignatures = <String>{};
    RealtimeChannel? channel;

    Future<void> emitCachedChats() async {
      final List<ChatModel> cached = await _databaseService
          .getCachedRecentChats(currentUserId);
      if (cached.isNotEmpty && !controller.isClosed) {
        controller.add(
          LocalFirstData<List<ChatModel>>(data: cached, isFromCache: true),
        );
      }
    }

    Future<void> refreshOnlineChats() async {
      try {
        final List<ChatModel> chats = await _fetchRecentChatsOnline(
          currentUserId,
        ).timeout(const Duration(seconds: 3));
        if (controller.isClosed) {
          return;
        }
        controller.add(LocalFirstData<List<ChatModel>>(data: chats));
        for (final ChatModel chat in chats) {
          if (chat.isLastMessageMine || chat.unreadCount <= 0) {
            continue;
          }
          final String signature =
              '${chat.id}:${chat.lastMessageAt.toIso8601String()}:${chat.unreadCount}';
          if (!notifiedChatSignatures.add(signature)) {
            continue;
          }
          await LocalNotificationService.instance.showIncomingMessageNotification(
            title: 'New Message from ${chat.gracyId ?? 'Gracy User'}',
            body: chat.lastMessage,
          );
        }
      } catch (_) {
        await emitCachedChats();
      }
    }

    Future<void>(() async {
      await emitCachedChats();
      await refreshOnlineChats();

      channel = _client.channel('public:recent_chats:$currentUserId');
      channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _messagesTable,
            callback: (_) async {
              await refreshOnlineChats();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _roomsTable,
            callback: (_) async {
              await refreshOnlineChats();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _chatMembersTable,
            callback: (_) async {
              await refreshOnlineChats();
            },
          )
          .subscribe();
    });

    controller.onCancel = () async {
      if (channel != null) {
        await _client.removeChannel(channel!);
      }
    };

    return controller.stream;
  }

  Future<List<ChatModel>> _fetchRecentChatsOnline(String currentUserId) async {
    final List<Map<String, dynamic>> roomRows = await _fetchRoomRowsForUser(
      currentUserId,
    );

    if (roomRows.isEmpty) {
      return const <ChatModel>[];
    }

    final List<String> roomIds = roomRows
        .map((Map<String, dynamic> row) => row['id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toList();
    final Set<String> participantIds = <String>{};

    for (final Map<String, dynamic> row in roomRows) {
      final String participantId = await _resolveParticipantId(
        roomId: row['id']?.toString() ?? '',
        currentUserId: currentUserId,
        roomHash: row['room_hash']?.toString() ?? '',
      );
      if (participantId.isNotEmpty) {
        participantIds.add(participantId);
      }
    }

    final Map<String, UserModel> participants = await _fetchProfilesByIds(
      participantIds,
    );
    final List<Map<String, dynamic>> messageRows = roomIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : ((await _client
                      .from(_messagesTable)
                      .select(
                        'id,room_id,sender_id,content,created_at,status,delivered_at,read_at,is_read',
                      )
                      .inFilter('room_id', roomIds)
                      .order('created_at', ascending: false))
                  as List<dynamic>)
              .map((dynamic row) => Map<String, dynamic>.from(row as Map))
              .toList();

    final Map<String, Map<String, dynamic>> latestByRoom =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row in messageRows) {
      final String roomId = row['room_id']?.toString() ?? '';
      latestByRoom.putIfAbsent(roomId, () => row);
    }

    final List<ChatModel> chats = <ChatModel>[];
    for (final Map<String, dynamic> row in roomRows) {
      final String roomId = row['id']?.toString() ?? '';
      final String roomHash = row['room_hash']?.toString() ?? '';
      final String participantId = await _resolveParticipantId(
        roomId: roomId,
        currentUserId: currentUserId,
        roomHash: roomHash,
      );
      final UserModel participant =
          participants[participantId] ?? _fallbackUser(participantId);
      final Map<String, dynamic>? latest = latestByRoom[roomId];
      final int unreadCount = messageRows
          .where((Map<String, dynamic> messageRow) {
            final bool isRead =
                messageRow['is_read'] == true ||
                messageRow['status']?.toString() == 'read';
            return messageRow['room_id']?.toString() == roomId &&
                messageRow['sender_id']?.toString() != currentUserId &&
                !isRead;
          })
          .length;

      chats.add(
        ChatModel(
          id: roomId,
          participantId: participantId,
          lastMessage:
              latest?['content']?.toString() ??
              (participant.id == botUserId
                  ? 'GracyAI: The Official Brain of Gracy ⚡'
                  : 'Start the conversation'),
          lastMessageAt:
              DateTime.tryParse(latest?['created_at']?.toString() ?? '') ??
              DateTime.now(),
          unreadCount: unreadCount,
          roomHash: roomHash,
          isOfficial: participant.id == botUserId,
          gracyId: participant.gracyId,
          isOnline: participant.isOnline,
          lastMessageStatus: _messageStatusFromRow(latest),
          isLastMessageMine: latest?['sender_id'] == currentUserId,
        ),
      );
    }

    chats.sort(
      (ChatModel a, ChatModel b) => b.lastMessageAt.compareTo(a.lastMessageAt),
    );
    await _databaseService.cacheRecentChats(chats, currentUserId);
    return chats;
  }

  Future<void> markMessagesAsRead({
    required String roomId,
    required String currentUserId,
    required String participantId,
  }) async {
    await _client
        .from(_messagesTable)
        .update({
          'status': 'read',
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('room_id', roomId)
        .eq('sender_id', participantId)
        .neq('status', 'read');
    await _databaseService.markCachedMessagesAsRead(
      roomId: roomId,
      ownerId: currentUserId,
      senderId: participantId,
    );
    await _databaseService.markRecentChatAsRead(
      roomId: roomId,
      ownerId: currentUserId,
    );
    try {
      await _client
          .from('notifications')
          .update(<String, dynamic>{'is_read': true})
          .eq('receiver_id', currentUserId)
          .eq('sender_id', participantId)
          .eq('type', 'message')
          .eq('is_read', false);
    } catch (_) {
      // Older environments may not rely on notifications rows for messages.
    }
  }

  Future<void> markMessagesAsDelivered({
    required String roomId,
    required String userId,
  }) async {
    await _client
        .from(_messagesTable)
        .update({
          'status': 'delivered',
          'delivered_at': DateTime.now().toIso8601String(),
        })
        .eq('room_id', roomId)
        .eq('sender_id', userId)
        .eq('status', 'sent');
  }

  Future<void> _ensureRoomMembers({
    required String roomId,
    required List<String> userIds,
  }) async {
    try {
      await _client
          .from(_chatMembersTable)
          .upsert(
            userIds
                .map(
                  (String userId) => <String, dynamic>{
                    'room_id': roomId,
                    'user_id': userId,
                  },
                )
                .toList(),
            onConflict: 'room_id,user_id',
          );
    } catch (_) {
      // Stay backward-compatible with deployments that still rely on room_hash only.
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRoomRowsForUser(
    String currentUserId,
  ) async {
    try {
      final List<dynamic> memberRows = await _client
          .from(_chatMembersTable)
          .select('room_id')
          .eq('user_id', currentUserId);

      final List<String> roomIds = memberRows
          .map(
            (dynamic row) =>
                Map<String, dynamic>.from(row as Map)['room_id']?.toString() ??
                '',
          )
          .where((String id) => id.isNotEmpty)
          .toList();

      if (roomIds.isEmpty) {
        return const <Map<String, dynamic>>[];
      }

      final List<dynamic> roomRows = await _client
          .from(_roomsTable)
          .select('id,room_hash')
          .inFilter('id', roomIds);

      return roomRows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      final List<dynamic> rawRoomRows = await _client
          .from(_roomsTable)
          .select('id,room_hash')
          .ilike('room_hash', '%$currentUserId%');

      return rawRoomRows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .where((Map<String, dynamic> row) {
            final String roomHash = row['room_hash']?.toString() ?? '';
            return roomHash.split('_').contains(currentUserId);
          })
          .toList();
    }
  }

  Future<String> _resolveParticipantId({
    required String roomId,
    required String currentUserId,
    required String roomHash,
  }) async {
    try {
      final List<dynamic> memberRows = await _client
          .from(_chatMembersTable)
          .select('user_id')
          .eq('room_id', roomId);
      final List<String> memberIds = memberRows
          .map(
            (dynamic row) =>
                Map<String, dynamic>.from(row as Map)['user_id']?.toString() ??
                '',
          )
          .where((String id) => id.isNotEmpty)
          .toList();

      final String participantId = memberIds.firstWhere(
        (String id) => id != currentUserId,
        orElse: () => '',
      );

      if (participantId.isNotEmpty) {
        return participantId;
      }
    } catch (_) {
      // Fall back to room_hash parsing for older environments.
    }

    return _otherParticipantId(
      roomHash: roomHash,
      currentUserId: currentUserId,
    );
  }

  Future<UserModel> _fetchRequiredProfile(
    String userId, {
    String? fallbackName,
    String? fallbackAvatarUrl,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from(_profilesTable)
          .select('id,username,gracy_id,full_name,avatar_url,is_online')
          .eq('id', userId)
          .single();
      return _userFromProfile(row);
    } catch (_) {
      return _fallbackUser(
        userId,
        fallbackName: fallbackName,
        fallbackAvatarUrl: fallbackAvatarUrl,
      );
    }
  }

  Future<String> _fetchRoomHash(String roomId) async {
    final Map<String, dynamic>? row = await _client
        .from(_roomsTable)
        .select('room_hash')
        .eq('id', roomId)
        .maybeSingle();
    return row?['room_hash']?.toString() ?? '';
  }

  Future<Map<String, UserModel>> _fetchProfilesByIds(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return const <String, UserModel>{};
    }

    final List<dynamic> rawRows = await _client
        .from(_profilesTable)
        .select('id,username,gracy_id,full_name,avatar_url,is_online')
        .inFilter('id', userIds.toList());

    final List<Map<String, dynamic>> rows = rawRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList();

    return <String, UserModel>{
      for (final Map<String, dynamic> row in rows)
        row['id']?.toString() ?? '': _userFromProfile(row),
    };
  }

  String _otherParticipantId({
    required String roomHash,
    required String currentUserId,
  }) {
    final List<String> ids = roomHash
        .split('_')
        .where((String value) => value.isNotEmpty)
        .toList();
    return ids.firstWhere((String id) => id != currentUserId, orElse: () => '');
  }

  UserModel _userFromProfile(Map<String, dynamic> row) {
    final String username = row['username']?.toString() ?? 'gracyuser';
    final String fullName =
        row['full_name']?.toString().trim().isNotEmpty == true
        ? row['full_name'].toString().trim()
        : username;
    final String? gracyId =
        row['gracy_id']?.toString().trim().isNotEmpty == true
        ? row['gracy_id'].toString().trim()
        : null;
    final String? avatarUrl =
        row['avatar_url']?.toString().trim().isNotEmpty == true
        ? row['avatar_url'].toString().trim()
        : null;

    return UserModel(
      id: row['id']?.toString() ?? '',
      fullName: fullName,
      username: username.startsWith('@') ? username : '@$username',
      age: 0,
      role: UserRole.student,
      courses: gracyId == null ? const <String>[] : <String>[gracyId],
      bio: gracyId == null ? 'Gracy member' : 'Gracy code: $gracyId',
      isOnline: row['is_online'] == true,
      location: 'Gracy network',
      avatarSeed: fullName,
      year: 'Active',
      avatarUrl: avatarUrl,
      gracyId: gracyId,
    );
  }

  UserModel _fallbackUser(
    String userId, {
    String? fallbackName,
    String? fallbackAvatarUrl,
  }) {
    final String shortId = userId.length >= 6 ? userId.substring(0, 6) : userId;
    final String resolvedName =
        fallbackName?.trim().isNotEmpty == true
        ? fallbackName!.trim()
        : 'Gracy User';
    return UserModel(
      id: userId,
      fullName: resolvedName,
      username: '@$shortId',
      age: 0,
      role: UserRole.student,
      courses: const <String>[],
      bio: 'Gracy member',
      isOnline: false,
      location: 'Gracy network',
      avatarSeed: resolvedName,
      year: 'Active',
      avatarUrl: fallbackAvatarUrl,
    );
  }

  MessageStatus _messageStatusFromRow(Map<String, dynamic>? row) {
    final String status = row?['status']?.toString() ?? 'sent';
    return switch (status) {
      'pending' => MessageStatus.pending,
      'read' => MessageStatus.read,
      'delivered' => MessageStatus.delivered,
      _ => MessageStatus.sent,
    };
  }

  UserModel _createGracyAiBot() {
    return UserModel(
      id: botUserId,
      fullName: 'GracyAI',
      username: '@gracyai',
      age: 0,
      role: UserRole.staff,
      courses: const <String>[],
      bio: 'The Official Brain of Gracy. Powered by Gemini 1.5 Pro.',
      isOnline: true,
      location: 'Digital Campus',
      avatarSeed: 'GracyAI',
      year: 'Always Active',
      gracyId: botGracyCode,
    );
  }
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

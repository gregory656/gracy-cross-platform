import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/chat_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';

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
  ChatRepository(this._client);

  static const String botUserId = 'd9660385-2c30-466d-8902-602868198f82';
  static const String botGracyCode = 'GRACY-BOT-99';

  static const String _profilesTable = 'profiles';
  static const String _roomsTable = 'chat_rooms';
  static const String _messagesTable = 'messages';

  final SupabaseClient _client;

  String buildRoomHash(String myId, String friendId) {
    final List<String> ids = <String>[myId, friendId]..sort();
    return ids.join('_');
  }

  Future<UserModel?> findProfileByGracyCode(String gracyId) async {
    final String normalizedCode = gracyId.trim();
    if (normalizedCode.isEmpty) {
      return null;
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
      throw const ChatRepositoryException('No profile was found for that Gracy code.');
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
      throw const ChatRepositoryException('You cannot start a chat with yourself.');
    }

    final String roomHash = buildRoomHash(currentUserId, participantId);
    final Map<String, dynamic> roomRow = await _client
        .from(_roomsTable)
        .upsert(<String, dynamic>{'room_hash': roomHash}, onConflict: 'room_hash')
        .select('id,room_hash')
        .single();

    final UserModel resolvedParticipant =
        participant ?? await _fetchRequiredProfile(participantId);

    return ChatThread(
      roomId: roomRow['id']?.toString() ?? '',
      roomHash: roomRow['room_hash']?.toString() ?? roomHash,
      participant: resolvedParticipant,
    );
  }

  Future<ChatThread> resolveThread({
    required String currentUserId,
    String? roomId,
    String? userId,
  }) async {
    if (roomId != null && roomId.trim().isNotEmpty) {
      final Map<String, dynamic> roomRow =
          await _client.from(_roomsTable).select('id,room_hash').eq('id', roomId).single();
      final String roomHash = roomRow['room_hash']?.toString() ?? '';
      final String participantId = roomHash
          .split('_')
          .where((String id) => id.isNotEmpty && id != currentUserId)
          .first;

      return ChatThread(
        roomId: roomRow['id']?.toString() ?? roomId,
        roomHash: roomHash,
        participant: await _fetchRequiredProfile(participantId),
      );
    }

    if (userId != null && userId.trim().isNotEmpty) {
      return findOrCreateRoom(
        currentUserId: currentUserId,
        participantId: userId,
      );
    }

    throw const ChatRepositoryException('No chat target was provided.');
  }

  Stream<List<MessageModel>> watchMessages({
    required String roomId,
    required String currentUserId,
  }) {
    final StreamController<List<MessageModel>> controller =
        StreamController<List<MessageModel>>();
    final Map<String, Map<String, dynamic>> messageRowsById =
        <String, Map<String, dynamic>>{};

    Future<void> emitMessages() async {
      final List<Map<String, dynamic>> rows = messageRowsById.values.toList()
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final DateTime aTime =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
          final DateTime bTime =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
          return aTime.compareTo(bTime);
        });

      final Set<String> senderIds = rows
          .map((Map<String, dynamic> row) => row['sender_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet();
      final Map<String, UserModel> senderMap = await _fetchProfilesByIds(senderIds);

      final List<MessageModel> messages = rows
          .map(
            (Map<String, dynamic> row) => MessageModel.fromDatabase(
              row: row,
              currentUserId: currentUserId,
              senderName: senderMap[row['sender_id']]?.fullName ?? 'Gracy User',
              senderUsername: senderMap[row['sender_id']]?.username,
              isOfficial: row['sender_id']?.toString() == botUserId,
            ),
          )
          .toList();

      if (!controller.isClosed) {
        controller.add(messages);
      }
    }

    Future<void> hydrateInitialMessages() async {
      final List<dynamic> rows = await _client
          .from(_messagesTable)
          .select('id,room_id,sender_id,content,created_at')
          .eq('room_id', roomId)
          .order('created_at');

      for (final dynamic row in rows) {
        final Map<String, dynamic> parsedRow =
            Map<String, dynamic>.from(row as Map);
        final String id = parsedRow['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          messageRowsById[id] = parsedRow;
        }
      }

      await emitMessages();
    }

    final RealtimeChannel channel = _client.channel('public:messages:$roomId');

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: _messagesTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (PostgresChangePayload change) async {
        final Map<String, dynamic> newRecord = change.newRecord;
        final String id = newRecord['id']?.toString() ?? '';
        if (id.isEmpty) {
          return;
        }

        messageRowsById[id] = newRecord;
        if (!controller.isClosed) {
          await emitMessages();
        }
      },
    )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
      if (status == RealtimeSubscribeStatus.channelError && !controller.isClosed) {
        controller.addError(error ?? 'Realtime channel error');
      }
    });

    Future<void>(() async {
      try {
        await hydrateInitialMessages();
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    });

    controller.onCancel = () async {
      await _client.removeChannel(channel);
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

    await _client.from(_messagesTable).insert(
      <String, dynamic>{
        'room_id': roomId,
        'sender_id': senderId,
        'content': trimmed,
      },
    );
  }

  Future<List<ChatModel>> fetchRecentChats(String currentUserId) async {
    final List<dynamic> rawRoomRows = await _client
        .from(_roomsTable)
        .select('id,room_hash')
        .ilike('room_hash', '%$currentUserId%');

    final List<Map<String, dynamic>> roomRows = rawRoomRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .where((Map<String, dynamic> row) {
      final String roomHash = row['room_hash']?.toString() ?? '';
      return roomHash.split('_').contains(currentUserId);
    }).toList();

    if (roomRows.isEmpty) {
      return const <ChatModel>[];
    }

    final List<String> roomIds = roomRows
        .map((Map<String, dynamic> row) => row['id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toList();
    final Set<String> participantIds = roomRows
        .map((Map<String, dynamic> row) => _otherParticipantId(
              roomHash: row['room_hash']?.toString() ?? '',
              currentUserId: currentUserId,
            ))
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Map<String, UserModel> participants = await _fetchProfilesByIds(participantIds);
    final List<Map<String, dynamic>> messageRows = roomIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : ((await _client
                    .from(_messagesTable)
                    .select('id,room_id,sender_id,content,created_at')
                    .inFilter('room_id', roomIds)
                    .order('created_at', ascending: false))
                as List<dynamic>)
            .map((dynamic row) => Map<String, dynamic>.from(row as Map))
            .toList();

    final Map<String, Map<String, dynamic>> latestByRoom = <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row in messageRows) {
      final String roomId = row['room_id']?.toString() ?? '';
      latestByRoom.putIfAbsent(roomId, () => row);
    }

    final List<ChatModel> chats = roomRows.map((Map<String, dynamic> row) {
      final String roomId = row['id']?.toString() ?? '';
      final String roomHash = row['room_hash']?.toString() ?? '';
      final String participantId =
          _otherParticipantId(roomHash: roomHash, currentUserId: currentUserId);
      final UserModel? participant = participants[participantId];
      final Map<String, dynamic>? latest = latestByRoom[roomId];

      return ChatModel(
        id: roomId,
        participantId: participantId,
        lastMessage: latest?['content']?.toString() ??
            (participant?.id == botUserId ? 'Official Gracy bot is ready.' : 'Start the conversation'),
        lastMessageAt:
            DateTime.tryParse(latest?['created_at']?.toString() ?? '') ?? DateTime.now(),
        unreadCount: 0,
        roomHash: roomHash,
        isOfficial: participant?.id == botUserId,
        gracyId: participant?.gracyId,
        isOnline: participant?.isOnline ?? false,
      );
    }).toList()
      ..sort((ChatModel a, ChatModel b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    return chats;
  }

  Future<UserModel> _fetchRequiredProfile(String userId) async {
    final Map<String, dynamic> row = await _client
        .from(_profilesTable)
        .select('id,username,gracy_id,full_name,avatar_url,is_online')
        .eq('id', userId)
        .single();
    return _userFromProfile(row);
  }

  Future<Map<String, UserModel>> _fetchProfilesByIds(Set<String> userIds) async {
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
      for (final Map<String, dynamic> row in rows) row['id']?.toString() ?? '': _userFromProfile(row),
    };
  }

  String _otherParticipantId({
    required String roomHash,
    required String currentUserId,
  }) {
    final List<String> ids = roomHash.split('_').where((String value) => value.isNotEmpty).toList();
    return ids.firstWhere(
      (String id) => id != currentUserId,
      orElse: () => '',
    );
  }

  UserModel _userFromProfile(Map<String, dynamic> row) {
    final String username = row['username']?.toString() ?? 'gracyuser';
    final String fullName = row['full_name']?.toString().trim().isNotEmpty == true
        ? row['full_name'].toString().trim()
        : username;
    final String? gracyId = row['gracy_id']?.toString().trim().isNotEmpty == true
        ? row['gracy_id'].toString().trim()
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
      gracyId: gracyId,
    );
  }
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

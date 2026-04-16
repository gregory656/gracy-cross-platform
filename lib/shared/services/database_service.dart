import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _appMetaTable = 'app_meta';
  static const String _contactsTable = 'contacts';
  static const String _legacyMessagesTable = 'messages';
  static const String _chatCacheTable = 'chat_message_cache';
  static const String _postsCacheTable = 'posts_cache';
  static const String _profilesCacheTable = 'profiles_cache';
  static const String _recentChatsCacheTable = 'recent_chats_cache';

  Database? _database;

  Future<Database> initialize() async {
    if (_database != null) {
      return _database!;
    }

    final String databasesPath = await getDatabasesPath();
    final String dbPath = p.join(databasesPath, 'gracy_local.db');

    _database = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (Database db, int version) async {
        await _createBaseTables(db);
        await _createChatCacheTable(db);
        await _createPostCacheTable(db);
        await _createProfilesCacheTable(db);
        await _createRecentChatsCacheTable(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_appMetaTable (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 3) {
          await _createChatCacheTable(db);
        }

        if (oldVersion < 4) {
          await _createPostCacheTable(db);
          await _createProfilesCacheTable(db);
          await _createRecentChatsCacheTable(db);
        }
        
        if (oldVersion < 5) {
          await db.execute('DROP TABLE IF EXISTS $_chatCacheTable');
          await db.execute('DROP TABLE IF EXISTS $_postsCacheTable');
          await db.execute('DROP TABLE IF EXISTS $_profilesCacheTable');
          await db.execute('DROP TABLE IF EXISTS $_recentChatsCacheTable');
          
          await _createChatCacheTable(db);
          await _createPostCacheTable(db);
          await _createProfilesCacheTable(db);
          await _createRecentChatsCacheTable(db);
        }
        
        if (oldVersion < 6) {
          await db.execute('DROP TABLE IF EXISTS $_chatCacheTable');
          await db.execute('DROP TABLE IF EXISTS $_postsCacheTable');
          await db.execute('DROP TABLE IF EXISTS $_profilesCacheTable');
          await db.execute('DROP TABLE IF EXISTS $_recentChatsCacheTable');
          
          await _createChatCacheTable(db);
          await _createPostCacheTable(db);
          await _createProfilesCacheTable(db);
          await _createRecentChatsCacheTable(db);
        }
      },
    );

    return _database!;
  }

  Future<Database> get database async {
    return initialize();
  }

  Future<bool> isOnboardingComplete() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _appMetaTable,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>['onboarding_complete'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    return rows.first['value'] == 'true';
  }

  Future<void> setOnboardingComplete(bool value) async {
    final Database db = await database;
    await db.insert(_appMetaTable, <String, Object?>{
      'key': 'onboarding_complete',
      'value': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MessageModel>> getCachedMessages({
    required String roomId,
    required String currentUserId,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _chatCacheTable,
      where: 'room_id = ? AND owner_id = ?',
      whereArgs: <Object?>[roomId, currentUserId],
      orderBy: 'created_at ASC',
    );

    return rows.map((Map<String, Object?> row) {
      final String senderId = row['sender_id']?.toString() ?? '';
      return MessageModel(
        id: row['message_id']?.toString() ?? '',
        chatId: row['room_id']?.toString() ?? roomId,
        senderId: senderId,
        text: row['content']?.toString() ?? '',
        sentAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        isMe: senderId == currentUserId,
        senderName: row['sender_name']?.toString() ?? 'Gracy User',
        senderUsername: row['sender_username']?.toString(),
        isOfficial: (row['is_official'] as int? ?? 0) == 1,
        status: _messageStatusFromString(row['status']?.toString()),
        isPending: row['status']?.toString() == 'pending',
      );
    }).toList();
  }

  Future<void> cacheMessages({
    required String roomId,
    required List<MessageModel> messages,
    required String ownerId,
  }) async {
    final Database db = await database;
    final Batch batch = db.batch();

    for (final MessageModel message in messages) {
      batch.insert(_chatCacheTable, <String, Object?>{
        'message_id': message.id,
        'room_id': roomId,
        'owner_id': ownerId,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'sender_username': message.senderUsername,
        'content': message.text,
        'created_at': message.sentAt.toIso8601String(),
        'is_official': message.isOfficial ? 1 : 0,
        'status': message.status.name,
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearCachedMessages(String roomId, String ownerId) async {
    final Database db = await database;
    await db.delete(
      _chatCacheTable,
      where: 'room_id = ? AND owner_id = ?',
      whereArgs: <Object?>[roomId, ownerId],
    );
  }

  Future<List<PostModel>> getCachedPosts(String ownerId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _postsCacheTable,
      where: 'owner_id = ?',
      whereArgs: <Object?>[ownerId],
      orderBy: 'created_at DESC',
    );

    return rows.map(_postFromRow).toList();
  }

  Future<PostModel?> getCachedPostById(String postId, String ownerId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _postsCacheTable,
      where: 'post_id = ? AND owner_id = ?',
      whereArgs: <Object?>[postId, ownerId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _postFromRow(rows.first);
  }

  Future<List<PostModel>> getCachedPostsByAuthor(String authorId, String ownerId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _postsCacheTable,
      where: 'author_id = ? AND owner_id = ?',
      whereArgs: <Object?>[authorId, ownerId],
      orderBy: 'created_at DESC',
    );

    return rows.map(_postFromRow).toList();
  }

  Future<void> cachePosts(List<PostModel> posts, String ownerId) async {
    final Database db = await database;
    final Batch batch = db.batch();

    for (final PostModel post in posts) {
      batch.insert(_postsCacheTable, <String, Object?>{
        'post_id': post.id,
        'owner_id': ownerId,
        'author_id': post.authorId,
        'content': post.content,
        'image_url': post.imageUrl,
        'likes_count': post.likesCount,
        'comments_count': post.commentsCount,
        'view_count': post.viewCount,
        'created_at': post.createdAt.toIso8601String(),
        'updated_at': post.updatedAt?.toIso8601String(),
        'author_name': post.authorName,
        'author_avatar': post.authorAvatar,
        'is_liked_by_current_user': post.isLikedByCurrentUser ? 1 : 0,
        'likes_visible': post.likesVisible ? 1 : 0,
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<void> cacheProfiles(List<UserModel> profiles, String ownerId) async {
    final Database db = await database;
    final Batch batch = db.batch();

    for (final UserModel profile in profiles) {
      batch.insert(_profilesCacheTable, <String, Object?>{
        'profile_id': profile.id,
        'owner_id': ownerId,
        'full_name': profile.fullName,
        'username': profile.username,
        'bio': profile.bio,
        'year_of_study': profile.year,
        'avatar_url': profile.avatarUrl,
        'gracy_id': profile.gracyId,
        'is_online': profile.isOnline ? 1 : 0,
        'selected_theme': profile.selectedTheme,
        'notifications_enabled': profile.notificationsEnabled ? 1 : 0,
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<UserModel>> getCachedProfiles(String ownerId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _profilesCacheTable,
      where: 'owner_id = ?',
      whereArgs: <Object?>[ownerId],
      orderBy: 'lower(username) ASC',
    );

    return rows.map(_userFromRow).toList();
  }

  Future<void> cacheRecentChats(List<ChatModel> chats, String ownerId) async {
    final Database db = await database;
    final Batch batch = db.batch();

    for (final ChatModel chat in chats) {
      batch.insert(_recentChatsCacheTable, <String, Object?>{
        'room_id': chat.id,
        'owner_id': ownerId,
        'participant_id': chat.participantId,
        'last_message': chat.lastMessage,
        'last_message_at': chat.lastMessageAt.toIso8601String(),
        'unread_count': chat.unreadCount,
        'room_hash': chat.roomHash,
        'is_official': chat.isOfficial ? 1 : 0,
        'gracy_id': chat.gracyId,
        'is_online': chat.isOnline ? 1 : 0,
        'last_message_status': chat.lastMessageStatus.name,
        'is_last_message_mine': chat.isLastMessageMine ? 1 : 0,
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<ChatModel>> getCachedRecentChats(String ownerId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _recentChatsCacheTable,
      where: 'owner_id = ?',
      whereArgs: <Object?>[ownerId],
      orderBy: 'last_message_at DESC',
    );

    return rows.map((Map<String, Object?> row) {
      return ChatModel(
        id: row['room_id']?.toString() ?? '',
        participantId: row['participant_id']?.toString() ?? '',
        lastMessage: row['last_message']?.toString() ?? '',
        lastMessageAt:
            DateTime.tryParse(row['last_message_at']?.toString() ?? '') ??
            DateTime.now(),
        unreadCount: (row['unread_count'] as int?) ?? 0,
        roomHash: row['room_hash']?.toString(),
        isOfficial: (row['is_official'] as int? ?? 0) == 1,
        gracyId: row['gracy_id']?.toString(),
        isOnline: (row['is_online'] as int? ?? 0) == 1,
        lastMessageStatus: _messageStatusFromString(
          row['last_message_status']?.toString(),
        ),
        isLastMessageMine: (row['is_last_message_mine'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  Future<void> _createBaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_appMetaTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_contactsTable (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        username TEXT,
        avatar_seed TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_legacyMessagesTable (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        body TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        is_sent INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createChatCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_chatCacheTable (
        message_id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        sender_username TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_official INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'sent',
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_message_cache_room_created
      ON $_chatCacheTable (room_id, created_at)
    ''');
  }

  Future<void> _createPostCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_postsCacheTable (
        post_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        author_id TEXT NOT NULL,
        content TEXT,
        image_url TEXT,
        likes_count INTEGER NOT NULL DEFAULT 0,
        comments_count INTEGER NOT NULL DEFAULT 0,
        view_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        author_name TEXT,
        author_avatar TEXT,
        is_liked_by_current_user INTEGER NOT NULL DEFAULT 0,
        likes_visible INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createProfilesCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_profilesCacheTable (
        profile_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL,
        bio TEXT,
        year_of_study TEXT,
        avatar_url TEXT,
        gracy_id TEXT,
        is_online INTEGER NOT NULL DEFAULT 0,
        selected_theme TEXT,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRecentChatsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_recentChatsCacheTable (
        room_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        participant_id TEXT NOT NULL,
        last_message TEXT NOT NULL,
        last_message_at TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        room_hash TEXT,
        is_official INTEGER NOT NULL DEFAULT 0,
        gracy_id TEXT,
        is_online INTEGER NOT NULL DEFAULT 0,
        last_message_status TEXT,
        is_last_message_mine INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  PostModel _postFromRow(Map<String, Object?> row) {
    return PostModel(
      id: row['post_id']?.toString() ?? '',
      authorId: row['author_id']?.toString() ?? '',
      imageUrl: row['image_url']?.toString(),
      content: row['content']?.toString() ?? '',
      likesCount: (row['likes_count'] as int?) ?? 0,
      commentsCount: (row['comments_count'] as int?) ?? 0,
      viewCount: (row['view_count'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.tryParse(row['updated_at']!.toString()),
      authorName: row['author_name']?.toString(),
      authorAvatar: row['author_avatar']?.toString(),
      isLikedByCurrentUser: (row['is_liked_by_current_user'] as int? ?? 0) == 1,
      likesVisible: (row['likes_visible'] as int? ?? 1) == 1,
    );
  }

  UserModel _userFromRow(Map<String, Object?> row) {
    final String username = row['username']?.toString() ?? 'gracyuser';
    final String fullName = row['full_name']?.toString() ?? username;

    return UserModel(
      id: row['profile_id']?.toString() ?? '',
      fullName: fullName,
      username: username.startsWith('@') ? username : '@$username',
      age: 0,
      role: UserRole.student,
      courses: row['gracy_id'] == null
          ? const <String>['Gracy member']
          : <String>[row['gracy_id']!.toString()],
      bio: row['bio']?.toString() ?? 'No bio yet.',
      isOnline: (row['is_online'] as int? ?? 0) == 1,
      location: 'Gracy network',
      avatarSeed: username,
      year: row['year_of_study']?.toString() ?? 'Not set',
      avatarUrl: row['avatar_url']?.toString(),
      gracyId: row['gracy_id']?.toString(),
      selectedTheme: row['selected_theme']?.toString() ?? 'midnight',
      notificationsEnabled:
          (row['notifications_enabled'] as int? ?? 1) == 1,
    );
  }

  MessageStatus _messageStatusFromString(String? value) {
    return switch (value) {
      'read' => MessageStatus.read,
      'delivered' => MessageStatus.delivered,
      _ => MessageStatus.sent,
    };
  }
}

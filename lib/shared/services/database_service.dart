import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/message_model.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _appMetaTable = 'app_meta';
  static const String _contactsTable = 'contacts';
  static const String _legacyMessagesTable = 'messages';
  static const String _chatCacheTable = 'chat_message_cache';

  Database? _database;

  Future<Database> initialize() async {
    if (_database != null) {
      return _database!;
    }

    final String databasesPath = await getDatabasesPath();
    final String dbPath = p.join(databasesPath, 'gracy_local.db');

    _database = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (Database db, int version) async {
        await _createBaseTables(db);
        await _createChatCacheTable(db);
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
    await db.insert(
      _appMetaTable,
      <String, Object?>{
        'key': 'onboarding_complete',
        'value': value.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getCachedMessages({
    required String roomId,
    required String currentUserId,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _chatCacheTable,
      where: 'room_id = ?',
      whereArgs: <Object?>[roomId],
      orderBy: 'created_at ASC',
    );

    return rows.map((Map<String, Object?> row) {
      final String senderId = row['sender_id']?.toString() ?? '';
      return MessageModel(
        id: row['message_id']?.toString() ?? '',
        chatId: row['room_id']?.toString() ?? roomId,
        senderId: senderId,
        text: row['content']?.toString() ?? '',
        sentAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        isMe: senderId == currentUserId,
        senderName: row['sender_name']?.toString() ?? 'Gracy User',
        senderUsername: row['sender_username']?.toString(),
        isOfficial: (row['is_official'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  Future<void> cacheMessages({
    required String roomId,
    required List<MessageModel> messages,
  }) async {
    final Database db = await database;
    final Batch batch = db.batch();

    for (final MessageModel message in messages) {
      batch.insert(
        _chatCacheTable,
        <String, Object?>{
          'message_id': message.id,
          'room_id': roomId,
          'sender_id': message.senderId,
          'sender_name': message.senderName,
          'sender_username': message.senderUsername,
          'content': message.text,
          'created_at': message.sentAt.toIso8601String(),
          'is_official': message.isOfficial ? 1 : 0,
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearCachedMessages(String roomId) async {
    final Database db = await database;
    await db.delete(
      _chatCacheTable,
      where: 'room_id = ?',
      whereArgs: <Object?>[roomId],
    );
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
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        sender_username TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_official INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_message_cache_room_created
      ON $_chatCacheTable (room_id, created_at)
    ''');
  }
}

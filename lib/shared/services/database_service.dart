import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> initialize() async {
    if (_database != null) {
      return _database!;
    }

    final String databasesPath = await getDatabasesPath();
    final String dbPath = p.join(databasesPath, 'gracy_local.db');

    _database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE contacts (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            username TEXT,
            avatar_seed TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            body TEXT NOT NULL,
            sent_at TEXT NOT NULL,
            is_sent INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
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
      'app_meta',
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
      'app_meta',
      <String, Object?>{
        'key': 'onboarding_complete',
        'value': value.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

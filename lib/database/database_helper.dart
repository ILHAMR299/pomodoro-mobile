import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getDatabasesPath();
    _database = await openDatabase(
      p.join(directory, 'teman_fokus.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            id INTEGER PRIMARY KEY,
            current_user_id INTEGER NULL
          )
        ''');
        await db.insert('app_settings', {'id': 1, 'current_user_id': null});
      },
    );
    return _database!;
  }

  Future<Map<String, Object?>?> userByEmail(String email) async {
    final rows = await (await database).query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> userById(int id) async {
    final rows = await (await database).query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertUser(Map<String, Object?> values) async =>
      (await database).insert('users', values);

  Future<int> insertUserAndSetSession(Map<String, Object?> values) async {
    final db = await database;
    return db.transaction((transaction) async {
      final id = await transaction.insert('users', values);
      await transaction.insert(
        'app_settings',
        {'id': 1, 'current_user_id': id},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    });
  }

  Future<int?> currentUserId() async {
    final rows = await (await database).query(
      'app_settings',
      columns: ['current_user_id'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['current_user_id'] as int?;
  }

  Future<void> setCurrentUser(int? id) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'id': 1, 'current_user_id': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

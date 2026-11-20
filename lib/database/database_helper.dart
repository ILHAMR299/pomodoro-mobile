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
      version: 5,
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
            current_user_id INTEGER NULL,
            notifications_enabled INTEGER NOT NULL DEFAULT 1,
            default_reminder_minutes INTEGER NOT NULL DEFAULT 60
          )
        ''');
        await db.insert('app_settings', {'id': 1, 'current_user_id': null});
        await _createTaskTables(db);
        await _createFocusSessionTable(db);
        await _createAppBlockingTables(db);
        await _addPomodoroStartedAt(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE app_settings ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE app_settings ADD COLUMN default_reminder_minutes INTEGER NOT NULL DEFAULT 60',
          );
          await _createTaskTables(db);
        }
        if (oldVersion < 3) await _createFocusSessionTable(db);
        if (oldVersion < 4) await _createAppBlockingTables(db);
        if (oldVersion < 5) await _addPomodoroStartedAt(db);
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

  Future<int> insertUserAndSetSession(Map<String, Object?> values) async {
    final db = await database;
    return db.transaction((transaction) async {
      final id = await transaction.insert('users', values);
      await transaction.insert('app_settings', {
        'id': 1,
        'current_user_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    await db.insert('app_settings', {
      'id': 1,
      'current_user_id': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> createTask(
    Map<String, Object?> values, {
    required int reminderMinutes,
    required int notificationId,
  }) async {
    final db = await database;
    return db.transaction((transaction) async {
      final taskId = await transaction.insert('tasks', values);
      await transaction.insert('task_reminders', {
        'task_id': taskId,
        'reminder_minutes': reminderMinutes,
        'notification_id': notificationId,
        'is_enabled': reminderMinutes > 0 ? 1 : 0,
      });
      return taskId;
    });
  }

  Future<void> updateTask(
    Map<String, Object?> values, {
    required int taskId,
    required int userId,
    required int reminderMinutes,
    required int notificationId,
  }) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.update(
        'tasks',
        values,
        where: 'id = ? AND user_id = ?',
        whereArgs: [taskId, userId],
      );
      await transaction.delete(
        'task_reminders',
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      await transaction.insert('task_reminders', {
        'task_id': taskId,
        'reminder_minutes': reminderMinutes,
        'notification_id': notificationId,
        'is_enabled': reminderMinutes > 0 ? 1 : 0,
      });
    });
  }

  Future<List<Map<String, Object?>>> tasksForUser(int userId) async =>
      (await database).rawQuery(
        '''
        SELECT t.*, COALESCE(r.reminder_minutes, 0) AS reminder_minutes
        FROM tasks t LEFT JOIN task_reminders r ON r.task_id = t.id
        WHERE t.user_id = ?
        ORDER BY t.is_completed ASC, t.deadline ASC
      ''',
        [userId],
      );

  Future<Map<String, Object?>?> taskById(int taskId, int userId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT t.*, COALESCE(r.reminder_minutes, 0) AS reminder_minutes
      FROM tasks t LEFT JOIN task_reminders r ON r.task_id = t.id
      WHERE t.id = ? AND t.user_id = ? LIMIT 1
    ''',
      [taskId, userId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> remindersForUser(int userId) async =>
      (await database).rawQuery(
        '''
        SELECT r.*, t.deadline, t.title, t.is_completed
        FROM task_reminders r JOIN tasks t ON t.id = r.task_id
        WHERE t.user_id = ?
      ''',
        [userId],
      );

  Future<List<Map<String, Object?>>> remindersForTask(int taskId) async =>
      (await database).query(
        'task_reminders',
        where: 'task_id = ?',
        whereArgs: [taskId],
      );

  Future<List<Map<String, Object?>>> allReminders() async =>
      (await database).query('task_reminders');

  Future<int> recordFocusSession({
    required int userId,
    required int durationMinutes,
    required DateTime completedAt,
  }) async => (await database).insert('focus_sessions', {
    'user_id': userId,
    'duration_minutes': durationMinutes,
    'completed_at': completedAt.toIso8601String(),
  });

  Future<List<Map<String, Object?>>> focusSessionsForUser(int userId) async =>
      (await database).query(
        'focus_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'completed_at DESC',
      );

  Future<List<Map<String, Object?>>> blockedApplications(int userId) async =>
      (await database).query(
        'blocked_applications',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'app_name COLLATE NOCASE',
      );

  Future<void> setBlockedApplication({
    required int userId,
    required String packageName,
    required String appName,
    required bool enabled,
  }) async {
    final db = await database;
    if (enabled) {
      await db.insert('blocked_applications', {
        'user_id': userId,
        'package_name': packageName,
        'app_name': appName,
        'is_enabled': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update(
        'blocked_applications',
        {'is_enabled': 0, 'app_name': appName},
        where: 'user_id = ? AND package_name = ?',
        whereArgs: [userId, packageName],
      );
    }
  }

  Future<Map<String, Object?>> appBlockingSettings(int userId) async {
    final rows = await (await database).query(
      'app_blocking_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty
        ? {'is_enabled': 0, 'block_during_breaks': 0}
        : rows.first;
  }

  Future<void> updateAppBlockingSettings({
    required int userId,
    required bool enabled,
    required bool blockDuringBreaks,
  }) async => (await database).insert('app_blocking_settings', {
    'user_id': userId,
    'is_enabled': enabled ? 1 : 0,
    'block_during_breaks': blockDuringBreaks ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, Object?>?> pomodoroState(int userId) async {
    final rows = await (await database).query(
      'pomodoro_states',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> savePomodoroState({
    required int userId,
    required String status,
    required String sessionType,
    required int remainingSeconds,
    required int totalSeconds,
    required int? endsAtEpochMillis,
    required int? sessionStartedAtEpochMillis,
    required int focusMinutes,
    required int breakMinutes,
    required int completedFocusSessions,
  }) async => (await database).insert('pomodoro_states', {
    'user_id': userId,
    'status': status,
    'session_type': sessionType,
    'remaining_seconds': remainingSeconds,
    'total_seconds': totalSeconds,
    'ends_at_epoch_ms': endsAtEpochMillis,
    'session_started_at_epoch_ms': sessionStartedAtEpochMillis,
    'focus_minutes': focusMinutes,
    'break_minutes': breakMinutes,
    'completed_focus_sessions': completedFocusSessions,
    'updated_at_epoch_ms': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteTask(int taskId, int userId) async =>
      (await database).delete(
        'tasks',
        where: 'id = ? AND user_id = ?',
        whereArgs: [taskId, userId],
      );

  Future<void> setTaskCompleted(int taskId, int userId, bool completed) async =>
      (await database).update(
        'tasks',
        {
          'is_completed': completed ? 1 : 0,
          'completed_at': completed ? DateTime.now().toIso8601String() : null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [taskId, userId],
      );

  Future<Map<String, Object?>> taskPreferences() async {
    final rows = await (await database).query(
      'app_settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty
        ? {'notifications_enabled': 1, 'default_reminder_minutes': 60}
        : rows.first;
  }

  Future<void> updateTaskPreferences({
    required bool notificationsEnabled,
    required int defaultReminderMinutes,
  }) async => (await database).update(
    'app_settings',
    {
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'default_reminder_minutes': defaultReminderMinutes,
    },
    where: 'id = ?',
    whereArgs: [1],
  );

  static Future<void> _createTaskTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT NULL,
      deadline TEXT NOT NULL,
      priority TEXT NOT NULL,
      is_completed INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      completed_at TEXT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE task_reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL,
      reminder_minutes INTEGER NOT NULL,
      notification_id INTEGER NOT NULL UNIQUE,
      is_enabled INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )''');
    await db.execute(
      'CREATE INDEX idx_tasks_user_deadline ON tasks(user_id, deadline)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_user_completed ON tasks(user_id, is_completed)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_task ON task_reminders(task_id)',
    );
  }

  static Future<void> _createFocusSessionTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE focus_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      duration_minutes INTEGER NOT NULL,
      completed_at TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''');
    await db.execute(
      'CREATE INDEX idx_focus_sessions_user_date ON focus_sessions(user_id, completed_at)',
    );
  }

  static Future<void> _createAppBlockingTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE blocked_applications (
      user_id INTEGER NOT NULL,
      package_name TEXT NOT NULL,
      app_name TEXT NOT NULL,
      is_enabled INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY(user_id, package_name),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE app_blocking_settings (
      user_id INTEGER PRIMARY KEY,
      is_enabled INTEGER NOT NULL DEFAULT 0,
      block_during_breaks INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE pomodoro_states (
      user_id INTEGER PRIMARY KEY,
      status TEXT NOT NULL DEFAULT 'idle',
      session_type TEXT NOT NULL DEFAULT 'focus',
      remaining_seconds INTEGER NOT NULL DEFAULT 1500,
      total_seconds INTEGER NOT NULL DEFAULT 1500,
      ends_at_epoch_ms INTEGER NULL,
      focus_minutes INTEGER NOT NULL DEFAULT 25,
      break_minutes INTEGER NOT NULL DEFAULT 5,
      completed_focus_sessions INTEGER NOT NULL DEFAULT 0,
      updated_at_epoch_ms INTEGER NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )''');
  }

  static Future<void> _addPomodoroStartedAt(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE pomodoro_states ADD COLUMN session_started_at_epoch_ms INTEGER NULL',
    );
  }
}

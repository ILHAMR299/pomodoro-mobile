import 'dart:math';

import '../database/database_helper.dart';
import '../models/task_model.dart';
import 'notification_service.dart';

class TaskSaveResult {
  const TaskSaveResult(this.task, {required this.reminderScheduled});
  final TaskModel task;
  final bool reminderScheduled;
}

class TaskService {
  TaskService({DatabaseHelper? database, NotificationService? notifications})
    : _database = database ?? DatabaseHelper.instance,
      _notifications = notifications ?? NotificationService.instance;

  final DatabaseHelper _database;
  final NotificationService _notifications;
  final Random _random = Random.secure();

  int _newNotificationId() => _random.nextInt(0x7ffffffe) + 1;

  Future<List<TaskModel>> tasks(int userId) async =>
      (await _database.tasksForUser(userId)).map(TaskModel.fromMap).toList();

  Future<TaskModel?> task(int taskId, int userId) async {
    final row = await _database.taskById(taskId, userId);
    return row == null ? null : TaskModel.fromMap(row);
  }

  Future<TaskSaveResult> save({
    TaskModel? existing,
    required int userId,
    required String title,
    required String category,
    required String description,
    required DateTime deadline,
    required String priority,
    required int reminderMinutes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'user_id': userId,
      'title': title.trim(),
      'category': category.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'deadline': deadline.toIso8601String(),
      'priority': priority,
      'updated_at': now,
    };
    final notificationId = reminderMinutes > 0
        ? _newNotificationId()
        : _newNotificationId();
    final oldReminders = existing == null
        ? <Map<String, Object?>>[]
        : await _database.remindersForTask(existing.id);
    TaskModel saved;
    if (existing == null) {
      values['created_at'] = now;
      values['is_completed'] = 0;
      final id = await _database.createTask(
        values,
        reminderMinutes: reminderMinutes,
        notificationId: notificationId,
      );
      saved = (await task(id, userId))!;
    } else {
      await _database.updateTask(
        values,
        taskId: existing.id,
        userId: userId,
        reminderMinutes: reminderMinutes,
        notificationId: notificationId,
      );
      saved = (await task(existing.id, userId))!;
      await _cancelRows(oldReminders);
    }
    final scheduled = await _scheduleTask(saved, notificationId);
    return TaskSaveResult(
      saved,
      reminderScheduled: reminderMinutes == 0 || scheduled,
    );
  }

  Future<void> delete(TaskModel task) async {
    final reminders = await _database.remindersForTask(task.id);
    await _database.deleteTask(task.id, task.userId);
    await _cancelRows(reminders);
  }

  Future<void> setCompleted(TaskModel task, bool completed) async {
    final reminders = await _database.remindersForTask(task.id);
    await _database.setTaskCompleted(task.id, task.userId, completed);
    if (completed) {
      await _cancelRows(reminders);
    } else {
      final fresh = await this.task(task.id, task.userId);
      if (fresh != null) {
        await _scheduleTask(
          fresh,
          reminders.firstOrNull?['notification_id'] as int? ??
              _newNotificationId(),
        );
      }
    }
  }

  Future<Map<String, Object?>> preferences() => _database.taskPreferences();

  Future<void> updateDefaultReminder(int minutes) async {
    final current = await preferences();
    await _database.updateTaskPreferences(
      notificationsEnabled:
          (current['notifications_enabled'] as int? ?? 1) == 1,
      defaultReminderMinutes: minutes,
    );
  }

  Future<bool> updatePreferences({
    required int userId,
    required bool notificationsEnabled,
    required int defaultReminderMinutes,
  }) async {
    if (notificationsEnabled && !await _notifications.requestPermission()) {
      return false;
    }
    await _database.updateTaskPreferences(
      notificationsEnabled: notificationsEnabled,
      defaultReminderMinutes: defaultReminderMinutes,
    );
    if (!notificationsEnabled) {
      final reminders = await _database.allReminders();
      await _cancelRows(reminders);
      return true;
    }
    await reconcile(userId);
    return true;
  }

  Future<void> reconcile(int userId) async {
    final prefs = await preferences();
    if ((prefs['notifications_enabled'] as int? ?? 1) != 1) return;
    final rows = await _database.remindersForUser(userId);
    for (final row in rows) {
      if ((row['is_enabled'] as int) != 1 ||
          (row['is_completed'] as int) == 1) {
        continue;
      }
      final deadline = DateTime.parse(row['deadline'] as String);
      final minutes = row['reminder_minutes'] as int;
      if (minutes <= 0) continue;
      await _schedule(
        id: row['notification_id'] as int,
        title: 'Pengingat tenggat tugas',
        body:
            'Tugas ${row['title']} akan segera berakhir. Jangan lupa selesaikan tugasmu!',
        deadline: deadline,
        reminderMinutes: minutes,
      );
    }
  }

  Future<bool> _scheduleTask(TaskModel task, int notificationId) async {
    final prefs = await preferences();
    if (task.isCompleted || task.reminderMinutes <= 0) {
      return true;
    }
    if ((prefs['notifications_enabled'] as int? ?? 1) != 1) return false;
    try {
      if (!await _notifications.requestPermission()) return false;
      return await _schedule(
        id: notificationId,
        title: 'Pengingat tenggat tugas',
        body:
            'Tugas ${task.title} akan segera berakhir. Jangan lupa selesaikan tugasmu!',
        deadline: task.deadline,
        reminderMinutes: task.reminderMinutes,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime deadline,
    required int reminderMinutes,
  }) async {
    final trigger = deadline.subtract(Duration(minutes: reminderMinutes));
    if (!trigger.isAfter(DateTime.now())) return false;
    await _notifications.schedule(
      id: id,
      title: title,
      body: body,
      triggerAt: trigger,
    );
    return true;
  }

  Future<void> _cancelRows(List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      try {
        await _notifications.cancel(row['notification_id'] as int);
      } catch (_) {}
    }
  }
}

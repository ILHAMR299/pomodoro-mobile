class TaskReminderModel {
  const TaskReminderModel({
    required this.id,
    required this.taskId,
    required this.reminderMinutes,
    required this.notificationId,
    required this.isEnabled,
  });

  final int id;
  final int taskId;
  final int reminderMinutes;
  final int notificationId;
  final bool isEnabled;

  factory TaskReminderModel.fromMap(Map<String, Object?> map) =>
      TaskReminderModel(
        id: map['id'] as int,
        taskId: map['task_id'] as int,
        reminderMinutes: map['reminder_minutes'] as int,
        notificationId: map['notification_id'] as int,
        isEnabled: (map['is_enabled'] as int) == 1,
      );
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.reminderMinutes,
  });

  final int id;
  final int userId;
  final String title;
  final String category;
  final String? description;
  final DateTime deadline;
  final String priority;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int reminderMinutes;

  bool get isOverdue => !isCompleted && deadline.isBefore(DateTime.now());

  factory TaskModel.fromMap(Map<String, Object?> map) => TaskModel(
    id: map['id'] as int,
    userId: map['user_id'] as int,
    title: map['title'] as String,
    category: map['category'] as String,
    description: map['description'] as String?,
    deadline: DateTime.parse(map['deadline'] as String),
    priority: map['priority'] as String,
    isCompleted: (map['is_completed'] as int) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    completedAt: map['completed_at'] == null
        ? null
        : DateTime.parse(map['completed_at'] as String),
    reminderMinutes: map['reminder_minutes'] as int? ?? 0,
  );
}

class FocusSessionModel {
  const FocusSessionModel({
    required this.id,
    required this.userId,
    required this.durationMinutes,
    required this.completedAt,
  });

  final int id;
  final int userId;
  final int durationMinutes;
  final DateTime completedAt;

  factory FocusSessionModel.fromMap(Map<String, Object?> map) =>
      FocusSessionModel(
        id: map['id'] as int,
        userId: map['user_id'] as int,
        durationMinutes: map['duration_minutes'] as int,
        completedAt: DateTime.parse(map['completed_at'] as String),
      );
}

import '../database/database_helper.dart';
import '../models/focus_session_model.dart';

class FocusSessionService {
  FocusSessionService({DatabaseHelper? database})
    : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  Future<void> recordCompletedSession({
    required int userId,
    required int durationMinutes,
    DateTime? completedAt,
  }) async {
    await _database.recordFocusSession(
      userId: userId,
      durationMinutes: durationMinutes,
      completedAt: completedAt ?? DateTime.now(),
    );
  }

  Future<List<FocusSessionModel>> sessionsForUser(int userId) async =>
      (await _database.focusSessionsForUser(userId))
          .map(FocusSessionModel.fromMap)
          .toList();
}

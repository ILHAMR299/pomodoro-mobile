import '../models/focus_session_model.dart';
import '../models/task_model.dart';

class StatisticsController {
  StatisticsController(List<TaskModel> tasks, {List<FocusSessionModel> focusSessions = const []})
    : tasks = List.unmodifiable(tasks),
      focusSessions = List.unmodifiable(focusSessions),
      weekStart = _day(DateTime.now()).subtract(const Duration(days: 6)) {
    total = this.tasks.length;
    completed = this.tasks.where((task) => task.isCompleted).length;
    overdue = this.tasks.where((task) => task.isOverdue).length;
    pending = total - completed;
    focusSessionCount = this.focusSessions.length;
    completionRate = total == 0 ? 0 : completed / total;
    completedByDay = List.unmodifiable(_countByDay(this.tasks
        .where((task) => task.isCompleted && task.completedAt != null)
        .map((task) => task.completedAt!)));
    focusSessionsByDay = List.unmodifiable(_countByDay(
      this.focusSessions.map((session) => session.completedAt),
    ));
    history = List.unmodifiable(this.tasks.where((task) => task.isCompleted)
      .toList()..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt)));
  }

  final List<TaskModel> tasks;
  final List<FocusSessionModel> focusSessions;
  final DateTime weekStart;
  late final int total, completed, overdue, pending, focusSessionCount;
  late final double completionRate;
  late final List<int> completedByDay, focusSessionsByDay;
  late final List<TaskModel> history;

  int countPriority(String priority) => tasks.where((task) => task.priority == priority).length;

  List<int> _countByDay(Iterable<DateTime> dates) {
    final counts = List<int>.filled(7, 0);
    for (final date in dates) {
      final day = _day(date);
      final index = day.difference(weekStart).inDays;
      if (index >= 0 && index < 7) counts[index]++;
    }
    return counts;
  }

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}

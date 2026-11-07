enum TimerStatus { idle, running, paused }

enum SessionType { focus, breakTime }

class PomodoroSnapshot {
  const PomodoroSnapshot({
    required this.status,
    required this.session,
    required this.remaining,
    required this.totalDuration,
    required this.completedFocusSessions,
    required this.sessionNumber,
  });

  final TimerStatus status;
  final SessionType session;
  final Duration remaining;
  final Duration totalDuration;
  final int completedFocusSessions;
  final int sessionNumber;

  bool get isRunning => status == TimerStatus.running;
  bool get isBreak => session == SessionType.breakTime;
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pomodoro_state.dart';

class PomodoroController extends ChangeNotifier {
  PomodoroController({
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    DateTime Function()? clock,
    this.onFocusSessionCompleted,
    this.onStateChanged,
  }) : _clock = clock ?? DateTime.now,
       _remaining = Duration(minutes: focusMinutes),
       _totalDuration = Duration(minutes: focusMinutes);

  int focusMinutes;
  int breakMinutes;
  final Future<void> Function(int durationMinutes)? onFocusSessionCompleted;
  final void Function(PomodoroSnapshot snapshot)? onStateChanged;
  Timer? _ticker;
  final DateTime Function() _clock;
  DateTime? _endsAt;
  DateTime? _sessionStartedAt;
  Duration _remaining;
  Duration _totalDuration;
  TimerStatus _status = TimerStatus.idle;
  SessionType _session = SessionType.focus;
  int _completedFocusSessions = 0;

  int? get endsAtEpochMillis => _endsAt?.millisecondsSinceEpoch;
  int? get sessionStartedAtEpochMillis =>
      _sessionStartedAt?.millisecondsSinceEpoch;

  PomodoroSnapshot get snapshot => PomodoroSnapshot(
    status: _status,
    session: _session,
    remaining: _remaining,
    totalDuration: _totalDuration,
    completedFocusSessions: _completedFocusSessions,
    sessionNumber: _completedFocusSessions + 1,
  );

  void start() {
    if (_status == TimerStatus.running) return;
    if (_status != TimerStatus.paused) _sessionStartedAt = _clock();
    _status = TimerStatus.running;
    _endsAt = _clock().add(_remaining);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _emitStateChange();
  }

  void pause() {
    if (_status != TimerStatus.running) return;
    _remaining = _remainingAt(_clock());
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    _status = TimerStatus.paused;
    _emitStateChange();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    _sessionStartedAt = null;
    _session = SessionType.focus;
    _status = TimerStatus.idle;
    _remaining = Duration(minutes: focusMinutes);
    _totalDuration = _remaining;
    _emitStateChange();
  }

  void updateDurations({required int focus, required int rest}) {
    focusMinutes = focus.clamp(1, 90).toInt();
    breakMinutes = rest.clamp(1, 30).toInt();
    reset();
  }

  void restore({
    required String status,
    required String sessionType,
    required int remainingSeconds,
    required int totalSeconds,
    required int? endsAtEpochMillis,
    required int? sessionStartedAtEpochMillis,
    required int focus,
    required int rest,
    required int completedFocusSessions,
  }) {
    _ticker?.cancel();
    focusMinutes = focus.clamp(1, 90).toInt();
    breakMinutes = rest.clamp(1, 30).toInt();
    _session = sessionType == 'break'
        ? SessionType.breakTime
        : SessionType.focus;
    _status = switch (status) {
      'running' => TimerStatus.running,
      'paused' => TimerStatus.paused,
      _ => TimerStatus.idle,
    };
    _totalDuration = Duration(seconds: totalSeconds);
    _remaining = Duration(seconds: remainingSeconds);
    _completedFocusSessions = completedFocusSessions;
    _endsAt = _status != TimerStatus.running
        ? null
        : endsAtEpochMillis == null
        ? _clock().add(_remaining)
        : DateTime.fromMillisecondsSinceEpoch(endsAtEpochMillis);
    _sessionStartedAt = sessionStartedAtEpochMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(sessionStartedAtEpochMillis);
    if (_status == TimerStatus.running) {
      _remaining = _remainingAt(_clock());
      if (_remaining == Duration.zero) {
        _completeSession();
        return;
      }
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    }
    notifyListeners();
  }

  void refreshAfterLifecycleChange() {
    if (_status == TimerStatus.running) _refresh();
  }

  Duration _remainingAt(DateTime now) {
    final end = _endsAt;
    if (end == null) return _remaining;
    final difference = end.difference(now);
    return difference.isNegative ? Duration.zero : difference;
  }

  void _refresh() {
    if (_status != TimerStatus.running) return;
    _remaining = _remainingAt(_clock());
    if (_remaining == Duration.zero) {
      _completeSession();
      return;
    }
    notifyListeners();
  }

  void _completeSession() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    if (_session == SessionType.focus) {
      _completedFocusSessions++;
      final recordSession = onFocusSessionCompleted;
      if (recordSession != null) {
        unawaited(
          Future<void>.sync(() => recordSession(focusMinutes))
              .catchError((_) {}),
        );
      }
      _session = SessionType.breakTime;
      _sessionStartedAt = _clock();
      _remaining = Duration(minutes: breakMinutes);
      _totalDuration = _remaining;
      _status = TimerStatus.running;
      _endsAt = _clock().add(_remaining);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    } else {
      _session = SessionType.focus;
      _sessionStartedAt = null;
      _remaining = Duration(minutes: focusMinutes);
      _totalDuration = _remaining;
      _status = TimerStatus.idle;
    }
    _emitStateChange();
  }

  void _emitStateChange() {
    notifyListeners();
    onStateChanged?.call(snapshot);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

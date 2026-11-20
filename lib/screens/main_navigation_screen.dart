import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../controllers/pomodoro_controller.dart';
import '../models/pomodoro_state.dart';
import '../services/focus_session_service.dart';
import '../services/app_blocking_platform.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import 'pomodoro_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'task_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });
  final UserModel user;
  final Future<void> Function() onLogout;
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selected = 0;
  int _revision = 0;
  final _tasks = TaskService();
  final _focusSessions = FocusSessionService();
  final _database = DatabaseHelper.instance;
  late final PomodoroController _pomodoro;
  bool _pomodoroReady = false;
  bool _monitorServiceStarted = false;
  Future<void> _blockingUpdates = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _pomodoro = PomodoroController(
      onFocusSessionCompleted: _recordFocusSession,
      onStateChanged: _onPomodoroStateChanged,
    );
    if (AppBlockingPlatform.isSupported) {
      AppBlockingPlatform.setEndSessionHandler(_pomodoro.reset);
    }
    unawaited(_restorePomodoro());
    unawaited(
      NotificationService.instance
          .initialize()
          .then((_) => _tasks.reconcile(widget.user.id))
          .catchError((_) {}),
    );
  }

  Future<void> _recordFocusSession(int durationMinutes) async {
    try {
      await _focusSessions.recordCompletedSession(
        userId: widget.user.id,
        durationMinutes: durationMinutes,
      );
      if (mounted) setState(() => _revision++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sesi fokus selesai, tetapi statistik belum tersimpan.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _restorePomodoro() async {
    try {
      if (AppBlockingPlatform.isSupported) {
        await AppBlockingPlatform.stopMonitoring();
        _monitorServiceStarted = false;
        if (await AppBlockingPlatform.takePendingEndSession()) {
          _pomodoro.reset();
          return;
        }
      }
      final saved = await _database.pomodoroState(widget.user.id);
      if (saved != null && mounted) {
        _pomodoro.restore(
          status: saved['status'] as String,
          sessionType: saved['session_type'] as String,
          remainingSeconds: saved['remaining_seconds'] as int,
          totalSeconds: saved['total_seconds'] as int,
          endsAtEpochMillis: saved['ends_at_epoch_ms'] as int?,
          sessionStartedAtEpochMillis:
              saved['session_started_at_epoch_ms'] as int?,
          focus: saved['focus_minutes'] as int,
          rest: saved['break_minutes'] as int,
          completedFocusSessions: saved['completed_focus_sessions'] as int,
        );
        await _queueBlockingSync(_pomodoro.snapshot);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Sesi fokus sebelumnya belum dapat dipulihkan.');
      }
    } finally {
      if (mounted) setState(() => _pomodoroReady = true);
    }
  }

  void _onPomodoroStateChanged(PomodoroSnapshot snapshot) {
    unawaited(_savePomodoroState(snapshot));
    unawaited(_queueBlockingSync(snapshot));
  }

  Future<void> _queueBlockingSync(PomodoroSnapshot snapshot) {
    final update = _blockingUpdates
        .catchError((Object _) {})
        .then((_) => _syncBlocking(snapshot));
    _blockingUpdates = update;
    return update;
  }

  Future<void> _savePomodoroState(PomodoroSnapshot snapshot) async {
    try {
      await _database.savePomodoroState(
        userId: widget.user.id,
        status: snapshot.status.name,
        sessionType: snapshot.isBreak ? 'break' : 'focus',
        remainingSeconds: snapshot.remaining.inSeconds,
        totalSeconds: snapshot.totalDuration.inSeconds,
        endsAtEpochMillis: _pomodoro.endsAtEpochMillis,
        sessionStartedAtEpochMillis: _pomodoro.sessionStartedAtEpochMillis,
        focusMinutes: _pomodoro.focusMinutes,
        breakMinutes: _pomodoro.breakMinutes,
        completedFocusSessions: snapshot.completedFocusSessions,
      );
    } catch (_) {
      if (mounted) _showMessage('Status sesi fokus belum dapat disimpan.');
    }
  }

  Future<bool> _preparePomodoroStart() async {
    if (!_pomodoroReady) {
      _showMessage('Sesi fokus sedang dipulihkan. Coba lagi sebentar.');
      return false;
    }
    if (!AppBlockingPlatform.isSupported) return true;
    final settings = await _database.appBlockingSettings(widget.user.id);
    if ((settings['is_enabled'] as int? ?? 0) == 0) return true;
    final selected = (await _database.blockedApplications(widget.user.id))
        .where((row) => (row['is_enabled'] as int) == 1)
        .map((row) => row['package_name'] as String)
        .toList(growable: false);
    final permissions = await Future.wait<bool>([
      AppBlockingPlatform.hasUsageAccess(),
      AppBlockingPlatform.canDrawOverlays(),
      AppBlockingPlatform.hasNotificationPermission(),
    ]);
    if (selected.isNotEmpty && permissions.every((granted) => granted)) {
      return true;
    }
    _showMessage(
      selected.isEmpty
          ? 'Pilih aplikasi di Pengaturan > Pemblokiran Aplikasi.'
          : 'Lengkapi izin pemantauan di Pengaturan > Pemblokiran Aplikasi.',
    );
    if (!mounted) return false;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(user: widget.user, onLogout: _logout),
      ),
    );
    return false;
  }

  Future<void> _syncBlocking(PomodoroSnapshot snapshot) async {
    if (!AppBlockingPlatform.isSupported) return;
    try {
      if (snapshot.status != TimerStatus.running) {
        if (_monitorServiceStarted) {
          await AppBlockingPlatform.stopMonitoring();
          _monitorServiceStarted = false;
        }
        return;
      }
      final settings = await _database.appBlockingSettings(widget.user.id);
      if ((settings['is_enabled'] as int? ?? 0) == 0) {
        if (_monitorServiceStarted) {
          await AppBlockingPlatform.stopMonitoring();
          _monitorServiceStarted = false;
        }
        return;
      }
      final apps = await _database.blockedApplications(widget.user.id);
      final packages = apps
          .where((row) => (row['is_enabled'] as int) == 1)
          .map((row) => row['package_name'] as String)
          .toList(growable: false);
      if (packages.isEmpty) {
        if (_monitorServiceStarted) {
          await AppBlockingPlatform.stopMonitoring();
          _monitorServiceStarted = false;
        }
        return;
      }
      final shouldMonitor =
          !snapshot.isBreak ||
          (settings['block_during_breaks'] as int? ?? 0) == 1;
      if (_monitorServiceStarted) {
        await AppBlockingPlatform.updateMonitoring(
          packages,
          enabled: shouldMonitor,
          resumeAtEpochMillis: !shouldMonitor && snapshot.isBreak
              ? _pomodoro.endsAtEpochMillis
              : null,
        );
      } else {
        await AppBlockingPlatform.startMonitoring(
          packages,
          monitoringEnabled: shouldMonitor,
          resumeAtEpochMillis: !shouldMonitor && snapshot.isBreak
              ? _pomodoro.endsAtEpochMillis
              : null,
        );
        _monitorServiceStarted = true;
      }
    } catch (_) {
      _monitorServiceStarted = false;
      if (mounted && _pomodoro.snapshot.status == TimerStatus.running) {
        _pomodoro.pause();
        _showMessage(
          'Pemantauan aplikasi gagal dimulai. Sesi dijeda agar status fokus tetap jelas.',
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await AppBlockingPlatform.stopMonitoring();
    } catch (_) {}
    _pomodoro.reset();
    await widget.onLogout();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    if (AppBlockingPlatform.isSupported) {
      AppBlockingPlatform.setEndSessionHandler(null);
    }
    _pomodoro.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(user: widget.user, onLogout: _logout),
      ),
    );
    if (mounted) {
      setState(() => _revision++);
      await _queueBlockingSync(_pomodoro.snapshot);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(const ['FocusMaxx', 'Daftar Tugas', 'Statistik'][_selected]),
      actions: [
        IconButton(
          tooltip: 'Pengaturan',
          onPressed: _openSettings,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: IndexedStack(
      index: _selected,
      children: [
        PomodoroScreen(
          controller: _pomodoro,
          userName: widget.user.name,
          onLogout: _logout,
          onStartRequested: _preparePomodoroStart,
        ),
        TaskScreen(
          userId: widget.user.id,
          name: widget.user.name,
          active: _selected == 1,
          revision: _revision,
          onDataChanged: () => setState(() => _revision++),
        ),
        StatisticsScreen(
          userId: widget.user.id,
          active: _selected == 2,
          revision: _revision,
        ),
      ],
    ),
    bottomNavigationBar: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) => setState(() => _selected = index),
        backgroundColor: const Color(0xFFF8FCF8),
        indicatorColor: AppTheme.softGreen.withValues(alpha: .58),
        elevation: 5,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Fokus',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tugas',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Statistik',
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../controllers/pomodoro_controller.dart';
import '../models/pomodoro_state.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot_widget.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({
    super.key,
    this.controller,
    this.userName,
    this.onLogout,
    this.onStartRequested,
  });

  final PomodoroController? controller;
  final String? userName;
  final Future<void> Function()? onLogout;
  final Future<bool> Function()? onStartRequested;

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with WidgetsBindingObserver {
  late final PomodoroController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PomodoroController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAfterLifecycleChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final snapshot = _controller.snapshot;
        final label = snapshot.status == TimerStatus.paused
            ? 'Sedang Dijeda'
            : snapshot.isBreak
            ? 'Waktu Istirahat'
            : 'Waktu Fokus';
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _header(context, snapshot.completedFocusSessions),
                        const SizedBox(height: 18),
                        Text(
                          snapshot.status == TimerStatus.running
                              ? snapshot.isBreak
                                    ? 'Tarik napas, kamu sudah bekerja keras.'
                                    : 'Satu hal dalam satu waktu.'
                              : widget.userName == null
                              ? 'Hai, siap untuk fokus hari ini?'
                              : 'Hai, ${widget.userName}, siap untuk fokus hari ini?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.darkGreen,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MascotWidget(
                          status: snapshot.status,
                          session: snapshot.session,
                        ),
                        const SizedBox(height: 2),
                        TimerProgress(
                          remaining: snapshot.remaining,
                          total: snapshot.totalDuration,
                          label: label,
                          sessionNumber: snapshot.sessionNumber,
                        ),
                        const SizedBox(height: 22),
                        _controls(snapshot),
                        const SizedBox(height: 24),
                        _sessionDetails(snapshot),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, int completed) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.softGreen.withValues(alpha: .52),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.spa_rounded,
            color: AppTheme.darkGreen,
            size: 23,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            'FocusMaxx',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Pengaturan durasi',
          onPressed: () => _showSettings(context),
          icon: const Icon(Icons.tune_rounded, color: AppTheme.darkGreen),
        ),
        if (completed > 0) ...[
          const SizedBox(width: 2),
          Icon(Icons.check_circle_rounded, size: 17, color: AppTheme.green),
          const SizedBox(width: 4),
          Text(
            '$completed',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
        ],
      ],
    );
  }

  Widget _controls(PomodoroSnapshot snapshot) {
    final running = snapshot.status == TimerStatus.running;
    final paused = snapshot.status == TimerStatus.paused;
    final canStart = !running;
    final label = running
        ? 'Jeda'
        : paused
        ? 'Lanjutkan'
        : 'Mulai';
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: canStart ? _start : _controller.pause,
          icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(label),
        ),
        OutlinedButton.icon(
          onPressed: _controller.reset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Atur Ulang'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.darkGreen,
            minimumSize: const Size(142, 54),
            side: BorderSide(color: AppTheme.darkGreen.withValues(alpha: .22)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _start() async {
    final allowed = await widget.onStartRequested?.call() ?? true;
    if (!allowed || !mounted) return;
    _controller.start();
  }

  Widget _sessionDetails(PomodoroSnapshot snapshot) {
    final next = snapshot.isBreak
        ? 'Sesi fokus berikutnya'
        : 'Istirahat singkat berikutnya';
    final nextDuration = snapshot.isBreak
        ? _controller.focusMinutes
        : _controller.breakMinutes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.softGreen.withValues(alpha: .52)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withValues(alpha: .045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 19,
                color: AppTheme.green,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Sesi fokus selesai',
                  style: TextStyle(color: AppTheme.ink, fontSize: 14),
                ),
              ),
              Text(
                '${snapshot.completedFocusSessions}',
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Color(0xFFE3EEE3)),
          ),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 19,
                color: AppTheme.green,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Durasi fokus',
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .85),
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${_controller.focusMinutes} menit',
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Color(0xFFE3EEE3)),
          ),
          Row(
            children: [
              Icon(
                snapshot.isBreak
                    ? Icons.menu_book_rounded
                    : Icons.coffee_rounded,
                size: 19,
                color: AppTheme.green,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  next,
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .85),
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$nextDuration menit',
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    final focusField = TextEditingController(
      text: '${_controller.focusMinutes}',
    );
    final breakField = TextEditingController(
      text: '${_controller.breakMinutes}',
    );
    var invalidDuration = false;
    final result = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFF8FCF8),
          title: const Text(
            'Atur durasi',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _durationField('Waktu fokus (menit)', focusField, 90),
              const SizedBox(height: 14),
              _durationField('Waktu istirahat (menit)', breakField, 30),
              const SizedBox(height: 8),
              const Text(
                'Fokus 1–90 menit, istirahat 1–30 menit.',
                style: TextStyle(fontSize: 12, color: AppTheme.darkGreen),
              ),
              if (invalidDuration)
                const Text(
                  'Masukkan durasi dalam rentang yang ditentukan.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9C3028)),
                ),
            ],
          ),
          actions: [
            if (widget.onLogout != null)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'logout'),
                child: const Text(
                  'Keluar Akun',
                  style: TextStyle(color: Color(0xFF9C3028)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final focus = int.tryParse(focusField.text);
                final rest = int.tryParse(breakField.text);
                if (focus == null ||
                    rest == null ||
                    focus < 1 ||
                    focus > 90 ||
                    rest < 1 ||
                    rest > 30) {
                  setDialogState(() => invalidDuration = true);
                  return;
                }
                Navigator.pop(dialogContext, (focus, rest));
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      focusField.dispose();
      breakField.dispose();
      return;
    }
    focusField.dispose();
    breakField.dispose();
    if (result == 'logout') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Keluar dari akun?'),
          content: const Text(
            'Akun dan sesi fokusmu tetap tersimpan di perangkat ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Keluar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirm == true) await widget.onLogout?.call();
    } else if (result case (int focus, int rest)) {
      _controller.updateDurations(focus: focus, rest: rest);
    }
  }

  Widget _durationField(
    String label,
    TextEditingController controller,
    int max,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'menit',
        helperText: 'Maksimal $max menit',
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

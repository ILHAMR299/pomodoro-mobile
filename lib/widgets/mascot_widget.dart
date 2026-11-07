import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models/pomodoro_state.dart';
import '../theme/app_theme.dart';

class MascotWidget extends StatelessWidget {
  const MascotWidget({super.key, required this.status, required this.session});

  final TimerStatus status;
  final SessionType session;

  @override
  Widget build(BuildContext context) {
    final isResting =
        session == SessionType.breakTime && status == TimerStatus.running;
    final isFocused = status == TimerStatus.running && !isResting;
    final asset = isResting
        ? 'assets/animations/break.json'
        : isFocused
        ? 'assets/animations/timercat.json'
        : 'assets/animations/idle.json';
    final key = isResting
        ? 'mascot-break'
        : isFocused
        ? 'mascot-focused'
        : 'mascot-idle';

    return SizedBox(
      width: 190,
      height: 180,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .92, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: Lottie.asset(
          asset,
          key: ValueKey(key),
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}

class TimerProgress extends StatelessWidget {
  const TimerProgress({
    super.key,
    required this.remaining,
    required this.total,
    required this.label,
    required this.sessionNumber,
  });

  final Duration remaining;
  final Duration total;
  final String label;
  final int sessionNumber;

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (1 - remaining.inMilliseconds / total.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final minutes = remaining.inSeconds ~/ 60;
    final seconds = remaining.inSeconds % 60;
    return SizedBox(
      width: 228,
      height: 228,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 9,
                strokeCap: StrokeCap.round,
                backgroundColor: AppTheme.softGreen.withValues(alpha: .45),
                valueColor: const AlwaysStoppedAnimation(AppTheme.green),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Sesi fokus ke-$sessionNumber',
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

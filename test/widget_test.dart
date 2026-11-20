import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:focusmaxx/controllers/pomodoro_controller.dart';
import 'package:focusmaxx/screens/pomodoro_screen.dart';

void main() {
  test('sesi fokus selesai memicu pencatatan durasi', () async {
    var now = DateTime(2026, 1, 1);
    final savedDuration = Completer<int>();
    final controller = PomodoroController(
      focusMinutes: 1,
      breakMinutes: 1,
      clock: () => now,
      onFocusSessionCompleted: (duration) async =>
          savedDuration.complete(duration),
    );
    addTearDown(controller.dispose);

    controller.start();
    now = now.add(const Duration(minutes: 1));
    controller.refreshAfterLifecycleChange();

    expect(await savedDuration.future, 1);
  });

  test('status Pomodoro tersimpan saat transisi dan dapat dipulihkan', () {
    var now = DateTime(2026, 5, 1, 10);
    final states = <String>[];
    final controller = PomodoroController(
      focusMinutes: 1,
      breakMinutes: 1,
      clock: () => now,
      onStateChanged: (snapshot) => states.add(
        '${snapshot.status.name}:${snapshot.isBreak ? 'break' : 'focus'}',
      ),
    );
    addTearDown(controller.dispose);

    controller.start();
    now = now.add(const Duration(seconds: 12));
    controller.refreshAfterLifecycleChange();
    controller.pause();

    expect(states, ['running:focus', 'paused:focus']);
    expect(controller.snapshot.remaining, const Duration(seconds: 48));

    final restored = PomodoroController(clock: () => now);
    addTearDown(restored.dispose);
    restored.restore(
      status: 'running',
      sessionType: 'focus',
      remainingSeconds: 48,
      totalSeconds: 60,
      endsAtEpochMillis: now
          .add(const Duration(seconds: 31))
          .millisecondsSinceEpoch,
      sessionStartedAtEpochMillis: now
          .subtract(const Duration(seconds: 29))
          .millisecondsSinceEpoch,
      focus: 1,
      rest: 1,
      completedFocusSessions: 2,
    );

    expect(restored.snapshot.status.name, 'running');
    expect(restored.snapshot.remaining, const Duration(seconds: 31));
    expect(restored.snapshot.completedFocusSessions, 2);
    expect(
      restored.sessionStartedAtEpochMillis,
      now.subtract(const Duration(seconds: 29)).millisecondsSinceEpoch,
    );
  });

  testWidgets('timer dapat dijeda, dilanjutkan, dan diatur ulang', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PomodoroScreen()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('FocusMaxx'), findsOneWidget);
    expect(find.text('Waktu Fokus'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);

    await tester.tap(find.text('Mulai'));
    await tester.pump();
    expect(find.text('Jeda'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Jeda'));
    await tester.pump();
    expect(find.text('Lanjutkan'), findsOneWidget);
    expect(find.text('Sedang Dijeda'), findsOneWidget);

    await tester.tap(find.text('Lanjutkan'));
    await tester.pump();
    expect(find.text('Jeda'), findsOneWidget);

    await tester.tap(find.text('Atur Ulang'));
    await tester.pump();
    expect(find.text('Mulai'), findsOneWidget);

    await tester.tap(find.byTooltip('Pengaturan durasi'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).at(0), '0');
    await tester.enterText(find.byType(TextField).at(1), '31');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(
      find.text('Masukkan durasi dalam rentang yang ditentukan.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.text('Simpan'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets('fokus beralih ke istirahat lalu kembali ke fokus', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    final controller = PomodoroController(
      focusMinutes: 1,
      breakMinutes: 1,
      clock: () => now,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: PomodoroScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Mulai'));
    await tester.pump();

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Waktu Istirahat'), findsOneWidget);
    expect(find.text('Jeda'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Waktu Fokus'), findsOneWidget);
    expect(find.text('Sesi fokus selesai'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });
}

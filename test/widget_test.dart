import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:focusmaxx/controllers/pomodoro_controller.dart';
import 'package:focusmaxx/main.dart';
import 'package:focusmaxx/screens/pomodoro_screen.dart';

void main() {
  testWidgets('timer dapat dijeda, dilanjutkan, dan diatur ulang', (
    tester,
  ) async {
    await tester.pumpWidget(const TemanFokusApp());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Teman Fokus'), findsOneWidget);
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

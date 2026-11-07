import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.loading, required this.error, required this.onRetry});
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Center(child: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 210, height: 210, child: LottieBuilder.asset('assets/animations/loadingscreen.json', fit: BoxFit.contain)),
        const SizedBox(height: 8),
        const Text('Teman Fokus', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
        const SizedBox(height: 6),
        const Text('Temani setiap langkah fokusmu.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.darkGreen)),
        if (loading) ...[const SizedBox(height: 22), const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.green))],
        if (error != null) ...[const SizedBox(height: 20), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.darkGreen)), const SizedBox(height: 14), FilledButton(onPressed: onRetry, child: const Text('Coba Lagi'))],
      ]),
    ))),
  );
}

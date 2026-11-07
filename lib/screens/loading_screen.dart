import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Lottie.asset('assets/animations/loadingscreen.json'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Teman Fokus',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Menyiapkan ruang fokusmu…',
              style: TextStyle(color: AppTheme.darkGreen),
            ),
          ],
        ),
      ),
    );
  }
}

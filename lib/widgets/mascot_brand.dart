import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';

class MascotBrand extends StatelessWidget {
  const MascotBrand({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
    SizedBox(width: 142, height: 112, child: Lottie.asset('assets/animations/Cutecatillustration.json', fit: BoxFit.contain)),
    const SizedBox(height: 2),
    const Text('FocusMaxx', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
  ]);
}

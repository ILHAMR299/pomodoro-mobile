import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFFE8F5E9);
  static const softGreen = Color(0xFFA5D6A7);
  static const green = Color(0xFF66BB6A);
  static const darkGreen = Color(0xFF1B5E20);
  static const ink = Color(0xFF25372A);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: darkGreen,
      onPrimary: Colors.white,
      surface: const Color(0xFFF8FCF8),
      onSurface: ink,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: darkGreen,
        letterSpacing: -.6,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: darkGreen,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size(150, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

class AppTheme {
  // Neon Colors
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonRed = Color(0xFFFF073A);
  static const Color neonBlue = Color(0xFF00F3FF);
  static const Color neonYellow = Color(0xFFFFE700);
  static const Color surface = Color(0xFF121212);

  // Classic Colors (Old School Nokia style)
  static const Color classicBg = Color(0xFF8BA922); // لونه أخضر زيتوني باهت
  static const Color classicSnake = Color(0xFF1D1F10); // أسود مخضر
  static const Color classicFood = Color(0xFF1D1F10);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: neonBlue,
    fontFamily: 'Orbitron',
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: neonBlue,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    ),
  );
}

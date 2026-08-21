import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF26352F);
  static const Color sage = Color(0xFF5F746A);
  static const Color cream = Color(0xFFF7F5F0);
  static const Color card = Color(0xFFFFFEFB);
  static const Color line = Color(0xFFE6E1D8);
  static const Color profit = Color(0xFF277A55);
  static const Color deficit = Color(0xFFC34A4A);
  static const Color balanced = Color(0xFF7A6F58);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: sage,
      brightness: Brightness.light,
      surface: cream,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      fontFamilyFallback: const ['Arial', 'Tahoma', 'sans-serif'],
      appBarTheme: const AppBarThemeData(
        elevation: 0,
        centerTitle: false,
        backgroundColor: cream,
        foregroundColor: ink,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: sage, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: sage.withOpacity(.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

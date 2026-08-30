import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light(Color accent) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F2F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  /// The Countdown screen intentionally breaks from the rest of the app's
  /// visual language per the spec — full black, high-contrast, distraction
  /// free. This is a standalone palette, not derived from ColorScheme.
  static ThemeData dark(Color accent) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121316),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1D1F23),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
      );

  static const countdownBackground = Color(0xFF000000);
  static const countdownText = Color(0xFFFFFFFF);

  static const priorityColors = {
    0: Color(0xFF9CA3AF), // low - grey
    1: Color(0xFF3B82F6), // medium - blue
    2: Color(0xFFF59E0B), // high - amber
    3: Color(0xFFEF4444), // critical - red
  };
}

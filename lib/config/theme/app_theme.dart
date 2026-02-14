import 'package:flutter/material.dart';

class VibeTheme {
  // Colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color primary = Color(0xFF00FF00); // Neon Green
  static const Color error = Color(0xFFFF3B30);   // Neon Red
  static const Color accent = Color(0xFF5E5CE6);  // Indigo
  static const Color onBackground = Colors.white;
  static const Color onSurface = Colors.white70;

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.black, // Text on neon green checks
        onSecondary: Colors.white,
        onSurface: onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onBackground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: onBackground),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent, // Active Tab
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'RobotoMono', // Ensure you have this font or use default
        bodyColor: onBackground,
        displayColor: onBackground,
      ),
      // Icon Theme
      iconTheme: const IconThemeData(
        color: onBackground,
      ),
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}

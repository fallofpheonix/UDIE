import 'package:flutter/material.dart';

class UdieTheme {
  static const Color bg = Color(0xFF0D1B2A);
  static const Color panel = Color(0xFF1B263B);
  static const Color accent = Color(0xFF00B4D8);
  static const Color caution = Color(0xFFF4A261);
  static const Color danger = Color(0xFFE63946);
  static const Color ok = Color(0xFF2A9D8F);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: caution,
        surface: panel,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
    );
  }
}

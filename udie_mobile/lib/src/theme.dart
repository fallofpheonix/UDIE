import 'package:flutter/material.dart';

class UdieTheme {
  static const Color bg = Color(0xFF0D1B2A);
  static const Color panel = Color(0xFF1B263B);
  static const Color accent = Color(0xFF00B4D8);
  static const Color caution = Color(0xFFF4A261);
  static const Color danger = Color(0xFFE63946);
  static const Color ok = Color(0xFF2A9D8F);

  /// Returns a semantic color for a disruption category label.
  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return const Color(0xFFF4A261);
      case 'crime':
        return const Color(0xFFE63946);
      case 'weather':
        return const Color(0xFF00B4D8);
      case 'infrastructure':
        return const Color(0xFF9B5DE5);
      case 'protest':
        return const Color(0xFFFF6B6B);
      case 'fire':
        return const Color(0xFFFF9F1C);
      default:
        return const Color(0xFF6B7FD7);
    }
  }

  /// Returns a representative icon for a disruption category label.
  static IconData categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return Icons.traffic;
      case 'crime':
        return Icons.local_police;
      case 'weather':
        return Icons.thunderstorm;
      case 'infrastructure':
        return Icons.construction;
      case 'protest':
        return Icons.groups;
      case 'fire':
        return Icons.local_fire_department;
      default:
        return Icons.warning_amber_rounded;
    }
  }

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
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

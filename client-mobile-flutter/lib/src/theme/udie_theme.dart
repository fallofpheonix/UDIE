import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UDIE Design System – v2
// ─────────────────────────────────────────────────────────────────────────────

class UdieTheme {
  // ── Core palette ────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF080E1A);
  static const Color surface0 = Color(0xFF0F1825); // lowest surface
  static const Color surface1 = Color(0xFF152030); // cards
  static const Color surface2 = Color(0xFF1C2A3E); // elevated cards
  static const Color panel = Color(0xFF152030);

  static const Color accent = Color(0xFF00C8F0);
  static const Color accentDim = Color(0xFF0080A8);
  static const Color caution = Color(0xFFF4A261);
  static const Color danger = Color(0xFFE63946);
  static const Color ok = Color(0xFF2DBD9F);
  static const Color info = Color(0xFF6B9FFF);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F4FA);
  static const Color textSecondary = Color(0xFF8EA8C4);
  static const Color textMuted = Color(0xFF4E6882);
  static const Color textAccent = accent;

  // ── Border ──────────────────────────────────────────────────────────────────
  static const Color border = Color(0xFF1F3048);
  static const Color borderStrong = Color(0xFF2A4060);

  // ── Spacing grid (8-pt) ─────────────────────────────────────────────────────
  static const double sp2 = 2;
  static const double sp4 = 4;
  static const double sp6 = 6;
  static const double sp8 = 8;
  static const double sp10 = 10;
  static const double sp12 = 12;
  static const double sp14 = 14;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  // ── Corner radii ────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 999;

  // ── Animation durations ─────────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 280);
  static const Duration durationSlow = Duration(milliseconds: 480);
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSnappy = Curves.easeInOutQuart;

  // ── Category colours ────────────────────────────────────────────────────────
  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return const Color(0xFFF4A261);
      case 'accident':
      case 'road_block':
      case 'road block':
      case 'crime':
        return const Color(0xFFE63946);
      case 'weather':
        return const Color(0xFF00C8F0);
      case 'intelligence':
        return const Color(0xFF00C8F0);
      case 'infrastructure':
      case 'construction':
      case 'system':
        return const Color(0xFF9B5DE5);
      case 'hotspot':
        return const Color(0xFFFF6B6B);
      case 'sudden_spike':
      case 'sudden spike':
        return const Color(0xFFFF9F1C);
      case 'protest':
        return const Color(0xFFFF6B6B);
      case 'fire':
        return const Color(0xFFFF9F1C);
      default:
        return const Color(0xFF6B9FFF);
    }
  }

  // ── Category icons ──────────────────────────────────────────────────────────
  static IconData categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return Icons.traffic_rounded;
      case 'accident':
        return Icons.car_crash_rounded;
      case 'road_block':
      case 'road block':
        return Icons.block_rounded;
      case 'crime':
        return Icons.local_police_rounded;
      case 'weather':
        return Icons.thunderstorm_rounded;
      case 'intelligence':
        return Icons.auto_awesome_rounded;
      case 'infrastructure':
      case 'construction':
        return Icons.construction_rounded;
      case 'system':
        return Icons.memory_rounded;
      case 'hotspot':
        return Icons.local_fire_department_rounded;
      case 'sudden_spike':
      case 'sudden spike':
        return Icons.trending_up_rounded;
      case 'protest':
        return Icons.groups_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  // ── Risk colour helper ───────────────────────────────────────────────────────
  static Color riskColor(double severity) {
    if (severity >= 0.7) return danger;
    if (severity >= 0.35) return caution;
    return ok;
  }

  static String riskLabel(double severity) {
    if (severity >= 0.7) return 'HIGH';
    if (severity >= 0.35) return 'MED';
    return 'LOW';
  }

  // ── Glassmorphism decoration helper ─────────────────────────────────────────
  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = radiusLg,
    double borderOpacity = 0.15,
  }) {
    return BoxDecoration(
      color: (color ?? surface1).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ── Gradient backgrounds ────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF080E1A), Color(0xFF0F1825), Color(0xFF101E2E)],
  );

  static LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDim],
  );

  // ── Material ThemeData ──────────────────────────────────────────────────────
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    const cs = ColorScheme.dark(
      primary: accent,
      secondary: caution,
      surface: surface1,
      error: danger,
      onPrimary: Color(0xFF00111A),
      onSurface: textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: cs,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface1,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
          side: BorderSide(color: border),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface0,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: sp16,
          vertical: sp12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: TextStyle(
          color: textMuted.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        elevation: 8,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : textMuted,
            size: 22,
          );
        }),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        labelStyle: const TextStyle(fontSize: 12, color: textSecondary),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: sp8, vertical: sp2),
      ),

      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.18),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.14),
        trackHeight: 3,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return accent.withValues(alpha: 0.3);
            }
            return accent;
          }),
          foregroundColor: WidgetStateProperty.all(const Color(0xFF00111A)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          minimumSize: WidgetStateProperty.all(
            const Size(double.infinity, 48),
          ),
        ),
      ),

      // Text
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

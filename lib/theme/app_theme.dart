import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class AppTheme {
  // ── Primary — Sage Green (matched to web --primary-xxx) ──────────────
  static const Color primary50 = Color(0xFFf2f7f4);
  static const Color primary100 = Color(0xFFdfeee4);
  static const Color primary200 = Color(0xFFc4dece);
  static const Color primary300 = Color(0xFFa8ccb4);
  static const Color primary400 = Color(0xFF8FAF9A); // Main Sage Green
  static const Color primary500 = Color(0xFF7a9e86);
  static const Color primary600 = Color(0xFF638170);
  static const Color primary700 = Color(0xFF4f6759);
  static const Color primary800 = Color(0xFF3b4d43);
  static const Color primary900 = Color(0xFF27332d);

  // ── Neutrals (warmer slate, matched to web --gray-xxx) ───────────────
  static const Color gray50 = Color(0xFFFDFBF7);
  static const Color gray100 = Color(0xFFF3EFEA);
  static const Color gray200 = Color(0xFFEAE6DF);
  static const Color gray300 = Color(0xFFd1cdc6);
  static const Color gray400 = Color(0xFF94908a);
  static const Color gray500 = Color(0xFF64748B);

  // ── Semantic / Status Colors ─────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF97316); // orange-500
  static const Color error = Color(0xFFEF4444);   // red-500
  static const Color info = Color(0xFF3B82F6);     // blue-500
  static const Color live = Color(0xFFF97316);     // orange-500 (live quiz accent)

  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFDFBF7);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF3EFEA);
  static const Color border = Color(0xFFEAE6DF);

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF334155);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);

  // ── Spacing scale (dp) ───────────────────────────────────────────────
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double spacingXxl = 32;

  // ── Border radii (matched to web: sm=8, md=12, lg=16, xl=24) ─────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 9999;

  // ── Animation duration ───────────────────────────────────────────────
  static const Duration transitionDuration = Duration(milliseconds: 200);

  // ═══════════════════════════════════════════════════════════════════════
  //  ThemeData
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary400,
        primary: primary400,
        secondary: primary600,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Plus Jakarta Sans',
      useMaterial3: true,

      // ── Page transitions ───────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
        },
      ),

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceCard,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // ── Cards ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
      ),

      // ── Elevated Buttons ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary400,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ───────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: primary400, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),

      // ── Text Theme ─────────────────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
    );
  }
}

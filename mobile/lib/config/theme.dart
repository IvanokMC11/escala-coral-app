import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

// ─── Paleta de colores ────────────────────────────────────
// Basada en la recomendación: elegante, universitaria, coral
class AppColors {
  // Primarios
  static const primary = Color(0xFFD32F2F);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryLight = Color(0xFFFDECEC);
  static const secondary = Color(0xFF374151);

  // Fondo y superficie
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF121212);
  static const cardDark = Color(0xFF1E1E1E);

  // Texto
  static const text = Color(0xFF222222);
  static const textSecondary = Color(0xFF6B7280);

  // Estados
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const eventRehearsal = Color(0xFF3B82F6);
  static const eventConcert = Color(0xFF8B5CF6);
  static const eventMeeting = Color(0xFF06B6D4);

  // Modo oscuro
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkText = Color(0xFFF5F5F5);
  static const darkTextSecondary = Color(0xFF9CA3AF);
}

/// Tema claro — profesional, limpio, con espacio y tarjetas blancas sobre fondo gris
ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,

    // ─── Tipografía ───────────────────────────────────────
    // fontFamily se deja sin definir para usar Roboto/Material default

    // ─── Transiciones ─────────────────────────────────
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
      },
    ),

    // ─── Cards ──────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
    ),

    // ─── AppBar ─────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
      ),
    ),

    // ─── Inputs ─────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.15))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans'),
      prefixIconColor: AppColors.textSecondary,
    ),

    // ─── Botones ───────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    // ─── Chips ────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryLight,
      labelStyle: TextStyle(color: AppColors.primary, fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),

    // ─── Bottom Navigation ────────────────────────────────
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
    ),

    // ─── Divider ─────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: AppColors.textSecondary.withValues(alpha: 0.12),
      thickness: 1,
      space: 24,
    ),
  );
}

/// Tema oscuro — ideal para ensayos nocturnos
ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: const Color(0xFFEF4444),
    onPrimary: const Color(0xFFFFFFFF),
    secondary: const Color(0xFF9CA3AF),
    surface: const Color(0xFF1E1E1E),
    error: const Color(0xFFEF4444),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.darkBackground,

    fontFamily: 'PlusJakartaSans',

    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
      },
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
    ),

    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkText,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: const Color(0xFFEF4444), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: AppColors.darkTextSecondary, fontFamily: 'PlusJakartaSans'),
      hintStyle: TextStyle(color: AppColors.darkTextSecondary.withValues(alpha: 0.6)),
      prefixIconColor: AppColors.darkTextSecondary,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
      labelStyle: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),

    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      thickness: 1,
      space: 24,
    ),
  );
}

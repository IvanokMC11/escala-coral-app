import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C4DFF),
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
      },
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C4DFF),
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
      },
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

import 'package:flutter/material.dart';

/// Shared visual identity for both apps. Calm, high-contrast, night-friendly —
/// appropriate for a device that is often viewed in the dark.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF4C6FFF);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    appBarTheme: const AppBarTheme(centerTitle: true),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true),
  );
}

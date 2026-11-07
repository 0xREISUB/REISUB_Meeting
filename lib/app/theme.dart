import 'package:flutter/material.dart';

/// Brand accent used by primary actions across the app.
const brandColor = Colors.deepPurpleAccent;

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  );
  final roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        shape: roundedShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: brandColor,
        side: const BorderSide(color: brandColor, width: 2),
        shape: roundedShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Shows [message] as an error using the theme's error colors.
void showErrorSnackBar(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: colorScheme.onError)),
      backgroundColor: colorScheme.error,
    ),
  );
}

import 'package:flutter/material.dart';

/// Brand accent used by primary actions across the app.
const brandColor = Colors.deepPurpleAccent;

/// The dark base every page shares, under its glass.
const pageBackground = Color(0xFF110F16);

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  );
  final roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  // Glass, for the parts drawn by Material itself: a faint white wash with a
  // thin light rim, over the dark base every page shares.
  const fill = Color(0x14FFFFFF);
  const rim = BorderSide(color: Color(0x24FFFFFF));
  const pane = Color(0xE01C1A22);
  final glassShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: rim,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: pageBackground,
    canvasColor: pageBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: fill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: glassShape,
    ),
    dividerTheme: const DividerThemeData(color: Color(0x1AFFFFFF)),
    dialogTheme: DialogThemeData(
      backgroundColor: pane,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: rim,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: pane,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x59000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: rim,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: pane,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: rim,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: pane,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: rim,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : const Color(0x33FFFFFF),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? brandColor : fill,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0x4DFFFFFF)
            : Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: brandColor.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: brandColor,
        shape: roundedShape.copyWith(
          side: const BorderSide(color: Color(0x40FFFFFF)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: fill,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x33FFFFFF)),
        shape: roundedShape,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandColor.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: rim,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: rim,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brandColor, width: 1.5),
      ),
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

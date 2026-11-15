import 'package:flutter/material.dart';

class Brand {
  static const violet = Color(0xFF7451F8);
  static const violetDeep = Color(0xFF5B3BE0);
  static const ink = Color(0xFF30223F);
  static const muted = Color(0xFF6D5B7D);
  static const bg = Color(0xFFF7F5FB);
  static const border = Color(0xFFE4DBEA);
  static const surface = Colors.white;
  static const success = Color(0xFF1F9D6B);
  static const warning = Color(0xFFE08A1E);
  static const danger = Color(0xFFD64561);

  static const payGradient = LinearGradient(
    colors: [Color(0xFF7451F8), Color(0xFFA25CF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const financeGradient = LinearGradient(
    colors: [Color(0xFF7451F8), Color(0xFF4A3FD8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: violet.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.violet,
    primary: Brand.violet,
    surface: Brand.surface,
    brightness: Brightness.light,
  );
  const radius = BorderRadius.all(Radius.circular(16));
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.bg,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    textTheme: Typography.material2021().black.apply(
      bodyColor: Brand.ink,
      displayColor: Brand.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.bg,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Brand.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Brand.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Brand.border),
      enabledBorder: border(Brand.border),
      focusedBorder: border(Brand.violet, 2),
      errorBorder: border(Brand.danger),
      focusedErrorBorder: border(Brand.danger, 2),
      labelStyle: const TextStyle(color: Brand.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: Brand.violet,
        side: const BorderSide(color: Brand.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Brand.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Brand.border, space: 1),
  );
}

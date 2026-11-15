import 'package:material_ui/material_ui.dart';

/// Design tokens taken from the Equitensa web app so web and app feel like one product.
class Eq {
  static const violet = Color(0xFF7451F8);
  static const violetDeep = Color(0xFF5B3BE0);
  static const violetSoft = Color(0xFFF0ECFA);
  static const ink = Color(0xFF211C32);
  static const ink2 = Color(0xFF30223F);
  static const muted = Color(0xFF6D5B7D);
  static const faint = Color(0xFF9A8DAA);
  static const bg = Color(0xFFF7F5FB);
  static const page = Color(0xFFFAF9FE);
  static const line = Color(0xFFE4DBEA);
  static const lineSoft = Color(0xFFEEEAF3);
  static const surface = Colors.white;

  static const plum = Color(0xFF191526);
  static const plum2 = Color(0xFF34234E);
  static const plumLine = Color(0xFF352A45);
  static const onPlum = Color(0xFFEDE8F6);
  static const onPlumMuted = Color(0xFFC8BDD7);

  static const success = Color(0xFF1F9D6B);
  static const warning = Color(0xFFC7791B);
  static const danger = Color(0xFFD64561);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF2A1D3D), Color(0xFF4A2F7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF8A6BFF), Color(0xFF6A45F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF3F2750).withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: violet.withValues(alpha: 0.35),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}

const _font = 'Inter';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Eq.violet,
    primary: Eq.violet,
    surface: Eq.surface,
    brightness: Brightness.light,
  );
  const r12 = BorderRadius.all(Radius.circular(12));
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: r12,
    borderSide: BorderSide(color: c, width: w),
  );

  final base = Typography.material2021().black.apply(
    fontFamily: _font,
    bodyColor: Eq.ink,
    displayColor: Eq.ink,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: _font,
    colorScheme: scheme,
    scaffoldBackgroundColor: Eq.page,
    textTheme: base,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Eq.page,
      foregroundColor: Eq.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Eq.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border(const Color(0xFFDCD5E8)),
      enabledBorder: border(const Color(0xFFDCD5E8)),
      focusedBorder: border(Eq.violet, 1.6),
      errorBorder: border(Eq.danger),
      focusedErrorBorder: border(Eq.danger, 1.6),
      hintStyle: const TextStyle(color: Eq.faint, fontWeight: FontWeight.w400),
      labelStyle: const TextStyle(color: Eq.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Eq.ink2,
      contentTextStyle: const TextStyle(
        fontFamily: _font,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Eq.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Eq.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(
      color: Eq.lineSoft,
      space: 1,
      thickness: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: Color(0xFFBFB3D0), width: 1.4),
    ),
  );
}

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

/// Semantic colors shared by every application surface. Documents keep their
/// own paper palette so changing appearance never changes an invoice or PDF.
class EqPalette {
  const EqPalette(this.dark);
  final bool dark;
  static EqPalette of(BuildContext context) => EqPalette(Theme.of(context).brightness == Brightness.dark);
  Color get ink => dark ? const Color(0xFFF3F0FA) : Eq.ink;
  Color get ink2 => dark ? const Color(0xFFE8E1F4) : Eq.ink2;
  Color get muted => dark ? const Color(0xFFB4ABBF) : Eq.muted;
  Color get faint => dark ? const Color(0xFF968CA5) : const Color(0xFF80728D);
  Color get page => dark ? const Color(0xFF111218) : Eq.page;
  Color get bg => dark ? const Color(0xFF171820) : Eq.bg;
  Color get surface => dark ? const Color(0xFF20212B) : Eq.surface;
  Color get line => dark ? const Color(0xFF3C3749) : Eq.line;
  Color get lineSoft => dark ? const Color(0xFF2E2B39) : Eq.lineSoft;
  Color get violetSoft => dark ? const Color(0xFF332A48) : Eq.violetSoft;
  Color get accent => dark ? const Color(0xFFC6B6FF) : Eq.violetDeep;
  Color get error => dark ? const Color(0xFFFF9CB0) : const Color(0xFFB42344);
}

extension EquitensaColors on BuildContext {
  EqPalette get eq => EqPalette.of(this);
}

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final palette = EqPalette(brightness == Brightness.dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: Eq.violet,
    primary: Eq.violet,
    surface: palette.surface,
    brightness: brightness,
  );
  const r12 = BorderRadius.all(Radius.circular(12));
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: r12,
    borderSide: BorderSide(color: c, width: w),
  );

  final typography = Typography.material2021();
  final base = (palette.dark ? typography.white : typography.black).apply(
    fontFamily: _font,
    bodyColor: palette.ink,
    displayColor: palette.ink,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: _font,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.page,
    textTheme: base,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.page,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border(const Color(0xFFDCD5E8)),
      enabledBorder: border(palette.line),
      focusedBorder: border(Eq.violet, 1.6),
      errorBorder: border(Eq.danger),
      focusedErrorBorder: border(Eq.danger, 1.6),
      hintStyle: TextStyle(color: palette.faint, fontWeight: FontWeight.w400),
      labelStyle: TextStyle(color: palette.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Eq.plum2,
      contentTextStyle: const TextStyle(
        fontFamily: _font,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: palette.lineSoft,
      space: 1,
      thickness: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: Color(0xFFBFB3D0), width: 1.4),
    ),
  );
}

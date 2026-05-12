import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── DESIGN TOKENS (mirrors shell.css :root) ──────────────────────────────
class GeoColors {
  // Brand
  static const primary       = Color(0xFFDC2626); // #dc2626
  static const primaryLight  = Color(0xFFEF4444); // #ef4444
  static const primaryDark   = Color(0xFFB91C1C); // #b91c1c
  static const primaryGhost  = Color(0x14DC2626); // rgba(220,38,38,.08)
  static const accent        = Color(0xFFF87171); // #f87171

  // Semantic
  static const danger        = Color(0xFFDC2626);
  static const dangerGhost   = Color(0x1ADC2626); // rgba(220,38,38,.10)
  static const warning       = Color(0xFFF59E0B);
  static const warningGhost  = Color(0x1AF59E0B);
  static const success       = Color(0xFF22C55E);
  static const successGhost  = Color(0x1A22C55E);
  static const online        = Color(0xFF22C55E);

  // Light surfaces
  static const bgBodyLight        = Color(0xFFF5F5F5);
  static const bgSidebarLight     = Color(0xFF111111);
  static const bgCardLight        = Color(0xFFFFFFFF);
  static const bgInputLight       = Color(0xFFF9F9F9);
  static const bgBadgeLight       = Color(0xFFF1F1F1);
  static const textPrimaryLight   = Color(0xFF111111);
  static const textSecondaryLight = Color(0xFF555555);
  static const textTertiaryLight  = Color(0xFF999999);
  static const borderLight        = Color(0xFFE4E4E4);

  // Dark surfaces
  static const bgBodyDark         = Color(0xFF0D0D0D);
  static const bgSidebarDark      = Color(0xFF000000);
  static const bgCardDark         = Color(0xFF1A1A1A);
  static const bgInputDark        = Color(0xFF222222);
  static const bgBadgeDark        = Color(0xFF2A2A2A);
  static const textPrimaryDark    = Color(0xFFF0F0F0);
  static const textSecondaryDark  = Color(0xFFAAAAAA);
  static const textTertiaryDark   = Color(0xFF666666);
  static const borderDark         = Color(0xFF333333);

  // Auth page background
  static const authBg            = Color(0xFF0A0A0A);

  // Avatar gradients (from PEOPLE pool in shell.js)
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFDC2626), Color(0xFF991B1B)],
    [Color(0xFF2563EB), Color(0xFF1E3A8A)],
    [Color(0xFF16A34A), Color(0xFF14532D)],
    [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    [Color(0xFFDB2777), Color(0xFF831843)],
    [Color(0xFF0891B2), Color(0xFF164E63)],
    [Color(0xFFD97706), Color(0xFF92400E)],
    [Color(0xFF059669), Color(0xFF064E3B)],
    [Color(0xFF6366F1), Color(0xFF312E81)],
    [Color(0xFFEA580C), Color(0xFF7C2D12)],
    [Color(0xFF0EA5E9), Color(0xFF0C4A6E)],
  ];
}

// ── RADII ────────────────────────────────────────────────────────────────
class GeoRadius {
  static const sm   = 6.0;
  static const md   = 10.0;
  static const lg   = 14.0;
  static const full = 999.0;
}

// ── SHADOWS ──────────────────────────────────────────────────────────────
class GeoShadows {
  static List<BoxShadow> sm() => [
    BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 2, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> md() => [
    BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 12, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> lg() => [
    BoxShadow(color: Colors.black.withOpacity(.09), blurRadius: 30, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> cardHover({bool dark = false}) => [
    BoxShadow(
      color: Colors.black.withOpacity(dark ? .4 : .09),
      blurRadius: 25, offset: const Offset(0, 10),
    ),
  ];
  static List<BoxShadow> primaryGlow() => [
    BoxShadow(color: GeoColors.primary.withOpacity(.4), blurRadius: 24, offset: const Offset(0, 8)),
  ];
}

// ── THEME NOTIFIER ────────────────────────────────────────────────────────
class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setDark(bool v) {
    _isDark = v;
    notifyListeners();
  }

  // Convenience getters mirroring CSS variables
  Color get bgBody        => _isDark ? GeoColors.bgBodyDark        : GeoColors.bgBodyLight;
  Color get bgSidebar     => _isDark ? GeoColors.bgSidebarDark     : GeoColors.bgSidebarLight;
  Color get bgCard        => _isDark ? GeoColors.bgCardDark        : GeoColors.bgCardLight;
  Color get bgInput       => _isDark ? GeoColors.bgInputDark       : GeoColors.bgInputLight;
  Color get bgBadge       => _isDark ? GeoColors.bgBadgeDark       : GeoColors.bgBadgeLight;
  Color get textPrimary   => _isDark ? GeoColors.textPrimaryDark   : GeoColors.textPrimaryLight;
  Color get textSecondary => _isDark ? GeoColors.textSecondaryDark : GeoColors.textSecondaryLight;
  Color get textTertiary  => _isDark ? GeoColors.textTertiaryDark  : GeoColors.textTertiaryLight;
  Color get border        => _isDark ? GeoColors.borderDark        : GeoColors.borderLight;
  Color get tableRowHover => _isDark ? const Color(0xFF2A1515)     : const Color(0xFFFEF2F2);
}

// ── MATERIAL THEME BUILDER ────────────────────────────────────────────────
ThemeData buildTheme({required bool dark}) {
  final base = dark ? ThemeData.dark() : ThemeData.light();
  final bg   = dark ? GeoColors.bgBodyDark  : GeoColors.bgBodyLight;
  final card = dark ? GeoColors.bgCardDark  : GeoColors.bgCardLight;
  final text = dark ? GeoColors.textPrimaryDark : GeoColors.textPrimaryLight;

  return base.copyWith(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary:   GeoColors.primary,
      onPrimary: Colors.white,
      secondary: GeoColors.primaryLight,
      onSecondary: Colors.white,
      error:     GeoColors.danger,
      onError:   Colors.white,
      surface:   card,
      onSurface: text,
    ),
    scaffoldBackgroundColor: bg,
    cardColor:  card,
    textTheme:  GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor:       text,
      displayColor:    text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:     true,
      fillColor:  dark ? GeoColors.bgInputDark : GeoColors.bgInputLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GeoRadius.md),
        borderSide:   BorderSide(color: dark ? GeoColors.borderDark : GeoColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GeoRadius.md),
        borderSide: const BorderSide(color: GeoColors.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GeoColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.md)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    dividerColor: dark ? GeoColors.borderDark : GeoColors.borderLight,
  );
}

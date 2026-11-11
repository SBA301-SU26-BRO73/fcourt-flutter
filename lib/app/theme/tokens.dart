import 'package:flutter/material.dart';

/// 4-pt spacing grid.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal screen margin on phones.
  static const double screen = 20;
}

/// Corner radii. Nested shapes stay concentric: inner = outer − padding.
abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double input = 18;
  static const double lg = 22;
  static const double card = 24;
  static const double xl = 28;
  static const double sheet = 32;
  static const double pill = 999;
}

/// Brand tokens that Material's [ColorScheme] has no role for.
@immutable
class FcTokens extends ThemeExtension<FcTokens> {
  const FcTokens({
    required this.brandGradient,
    required this.onBrandMuted,
    required this.wallpaper,
    required this.glows,
    required this.frostedFill,
    required this.frostedStrong,
    required this.hairline,
    required this.shadowColor,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Teal → cyan → indigo, used for heroes and prominent accents.
  final List<Color> brandGradient;

  /// Secondary text on top of [brandGradient].
  final Color onBrandMuted;

  /// Base colour of the aurora wallpaper.
  final Color wallpaper;

  /// Soft glows of the wallpaper: (colour, centre, radius factor).
  final List<(Color, Alignment, double)> glows;

  /// Translucent fill of content cards resting on the wallpaper.
  final Color frostedFill;

  /// Denser fill for inputs and controls that need more contrast.
  final Color frostedStrong;

  /// Light-catching 1px edge of frosted surfaces.
  final Color hairline;
  final Color shadowColor;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  LinearGradient get brand => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandGradient,
  );

  /// Soft, tinted, far-reaching shadow. Never a hard black one.
  List<BoxShadow> get shadow => [
    BoxShadow(color: shadowColor, blurRadius: 32, offset: const Offset(0, 14)),
  ];

  List<BoxShadow> get shadowSmall => [
    BoxShadow(color: shadowColor, blurRadius: 16, offset: const Offset(0, 6)),
  ];

  static const light = FcTokens(
    brandGradient: [Color(0xFF00A98C), Color(0xFF0A8DB3), Color(0xFF6A6CE0)],
    onBrandMuted: Color(0xFFD6FBF1),
    wallpaper: Color(0xFFF1F7F8),
    glows: [
      (Color(0xFFAEF0DC), Alignment(-1.1, -1.05), .95),
      (Color(0xFFBCDFFC), Alignment(1.15, -.7), .85),
      (Color(0xFFDAD4FF), Alignment(1.1, .75), .9),
      (Color(0xFFFFEBD6), Alignment(-1.1, .95), .7),
    ],
    frostedFill: Color(0xB8FFFFFF),
    frostedStrong: Color(0xD9FFFFFF),
    hairline: Color(0xE6FFFFFF),
    shadowColor: Color(0x1F0B5266),
    success: Color(0xFF0E9F6E),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2F4B),
    info: Color(0xFF2B7FD9),
  );

  static const dark = FcTokens(
    brandGradient: [Color(0xFF009C82), Color(0xFF0B7FA6), Color(0xFF5D5FD3)],
    onBrandMuted: Color(0xFFCFF7EC),
    wallpaper: Color(0xFF0A1822),
    glows: [
      (Color(0xFF0C5F55), Alignment(-1.1, -1.05), .95),
      (Color(0xFF12466E), Alignment(1.15, -.7), .85),
      (Color(0xFF33307F), Alignment(1.1, .75), .9),
      (Color(0xFF0B3F4A), Alignment(-1.1, .95), .7),
    ],
    frostedFill: Color(0x14FFFFFF),
    frostedStrong: Color(0x1FFFFFFF),
    hairline: Color(0x24FFFFFF),
    shadowColor: Color(0x52000000),
    success: Color(0xFF4ADE9F),
    warning: Color(0xFFFBBF4A),
    danger: Color(0xFFFF7A8C),
    info: Color(0xFF7CB8FF),
  );

  @override
  FcTokens copyWith() => this;

  @override
  FcTokens lerp(FcTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

extension FcTokensContext on BuildContext {
  /// Brand tokens of the current theme (falls back to light/dark defaults when
  /// a screen is hosted under a bare [ThemeData]).
  FcTokens get fc {
    final theme = Theme.of(this);
    return theme.extension<FcTokens>() ??
        (theme.brightness == Brightness.dark ? FcTokens.dark : FcTokens.light);
  }
}

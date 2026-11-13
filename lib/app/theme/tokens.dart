import 'package:flutter/material.dart';

/// Spacing on a 4-pt grid (8-pt for the larger steps).
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal screen margin on phones.
  static const double screen = 16;

  /// Minimum touch target (Material and WCAG 2.5.8).
  static const double touch = 48;

  /// Room a scrolling list leaves at its end so a floating action button
  /// never covers the last item (56dp button + 16dp margin + 16dp air).
  static const double fabClearance = 88;

  /// Room a scrolling list leaves at its end so the floating navigation bar
  /// (68dp bar + 12dp margin) never hides the last item. Use it as bottom
  /// padding when a screen extends behind the bar. Equals
  /// FloatingNavBar.clearance.
  static const double navClearance = 96;

  /// Same for a screen that ends with a FloatingBottomBar (price + action):
  /// bar height 72dp + 12dp margin + 12dp air.
  static const double bottomBarClearance = 96;
}

/// Corner radii: three steps, plus the sheet and the pill.
abstract final class Radii {
  /// Small badges, tags, tooltips.
  static const double sm = 10;

  /// Buttons, inputs, list tiles, slots, inner blocks.
  static const double md = 16;

  /// Cards and dialogs.
  static const double lg = 20;

  /// Photo cards, hero photos.
  static const double xl = 24;

  /// Bottom sheets and the hero header's lower corners.
  static const double sheet = 28;

  /// Pills: buttons, chips, search field, floating bars.
  static const double pill = 999;
}

/// A status colour with its tinted container. Text in [color] on
/// [container] reaches WCAG AA (4.5:1) in both brightnesses.
@immutable
class StatusTone {
  const StatusTone(this.color, this.container);
  final Color color;
  final Color container;
}

/// Status colours that Material's [ColorScheme] has no role for.
@immutable
class FcTokens extends ThemeExtension<FcTokens> {
  const FcTokens({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
  });

  final StatusTone success;
  final StatusTone warning;
  final StatusTone danger;
  final StatusTone info;
  final StatusTone neutral;

  static const light = FcTokens(
    success: StatusTone(Color(0xFF0E7550), Color(0xFFE6F5ED)),
    warning: StatusTone(Color(0xFF8A610C), Color(0xFFFFF3D2)),
    danger: StatusTone(Color(0xFF9F1D17), Color(0xFFFCE4E1)),
    info: StatusTone(Color(0xFF3928B9), Color(0xFFEFEDFF)),
    neutral: StatusTone(Color(0xFF3D4A63), Color(0xFFEEF0F6)),
  );

  static const dark = FcTokens(
    success: StatusTone(Color(0xFF8CE4B5), Color(0xFF163E36)),
    warning: StatusTone(Color(0xFFF0CF7B), Color(0xFF423924)),
    danger: StatusTone(Color(0xFFFFB4AB), Color(0xFF4F2326)),
    info: StatusTone(Color(0xFFB9C2FF), Color(0xFF26325E)),
    neutral: StatusTone(Color(0xFFC4D0E4), Color(0xFF243449)),
  );

  @override
  FcTokens copyWith() => this;

  @override
  FcTokens lerp(FcTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

extension FcTokensContext on BuildContext {
  /// Status tokens of the current theme (falls back to light/dark defaults
  /// when a screen is hosted under a bare [ThemeData]).
  FcTokens get fc {
    final theme = Theme.of(this);
    return theme.extension<FcTokens>() ??
        (theme.brightness == Brightness.dark ? FcTokens.dark : FcTokens.light);
  }
}

/// Mid-tone colours for charts and calendar marks. Each reaches 3:1 against
/// both the light and the dark page (WCAG 1.4.11), so one set serves both.
abstract final class ChartColors {
  static const success = Color(0xFF2B9E70);
  static const warning = Color(0xFFC77A00);
  static const peak = Color(0xFFD1661A);
  static const danger = Color(0xFFD9483F);
  static const info = Color(0xFF2F80C8);
  static const accent = Color(0xFF6F61F5);
  static const neutral = Color(0xFF7C8C90);
  static const gold = Color(0xFFC99700);
  static const bronze = Color(0xFFB87333);
}

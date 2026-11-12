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
}

/// Corner radii: three steps, plus the sheet and the pill.
abstract final class Radii {
  /// Chips, small badges, tooltips, inputs.
  static const double sm = 8;

  /// Buttons, list tiles, inner blocks.
  static const double md = 12;

  /// Cards and dialogs.
  static const double lg = 16;

  /// Bottom sheets only.
  static const double sheet = 28;
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
    success: StatusTone(Color(0xFF166534), Color(0xFFD9F2E1)),
    warning: StatusTone(Color(0xFF7A4A00), Color(0xFFFFEBC7)),
    danger: StatusTone(Color(0xFF9F1D17), Color(0xFFFBE0DD)),
    info: StatusTone(Color(0xFF0B5483), Color(0xFFD9EBF8)),
    neutral: StatusTone(Color(0xFF3F5157), Color(0xFFE3EAE8)),
  );

  static const dark = FcTokens(
    success: StatusTone(Color(0xFF8FDCA8), Color(0xFF1A3827)),
    warning: StatusTone(Color(0xFFFFCF7A), Color(0xFF442E00)),
    danger: StatusTone(Color(0xFFFFB4AB), Color(0xFF5C1A16)),
    info: StatusTone(Color(0xFF9CCBF0), Color(0xFF163349)),
    neutral: StatusTone(Color(0xFFC4D2D2), Color(0xFF2A3438)),
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
  static const success = Color(0xFF2B9457);
  static const warning = Color(0xFFC77A00);
  static const peak = Color(0xFFD1661A);
  static const danger = Color(0xFFD9483F);
  static const info = Color(0xFF2F80C8);
  static const accent = Color(0xFF15907F);
  static const neutral = Color(0xFF7C8C90);
  static const gold = Color(0xFFC99700);
  static const bronze = Color(0xFFB87333);
}

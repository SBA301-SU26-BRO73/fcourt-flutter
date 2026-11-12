import 'package:flutter/material.dart';

/// Colours of the WP3b look (approved mock-up): white page with an indigo
/// accent, or navy page with a lime accent.
///
/// Every text/background pair
/// used by the picker reaches WCAG AA (4.5:1) in both modes. The whole app
/// theme ([AppTheme]) is built from these same values, so the picker and the
/// rest of the app share one palette.
@immutable
class SlotPickerPalette {
  const SlotPickerPalette._({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.danger,
  });

  final Color background,
      surface,
      surfaceRaised,
      line,
      text,
      muted,
      accent,
      onAccent,
      accentSoft,
      danger;

  static const light = SlotPickerPalette._(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF5F5FA),
    line: Color(0xFFE9EBF2),
    text: Color(0xFF172238),
    muted: Color(0xFF5F6C84),
    accent: Color(0xFF4F3FE8),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEFEDFF),
    danger: Color(0xFFB3261E),
  );

  static const dark = SlotPickerPalette._(
    background: Color(0xFF0E1A2B),
    surface: Color(0xFF18273B),
    surfaceRaised: Color(0xFF1F3048),
    line: Color(0xFF2B3C51),
    text: Color(0xFFF3F6FF),
    muted: Color(0xFFA4B4CA),
    accent: Color(0xFFE4F45A),
    onAccent: Color(0xFF142334),
    accentSoft: Color(0xFF293831),
    danger: Color(0xFFFFB4AB),
  );

  static SlotPickerPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Motion durations, collapsed to zero when the user disabled animations.
Duration slotMotion(BuildContext context, [int milliseconds = 200]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

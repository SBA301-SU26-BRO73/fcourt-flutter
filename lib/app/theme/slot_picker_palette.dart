import 'package:flutter/material.dart';

/// Flat solid colors of the slot picker (approved mock-up, light and dark).
///
/// One teal accent, no gradients or translucency. Every text/background pair
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
    background: Color(0xFFF6F9F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEAF3F1),
    line: Color(0xFFD3E0DC),
    text: Color(0xFF14252A),
    muted: Color(0xFF51636A),
    accent: Color(0xFF006E65),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFD9F0EB),
    danger: Color(0xFFB3261E),
  );

  static const dark = SlotPickerPalette._(
    background: Color(0xFF0F1417),
    surface: Color(0xFF161C20),
    surfaceRaised: Color(0xFF1E272C),
    line: Color(0xFF334045),
    text: Color(0xFFEAF2F1),
    muted: Color(0xFFAEC0C0),
    accent: Color(0xFF7FD8C9),
    onAccent: Color(0xFF05302B),
    accentSoft: Color(0xFF173F3B),
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

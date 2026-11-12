import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'slot_picker_palette.dart';
import 'tokens.dart';

class AppColors {
  const AppColors._();

  /// Seed of the Material 3 colour scheme: the single teal accent.
  static const primary = Color(0xFF006E65);
}

/// Material 3 theme. Flat solid surfaces (no gradients, glass or glow), one
/// teal accent, cards one step above the page, secondary text at AA contrast.
/// Every colour comes from [SlotPickerPalette] and [FcTokens].
class AppTheme {
  const AppTheme._();
  static const fontFamily = 'BeVietnamPro';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final p = dark ? SlotPickerPalette.dark : SlotPickerPalette.light;
    return ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: dark
          ? const Color(0xFFBFEFE6)
          : const Color(0xFF00403A),
      // One accent only: secondary and tertiary are quiet teal-greys.
      secondary: dark ? const Color(0xFFB0CCC7) : const Color(0xFF3E5651),
      onSecondary: dark ? const Color(0xFF173F3B) : Colors.white,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: dark
          ? const Color(0xFFBFEFE6)
          : const Color(0xFF00403A),
      tertiary: dark ? const Color(0xFFB0CCC7) : const Color(0xFF3E5651),
      onTertiary: dark ? const Color(0xFF173F3B) : Colors.white,
      tertiaryContainer: p.surfaceRaised,
      onTertiaryContainer: p.text,
      error: p.danger,
      onError: dark ? const Color(0xFF601410) : Colors.white,
      errorContainer: dark ? const Color(0xFF5C1A16) : const Color(0xFFFBE0DD),
      onErrorContainer: dark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF601410),
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: dark ? const Color(0xFF0B1013) : Colors.white,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceRaised,
      surfaceContainerHigh: dark
          ? const Color(0xFF263136)
          : const Color(0xFFE1ECE9),
      surfaceContainerHighest: dark
          ? const Color(0xFF2E3A40)
          : const Color(0xFFD8E5E2),
      outline: dark ? const Color(0xFF879A9E) : const Color(0xFF6B7F85),
      outlineVariant: p.line,
      inverseSurface: dark ? const Color(0xFFE3EEEC) : const Color(0xFF223237),
      onInverseSurface: dark ? const Color(0xFF14252A) : Colors.white,
      inversePrimary: dark ? const Color(0xFF006E65) : const Color(0xFF7FD8C9),
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final fc = dark ? FcTokens.dark : FcTokens.light;
    final scheme = AppTheme.scheme(brightness);

    final text = _textTheme(
      (dark ? Typography.whiteMountainView : Typography.blackMountainView)
          .merge(Typography.englishLike2021),
      scheme,
    );
    const pill = StadiumBorder();
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(color: scheme.outlineVariant),
    );
    OutlineInputBorder input(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: color, width: width),
        );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: .1,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      extensions: [fc],
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        systemOverlayStyle:
            (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        minTileHeight: Gap.touch,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: input(scheme.outline),
        enabledBorder: input(scheme.outline),
        disabledBorder: input(scheme.outlineVariant),
        focusedBorder: input(scheme.primary, 2),
        errorBorder: input(scheme.error),
        focusedErrorBorder: input(scheme.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          padding: buttonPadding,
          elevation: 0,
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: scheme.primary,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          padding: buttonPadding,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        extendedTextStyle: buttonText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: pill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 8),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          backgroundColor: scheme.surfaceContainerLow,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outline),
          textStyle: buttonText,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: scheme.outlineVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: buttonText,
        unselectedLabelStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: .08),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: scheme.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: scheme.onInverseSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }

  /// Be Vietnam Pro, three weights (400, 500, 700). Screen titles stay at 22sp
  /// and below; nothing is smaller than 12sp.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? style(
      TextStyle? source,
      FontWeight weight,
      double size, {
      double? height,
    }) => source?.copyWith(
      fontFamily: fontFamily,
      fontWeight: weight,
      fontSize: size,
      letterSpacing: 0,
      height: height,
      color: scheme.onSurface,
    );
    return base.copyWith(
      displayLarge: style(base.displayLarge, FontWeight.w700, 40, height: 1.2),
      displayMedium: style(
        base.displayMedium,
        FontWeight.w700,
        34,
        height: 1.2,
      ),
      displaySmall: style(base.displaySmall, FontWeight.w700, 28, height: 1.25),
      headlineLarge: style(
        base.headlineLarge,
        FontWeight.w700,
        26,
        height: 1.25,
      ),
      headlineMedium: style(
        base.headlineMedium,
        FontWeight.w700,
        24,
        height: 1.25,
      ),
      headlineSmall: style(
        base.headlineSmall,
        FontWeight.w700,
        22,
        height: 1.3,
      ),
      titleLarge: style(base.titleLarge, FontWeight.w700, 20, height: 1.3),
      titleMedium: style(base.titleMedium, FontWeight.w700, 16, height: 1.4),
      titleSmall: style(base.titleSmall, FontWeight.w700, 14, height: 1.4),
      bodyLarge: style(base.bodyLarge, FontWeight.w400, 16, height: 1.5),
      bodyMedium: style(base.bodyMedium, FontWeight.w400, 14, height: 1.5),
      bodySmall: style(base.bodySmall, FontWeight.w400, 12, height: 1.45),
      labelLarge: style(base.labelLarge, FontWeight.w700, 14),
      labelMedium: style(base.labelMedium, FontWeight.w500, 12),
      labelSmall: style(base.labelSmall, FontWeight.w500, 12),
    );
  }
}

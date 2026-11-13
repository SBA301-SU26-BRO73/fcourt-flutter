import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'slot_picker_palette.dart';
import 'tokens.dart';

class AppColors {
  const AppColors._();

  /// Seed of the Material 3 colour scheme: the indigo accent (light mode).
  static const primary = Color(0xFF4F3FE8);

  /// Lime accent of the dark mode and the rank badge on photos.
  static const lime = Color(0xFFE4F45A);

  /// Deep indigo of the filled bottom bar (light mode).
  static const indigoDeep = Color(0xFF3928B9);
}

/// WP3b theme (approved mock-up): white page with an indigo accent, or navy
/// page with a lime accent; Plus Jakarta Sans; radii 16 to 24; pill buttons.
/// Every colour comes from [SlotPickerPalette] and [FcTokens].
class AppTheme {
  const AppTheme._();
  static const fontFamily = 'PlusJakartaSans';

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
      onPrimaryContainer: dark ? AppColors.lime : AppColors.indigoDeep,
      secondary: dark ? const Color(0xFFB9C7DD) : const Color(0xFF3D4A63),
      onSecondary: dark ? const Color(0xFF142334) : Colors.white,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: dark ? AppColors.lime : AppColors.indigoDeep,
      tertiary: dark ? const Color(0xFF8CE4B5) : const Color(0xFF0E7550),
      onTertiary: dark ? const Color(0xFF0E1A2B) : Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF163E36)
          : const Color(0xFFE6F5ED),
      onTertiaryContainer: dark
          ? const Color(0xFF8CE4B5)
          : const Color(0xFF0E7550),
      error: p.danger,
      onError: dark ? const Color(0xFF601410) : Colors.white,
      errorContainer: dark ? const Color(0xFF4F2326) : const Color(0xFFFCE4E1),
      onErrorContainer: dark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF601410),
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: dark ? const Color(0xFF0A1424) : Colors.white,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceRaised,
      surfaceContainerHigh: dark
          ? const Color(0xFF1F3048)
          : const Color(0xFFFFFFFF),
      surfaceContainerHighest: dark
          ? const Color(0xFF28405C)
          : const Color(0xFFECECF6),
      outline: dark ? const Color(0xFF8396B0) : const Color(0xFF8791A6),
      outlineVariant: p.line,
      inverseSurface: dark ? const Color(0xFFF3F6FF) : const Color(0xFF172238),
      onInverseSurface: dark ? const Color(0xFF142334) : Colors.white,
      inversePrimary: dark ? const Color(0xFF4F3FE8) : const Color(0xFFC9C3FF),
      surfaceTint: Colors.transparent,
      shadow: const Color(0xFF14213C),
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
        centerTitle: true,
        elevation: 0,
        toolbarHeight: 58,
        systemOverlayStyle:
            (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: text.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const _RoundNavIcon(Icons.chevron_left),
        closeButtonIconBuilder: (_) => const _RoundNavIcon(Icons.close),
        drawerButtonIconBuilder: (_) => const _RoundNavIcon(Icons.menu),
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
        fillColor: scheme.surfaceContainer,
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
        border: input(scheme.outlineVariant),
        enabledBorder: input(scheme.outlineVariant),
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
          side: BorderSide(color: scheme.outlineVariant, width: 1.4),
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
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        shape: pill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 8),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(Gap.touch, Gap.touch),
          backgroundColor: scheme.surfaceContainerLow,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
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
        unselectedLabelStyle: buttonText.copyWith(fontWeight: FontWeight.w600),
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
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
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
          fontWeight: FontWeight.w600,
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

  /// Plus Jakarta Sans, three weights (400, 600, 700). Screen titles stay at
  /// 22sp and below; nothing is smaller than 12sp.
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
      labelMedium: style(base.labelMedium, FontWeight.w600, 12),
      labelSmall: style(base.labelSmall, FontWeight.w600, 12),
    );
  }
}

/// Circle with a thin line around an icon: the back, close and menu buttons of
/// every AppBar (mock-up: 42dp circle, hairline border).
class _RoundNavIcon extends StatelessWidget {
  const _RoundNavIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Icon(icon, size: 24, color: colors.onSurface),
    );
  }
}

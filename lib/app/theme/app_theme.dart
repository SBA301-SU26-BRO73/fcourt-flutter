import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_backdrop.dart';
import 'tokens.dart';

class AppColors {
  const AppColors._();
  static const primary = Color(0xFF007F75);
}

class AppTheme {
  const AppTheme._();
  static const fontFamily = 'BeVietnamPro';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final fc = dark ? FcTokens.dark : FcTokens.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF5FE3C4) : AppColors.primary,
          onPrimary: dark ? const Color(0xFF04302F) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF0E4A47)
              : const Color(0xFFCFF5EA),
          onPrimaryContainer: dark
              ? const Color(0xFFB9F6E6)
              : const Color(0xFF00403B),
          secondary: dark ? const Color(0xFF9BA8FF) : const Color(0xFF5458D6),
          tertiary: dark ? const Color(0xFF7FD3F7) : const Color(0xFF0A7EA4),
          surface: dark ? const Color(0xFF13283A) : Colors.white,
          onSurface: dark ? const Color(0xFFEFFAFD) : const Color(0xFF10293A),
          onSurfaceVariant: dark
              ? const Color(0xFFA9C2CC)
              : const Color(0xFF526A78),
          surfaceContainerLowest: dark ? const Color(0xFF0D1E2B) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xFF152B3D)
              : const Color(0xFFF6FAFA),
          surfaceContainer: dark
              ? const Color(0xFF183044)
              : const Color(0xFFF0F6F6),
          surfaceContainerHigh: dark
              ? const Color(0xFF1C364B)
              : const Color(0xFFE9F2F2),
          surfaceContainerHighest: dark
              ? const Color(0xFF223D53)
              : const Color(0xFFE1ECEC),
          outline: dark ? const Color(0xFF5E7C8A) : const Color(0xFF8AA3AD),
          outlineVariant: dark
              ? const Color(0xFF2C4A5C)
              : const Color(0xFFD5E6E6),
          error: dark ? const Color(0xFFFF8B9A) : const Color(0xFFD12B46),
          surfaceTint: Colors.transparent,
        );

    final text = _textTheme(
      (dark ? Typography.whiteMountainView : Typography.blackMountainView)
          .merge(Typography.englishLike2021),
      scheme,
    );
    final pill = const StadiumBorder();
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      side: BorderSide(color: fc.hairline),
    );
    OutlineInputBorder input(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.input),
          borderSide: BorderSide(color: color, width: width),
        );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: .1,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
    const backdropTransitions = BackdropPageTransitionsBuilder(
      PredictiveBackPageTransitionsBuilder(),
    );
    const backdropCupertino = BackdropPageTransitionsBuilder(
      CupertinoPageTransitionsBuilder(),
    );
    final popupSurface = dark ? const Color(0xFF183044) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      extensions: [fc],
      // Pages are see-through; each route paints the aurora wallpaper behind
      // itself through the page transition below.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: popupSurface,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: backdropTransitions,
          TargetPlatform.iOS: backdropCupertino,
          TargetPlatform.macOS: backdropCupertino,
          TargetPlatform.windows: backdropTransitions,
          TargetPlatform.linux: backdropTransitions,
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        systemOverlayStyle:
            (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 21),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: fc.frostedFill,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 12.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fc.frostedStrong,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: input(scheme.outlineVariant),
        enabledBorder: input(scheme.outlineVariant),
        disabledBorder: input(scheme.outlineVariant.withValues(alpha: .5)),
        focusedBorder: input(scheme.primary, 1.8),
        errorBorder: input(scheme.error),
        focusedErrorBorder: input(scheme.error, 1.8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: buttonPadding,
          elevation: 0,
          backgroundColor: fc.frostedStrong,
          foregroundColor: scheme.primary,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: buttonPadding,
          backgroundColor: fc.frostedFill,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: pill,
          textStyle: buttonText.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        extendedTextStyle: buttonText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fc.frostedFill,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: pill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: fc.frostedFill,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: buttonText.copyWith(fontSize: 13),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: _PillIndicator(scheme.primaryContainer),
        labelColor: scheme.onPrimaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: buttonText.copyWith(fontSize: 14),
        unselectedLabelStyle: buttonText.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: popupSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: fc.hairline),
        ),
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: popupSurface,
        modalBackgroundColor: popupSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: scheme.outline.withValues(alpha: .55),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: popupSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: fc.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: fc.hairline),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: popupSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: popupSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFFE8F6F4)
            : const Color(0xFF10293A),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: dark ? const Color(0xFF10293A) : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: dark ? AppColors.primary : const Color(0xFF7BEBD0),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.input),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: .14),
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline.withValues(alpha: .45),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE8F6F4) : const Color(0xFF10293A),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: dark ? const Color(0xFF10293A) : Colors.white,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .7),
        space: 1,
        thickness: 1,
      ),
    );
  }

  /// Be Vietnam Pro with a confident hierarchy: heavy, tight headlines and
  /// calm body text.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? style(
      TextStyle? source,
      FontWeight weight, {
      double? size,
      double spacing = 0,
      double? height,
    }) => source?.copyWith(
      fontFamily: fontFamily,
      fontWeight: weight,
      fontSize: size,
      letterSpacing: spacing,
      height: height,
      color: scheme.onSurface,
    );
    return base.copyWith(
      displayLarge: style(base.displayLarge, FontWeight.w800, spacing: -1.5),
      displayMedium: style(base.displayMedium, FontWeight.w800, spacing: -1.2),
      displaySmall: style(base.displaySmall, FontWeight.w800, spacing: -1),
      headlineLarge: style(
        base.headlineLarge,
        FontWeight.w800,
        spacing: -.8,
        height: 1.18,
      ),
      headlineMedium: style(
        base.headlineMedium,
        FontWeight.w800,
        spacing: -.6,
        height: 1.2,
      ),
      headlineSmall: style(
        base.headlineSmall,
        FontWeight.w800,
        spacing: -.4,
        height: 1.25,
      ),
      titleLarge: style(
        base.titleLarge,
        FontWeight.w800,
        size: 20,
        spacing: -.3,
        height: 1.3,
      ),
      titleMedium: style(base.titleMedium, FontWeight.w700, spacing: -.1),
      titleSmall: style(base.titleSmall, FontWeight.w700),
      bodyLarge: style(base.bodyLarge, FontWeight.w400, height: 1.5),
      bodyMedium: style(base.bodyMedium, FontWeight.w400, height: 1.5),
      bodySmall: style(base.bodySmall, FontWeight.w400, height: 1.45),
      labelLarge: style(base.labelLarge, FontWeight.w700),
      labelMedium: style(base.labelMedium, FontWeight.w600),
      labelSmall: style(base.labelSmall, FontWeight.w600, spacing: .2),
    );
  }
}

/// Tab indicator: a pill inset from the tab's edges, like a segmented control.
class _PillIndicator extends Decoration {
  const _PillIndicator(this.color);
  final Color color;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _PillIndicatorPainter(color);
}

class _PillIndicatorPainter extends BoxPainter {
  _PillIndicatorPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = Rect.fromLTWH(
      offset.dx + 6,
      offset.dy + 4,
      size.width - 12,
      size.height - 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..color = color,
    );
  }
}

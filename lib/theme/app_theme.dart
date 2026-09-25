import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_metrics.dart';
import 'app_palettes.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_palettes.dart';
export 'app_metrics.dart';
export 'app_typography.dart';

/// Reads the semantic colour tokens for the active theme.
///
/// `context.colors.textSecondary` replaces the
/// `onSurface.withValues(alpha: 0.6)` pattern that used to produce nearly
/// all secondary text in this app. That pattern was the root cause of the
/// contrast audit's findings: the effective background of an alpha
/// composite is not knowable at build time, so the ratio could not be
/// proven — and where it could be measured, it failed (4.29:1 on white).
/// Every token here is opaque and measured.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// Builds the light and dark [ThemeData] from the design tokens.
///
/// Everything a widget needs should come from here — button shapes and
/// minimum sizes, card surfaces, input decoration, slider metrics, the
/// focus ring. Per-call-site `styleFrom` is a bug, not a style choice.
abstract final class AppTheme {
  static ThemeData light({
    AccentPalette accent = AccentPalette.fallback,
    BackgroundPair background = BackgroundPair.fallback,
  }) =>
      _build(
          Brightness.light,
          AppColors.themed(Brightness.light,
              accent: accent, background: background));

  static ThemeData dark({
    AccentPalette accent = AccentPalette.fallback,
    BackgroundPair background = BackgroundPair.fallback,
  }) =>
      _build(
          Brightness.dark,
          AppColors.themed(Brightness.dark,
              accent: accent, background: background));

  static ThemeData _build(Brightness brightness, AppColors c) {
    final textTheme = AppType.textTheme(c.text, c.textSecondary);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.accentFill,
      onPrimary: c.textOnAccent,
      primaryContainer: c.accentWash,
      onPrimaryContainer: c.accentText,
      secondary: c.cta,
      onSecondary: c.textOnCta,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.bg,
      surfaceContainer: c.surfaceSunken,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.textSecondary,
      error: c.danger,
      onError: brightness == Brightness.light ? c.surface : c.bg,
      errorContainer: c.dangerWash,
      onErrorContainer: c.danger,
      // Meaningful borders only. Decorative hairlines read `colors.border`
      // directly; `outline` is the ≥3:1 one so framework widgets that use
      // it for state never fall below the non-text floor.
      outline: c.borderContrast,
      outlineVariant: c.border,
    );

    ButtonStyle baseButton({
      required Color foreground,
      Color? background,
      BorderSide? side,
    }) {
      return ButtonStyle(
        // 44px minimum on every button, enforced here rather than by each
        // caller's padding.
        minimumSize: const WidgetStatePropertyAll(Size(0, Dim.tapMin)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: R.sm),
        ),
        // No uppercase, no letter-spacing.
        textStyle: const WidgetStatePropertyAll(AppType.label),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? c.textDisabled : foreground),
        backgroundColor: background == null
            ? null
            : WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.disabled)
                    ? c.surfaceSunken
                    : background),
        side: side == null ? null : WidgetStatePropertyAll(side),
        overlayColor: WidgetStatePropertyAll(c.accent.withValues(alpha: 0.10)),
        elevation: const WidgetStatePropertyAll(0),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppType.sans,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: InkSparkle.splashFactory,
      focusColor: c.focusRing.withValues(alpha: 0.16),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: R.md,
          side: BorderSide(color: c.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.titleMd.copyWith(color: c.text),
      ),
      iconTheme: IconThemeData(color: c.text, size: Dim.iconMd),
      listTileTheme: ListTileThemeData(
        iconColor: c.accent,
        textColor: c.text,
        titleTextStyle: AppType.bodyLg.copyWith(color: c.text),
        subtitleTextStyle: AppType.body.copyWith(color: c.textSecondary),
        shape: const RoundedRectangleBorder(borderRadius: R.md),
        minVerticalPadding: Sp.x2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: baseButton(foreground: c.textOnAccent, background: c.accentFill),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: baseButton(foreground: c.textOnAccent, background: c.accentFill),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: baseButton(
          foreground: c.accentText,
          side: BorderSide(color: c.borderContrast),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: baseButton(foreground: c.accentText),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size(Dim.tapMin, Dim.tapMin)),
          iconSize: const WidgetStatePropertyAll(Dim.iconMd),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled) ? c.textDisabled : c.text),
          overlayColor:
              WidgetStatePropertyAll(c.accent.withValues(alpha: 0.10)),
          shape: const WidgetStatePropertyAll(CircleBorder()),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSunken,
        selectedColor: c.accentWash,
        labelStyle: AppType.label.copyWith(color: c.text),
        secondaryLabelStyle: AppType.label.copyWith(color: c.accentText),
        // Selection is never signalled by colour alone: the chip gains a
        // ≥3:1 outline and a weight change as well as the fill.
        side: BorderSide(color: c.border),
        shape: const RoundedRectangleBorder(borderRadius: R.pill),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: AppType.bodyLg.copyWith(color: c.textMuted),
        labelStyle: AppType.body.copyWith(color: c.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        border: OutlineInputBorder(
          borderRadius: R.sm,
          borderSide: BorderSide(color: c.borderContrast),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: R.sm,
          borderSide: BorderSide(color: c.borderContrast),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: R.sm,
          borderSide: BorderSide(color: c.focusRing, width: Dim.focusWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: R.sm,
          borderSide: BorderSide(color: c.danger),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: Dim.scrubTrack,
        activeTrackColor: c.accentFill,
        inactiveTrackColor: c.border,
        thumbColor: c.accentFill,
        overlayColor: c.accent.withValues(alpha: 0.16),
        thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: Dim.scrubThumb / 2),
        overlayShape:
            const RoundSliderOverlayShape(overlayRadius: Dim.tapMin / 2),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: AppType.bodyLg.copyWith(color: c.text),
        actionTextColor: c.accentText,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: R.md),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: R.lg),
        titleTextStyle: AppType.titleSm.copyWith(color: c.text),
        contentTextStyle: AppType.bodyLg.copyWith(color: c.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        textStyle: AppType.bodyLg.copyWith(color: c.text),
        shape: RoundedRectangleBorder(
          borderRadius: R.md,
          side: BorderSide(color: c.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentWash,
        indicatorShape: const RoundedRectangleBorder(borderRadius: R.pill),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppType.label.copyWith(color: c.accentText)
              : AppType.label.copyWith(
                  color: c.textSecondary, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: Dim.iconMd,
            color: s.contains(WidgetState.selected)
                ? c.accentText
                : c.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accentWash,
        indicatorShape: const RoundedRectangleBorder(borderRadius: R.pill),
        selectedLabelTextStyle: AppType.label.copyWith(color: c.accentText),
        unselectedLabelTextStyle: AppType.label
            .copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
        selectedIconTheme: IconThemeData(color: c.accentText, size: Dim.iconMd),
        unselectedIconTheme:
            IconThemeData(color: c.textSecondary, size: Dim.iconMd),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: R.sm,
          border: Border.all(color: c.border),
        ),
        textStyle: AppType.caption.copyWith(color: c.text),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Type scale from `design/tokens.md` §2.
///
/// Two rules the rest of the app must not break:
///
/// 1. **13px is the absolute floor and 17px is the default.** Nothing at 9,
///    10, 11 or 12px. The current build's 9–12px type was the single largest
///    accessibility problem in the app.
/// 2. **Letter-spacing is 0 everywhere**, and there are no `toUpperCase()`
///    labels. Uppercase destroys word shape (which is what fluent readers
///    pattern-match on), some screen readers spell short caps strings letter
///    by letter, and uppercase is what forced every label down to 10–12px in
///    the first place. Hierarchy is carried by size and weight instead.
///
/// Sizes are never applied through a fixed-height `SizedBox`; type must
/// scale with the OS text-size setting to at least 200% without clipping.
abstract final class AppType {
  /// Every style below names the family explicitly. `ThemeData.fontFamily`
  /// only reaches `textTheme`, so component themes that carry an explicit
  /// `TextStyle` (every button, chip, list tile and input hint here) were
  /// silently rendering in the platform default face instead of the
  /// bundled one.
  static const String sans = 'Inter';

  /// Serif accent face for the wordmark and book titles. Not bundled —
  /// resolved from the platform's own serif stack.
  static const List<String> serifFallback = <String>[
    'Iowan Old Style',
    'Palatino',
    'Georgia',
    'serif',
  ];

  /// Timecodes, durations, counts and percentages, so digits do not jitter
  /// as they tick.
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const display = TextStyle(
      fontFamily: sans,
      fontSize: 34,
      height: 40 / 34,
      fontWeight: FontWeight.w700,
      letterSpacing: 0);
  static const titleLg = TextStyle(
      fontFamily: sans,
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 0);
  static const titleMd = TextStyle(
      fontFamily: sans,
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0);
  static const titleSm = TextStyle(
      fontFamily: sans,
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0);

  /// The default body size.
  static const bodyLg = TextStyle(
      fontFamily: sans,
      fontSize: 17,
      height: 26 / 17,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const body = TextStyle(
      fontFamily: sans,
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const label = TextStyle(
      fontFamily: sans,
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0);

  /// The floor. Permitted only for information that also appears elsewhere
  /// or is non-essential.
  static const caption = TextStyle(
      fontFamily: sans,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0);

  /// A [caption]/[body]-sized style with tabular figures, for timecodes.
  static TextStyle tabularCaption(Color color) => caption.copyWith(
      color: color, fontFeatures: tabular, letterSpacing: 0.13);

  static TextStyle tabularBody(Color color) =>
      body.copyWith(color: color, fontFeatures: tabular, letterSpacing: 0.16);

  static TextStyle serif(TextStyle base) => base.copyWith(
        fontFamily: serifFallback.first,
        fontFamilyFallback: serifFallback.sublist(1),
      );

  /// Maps the scale onto Material's [TextTheme] slots so unstyled
  /// framework widgets (`ListTile`, `AlertDialog`, buttons, menus) inherit
  /// the right sizes without a per-call-site `TextStyle`.
  static TextTheme textTheme(Color text, Color secondary) => TextTheme(
        displayLarge: display.copyWith(color: text),
        displayMedium: display.copyWith(color: text),
        displaySmall: titleLg.copyWith(color: text),
        headlineLarge: titleLg.copyWith(color: text),
        headlineMedium: titleMd.copyWith(color: text),
        headlineSmall: titleMd.copyWith(color: text),
        titleLarge: titleMd.copyWith(color: text),
        titleMedium: titleSm.copyWith(color: text),
        titleSmall: label.copyWith(color: text),
        bodyLarge: bodyLg.copyWith(color: text),
        bodyMedium: body.copyWith(color: text),
        bodySmall: caption.copyWith(color: secondary),
        labelLarge: label.copyWith(color: text),
        labelMedium: label.copyWith(color: text),
        // Deliberately 13px, not Material's 11px default: 13 is the floor.
        labelSmall: caption.copyWith(color: secondary),
      );
}

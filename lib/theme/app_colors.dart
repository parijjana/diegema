import 'package:flutter/material.dart';

/// Primitive colour ramps from `design/tokens.css` / `design/tokens.md` §1.1.
///
/// These are the *only* place raw hex literals are allowed to live. Widgets
/// must never reference a ramp step directly — they read a semantic token
/// from [AppColors] (via `Theme.of(context).extension<AppColors>()`, or the
/// `context.colors` shorthand in `app_theme.dart`), because the semantic
/// mapping deliberately differs between light and dark.
///
/// Direction: **teal + warm paper** — a reading room, not a console. The
/// audience assumption that drives every value here is *older readers,
/// including blind and low-vision users*, so every foreground/background
/// pair the semantic layer forms has a measured WCAG ratio recorded in
/// `design/tokens.md` §1.3.
abstract final class Ramp {
  // Teal — primary. Anchor teal500 = #2E6D7D (the app's original value).
  static const teal50 = Color(0xFFEEF5F7);
  static const teal100 = Color(0xFFD7E7EB);
  static const teal200 = Color(0xFFAECFD7);
  static const teal300 = Color(0xFF7FB2BF);
  static const teal400 = Color(0xFF4F8F9F);
  static const teal500 = Color(0xFF2E6D7D);
  static const teal600 = Color(0xFF265A68);
  static const teal700 = Color(0xFF1E4753);
  static const teal800 = Color(0xFF17353E);
  static const teal900 = Color(0xFF102429);

  // Rust — secondary / call to action. Anchor rust500 = #CC4D22.
  static const rust50 = Color(0xFFFCF0EB);
  static const rust100 = Color(0xFFF8DCD1);
  static const rust200 = Color(0xFFF0B9A3);
  static const rust300 = Color(0xFFE5906F);
  static const rust400 = Color(0xFFD96B44);
  static const rust500 = Color(0xFFCC4D22);
  static const rust600 = Color(0xFFA93E1B);
  static const rust700 = Color(0xFF863116);
  static const rust800 = Color(0xFF632410);
  static const rust900 = Color(0xFF41180B);

  // Paper — light neutrals (warm).
  static const paper0 = Color(0xFFFFFFFF);
  static const paper50 = Color(0xFFFBFAF7);
  static const paper100 = Color(0xFFF8F8F5);
  static const paper200 = Color(0xFFEFEEE8);
  static const paper300 = Color(0xFFE0DED6);
  static const paper400 = Color(0xFFC4C1B6);
  static const paper500 = Color(0xFF9A968B);
  static const paper600 = Color(0xFF767268);
  static const paper700 = Color(0xFF55534C);
  static const paper800 = Color(0xFF3A382F);
  static const paper900 = Color(0xFF22201C);

  // Ink — dark surfaces (cool).
  static const ink900 = Color(0xFF101417);
  static const ink850 = Color(0xFF14181C);
  static const ink800 = Color(0xFF181C20);
  static const ink700 = Color(0xFF22272C);
  static const ink600 = Color(0xFF2E353B);
  static const ink500 = Color(0xFF414951);
  static const ink400 = Color(0xFF666F77);
  static const ink300 = Color(0xFF8A939B);

  // Bone — dark-mode text (warm, keeps the paper feel).
  static const bone100 = Color(0xFFF2F0EA);
  static const bone200 = Color(0xFFE6E4DF);
  static const bone300 = Color(0xFFC7C4BC);
  static const bone400 = Color(0xFFB4B0A6);
  static const bone500 = Color(0xFF928D83);

  // Status.
  static const green600 = Color(0xFF1F6B4A);
  static const green300 = Color(0xFF6ECF9F);
  static const amber700 = Color(0xFF8A5A00);
  static const amber300 = Color(0xFFE3B341);
  static const red600 = Color(0xFFB3261E);
  static const red700 = Color(0xFF8C1D18);
  static const red300 = Color(0xFFF2857A);

  // One-off semantic mixes that have no ramp step of their own.
  static const textMutedLight = Color(0xFF6E6B62);
  static const textDisabledLight = Color(0xFF8C8880);
  static const textDisabledDark = Color(0xFF6E7780);
  static const accentWashDark = Color(0xFF16303A);
  static const dangerWashLight = Color(0xFFFDECEA);
  static const dangerWashDark = Color(0xFF3A1614);
}

/// The semantic colour layer (`design/tokens.md` §1.2). Attached to
/// [ThemeData.extensions] so widgets get the right value for the active
/// brightness without ever branching on `Theme.of(context).brightness`.
///
/// ## Why light and dark do not share an accent
///
/// `accent` is `teal-500` in light and **`teal-300` in dark**. This is
/// deliberate and must not be "unified". The shared `#2E6D7D` measures
/// **2.94:1** against the dark surface `#181C20` — it fails AA for text
/// *and* fails the 3:1 non-text floor for icons, borders and focus rings.
/// `teal-300` on `ink-800` measures 7.36:1. The hue is unchanged; only the
/// step differs.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color surfaceRaised;
  final Color surfaceAccent;

  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  final Color accent;
  final Color accentText;
  final Color accentFill;
  final Color textOnAccent;
  final Color accentWash;
  final Color cta;
  final Color textOnCta;

  /// Decorative hairlines only — deliberately below 3:1. Any border that
  /// *carries meaning* (selection, focus, a state boundary, an input
  /// outline) must use [borderContrast] instead.
  final Color border;
  final Color borderContrast;
  final Color focusRing;

  final Color danger;
  final Color dangerWash;
  final Color warning;
  final Color success;

  /// Shadow stack tokens (`design/tokens.md` §5). No coloured glow
  /// shadows exist in this system — they were residue of the rejected
  /// neon pass.
  final List<BoxShadow> shadow1;
  final List<BoxShadow> shadow2;
  final List<BoxShadow> shadow3;
  final List<BoxShadow> shadowCover;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.surfaceAccent,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.accent,
    required this.accentText,
    required this.accentFill,
    required this.textOnAccent,
    required this.accentWash,
    required this.cta,
    required this.textOnCta,
    required this.border,
    required this.borderContrast,
    required this.focusRing,
    required this.danger,
    required this.dangerWash,
    required this.warning,
    required this.success,
    required this.shadow1,
    required this.shadow2,
    required this.shadow3,
    required this.shadowCover,
  });

  static const AppColors light = AppColors(
    bg: Ramp.paper100,
    surface: Ramp.paper0,
    surfaceSunken: Ramp.paper200,
    surfaceRaised: Ramp.paper0,
    surfaceAccent: Ramp.teal50,
    text: Ramp.paper900,
    textSecondary: Ramp.paper700,
    textMuted: Ramp.textMutedLight,
    textDisabled: Ramp.textDisabledLight,
    accent: Ramp.teal500,
    accentText: Ramp.teal600,
    accentFill: Ramp.teal500,
    textOnAccent: Ramp.paper0,
    accentWash: Ramp.teal50,
    cta: Ramp.rust600,
    textOnCta: Ramp.paper0,
    border: Ramp.paper300,
    borderContrast: Ramp.paper600,
    focusRing: Ramp.teal600,
    danger: Ramp.red600,
    dangerWash: Ramp.dangerWashLight,
    warning: Ramp.amber700,
    success: Ramp.green600,
    shadow1: [
      BoxShadow(
          color: Color(0x0F22201C), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
          color: Color(0x0A22201C), blurRadius: 1, offset: Offset(0, 1)),
    ],
    shadow2: [
      BoxShadow(
          color: Color(0x1422201C), blurRadius: 6, offset: Offset(0, 2)),
    ],
    shadow3: [
      BoxShadow(
          color: Color(0x1F22201C), blurRadius: 24, offset: Offset(0, 8)),
    ],
    shadowCover: [
      BoxShadow(
          color: Color(0x2E22201C), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  static const AppColors dark = AppColors(
    bg: Ramp.ink900,
    surface: Ramp.ink800,
    surfaceSunken: Ramp.ink850,
    surfaceRaised: Ramp.ink700,
    surfaceAccent: Ramp.teal900,
    text: Ramp.bone200,
    textSecondary: Ramp.bone400,
    textMuted: Ramp.bone500,
    textDisabled: Ramp.textDisabledDark,
    // teal-300, NOT teal-500 — see the class doc comment.
    accent: Ramp.teal300,
    accentText: Ramp.teal300,
    accentFill: Ramp.teal300,
    textOnAccent: Ramp.ink900,
    accentWash: Ramp.accentWashDark,
    cta: Ramp.rust300,
    textOnCta: Ramp.ink900,
    border: Ramp.ink600,
    borderContrast: Ramp.ink400,
    focusRing: Ramp.teal300,
    danger: Ramp.red300,
    dangerWash: Ramp.dangerWashDark,
    warning: Ramp.amber300,
    success: Ramp.green300,
    shadow1: [
      BoxShadow(
          color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    shadow2: [
      BoxShadow(
          color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadow3: [
      BoxShadow(
          color: Color(0x99000000), blurRadius: 28, offset: Offset(0, 10)),
    ],
    shadowCover: [
      BoxShadow(
          color: Color(0x8C000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSunken,
    Color? surfaceRaised,
    Color? surfaceAccent,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? accent,
    Color? accentText,
    Color? accentFill,
    Color? textOnAccent,
    Color? accentWash,
    Color? cta,
    Color? textOnCta,
    Color? border,
    Color? borderContrast,
    Color? focusRing,
    Color? danger,
    Color? dangerWash,
    Color? warning,
    Color? success,
    List<BoxShadow>? shadow1,
    List<BoxShadow>? shadow2,
    List<BoxShadow>? shadow3,
    List<BoxShadow>? shadowCover,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceAccent: surfaceAccent ?? this.surfaceAccent,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentFill: accentFill ?? this.accentFill,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accentWash: accentWash ?? this.accentWash,
      cta: cta ?? this.cta,
      textOnCta: textOnCta ?? this.textOnCta,
      border: border ?? this.border,
      borderContrast: borderContrast ?? this.borderContrast,
      focusRing: focusRing ?? this.focusRing,
      danger: danger ?? this.danger,
      dangerWash: dangerWash ?? this.dangerWash,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
      shadow3: shadow3 ?? this.shadow3,
      shadowCover: shadowCover ?? this.shadowCover,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        t < 0.5 ? a : b;
    return AppColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceAccent: c(surfaceAccent, other.surfaceAccent),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      textDisabled: c(textDisabled, other.textDisabled),
      accent: c(accent, other.accent),
      accentText: c(accentText, other.accentText),
      accentFill: c(accentFill, other.accentFill),
      textOnAccent: c(textOnAccent, other.textOnAccent),
      accentWash: c(accentWash, other.accentWash),
      cta: c(cta, other.cta),
      textOnCta: c(textOnCta, other.textOnCta),
      border: c(border, other.border),
      borderContrast: c(borderContrast, other.borderContrast),
      focusRing: c(focusRing, other.focusRing),
      danger: c(danger, other.danger),
      dangerWash: c(dangerWash, other.dangerWash),
      warning: c(warning, other.warning),
      success: c(success, other.success),
      shadow1: s(shadow1, other.shadow1),
      shadow2: s(shadow2, other.shadow2),
      shadow3: s(shadow3, other.shadow3),
      shadowCover: s(shadowCover, other.shadowCover),
    );
  }
}

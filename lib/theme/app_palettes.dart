import 'package:flutter/material.dart';

// Hand-tuned palettes for the Settings colour pickers. Every accent x
// background x brightness combination is checked for WCAG AA by
// `test/theme/palette_contrast_test.dart`; change a value here and that
// test tells you whether it still reads.

/// The three accent families offered in Settings.
enum AccentFamily {
  /// Muted, earthy, low-saturation: a reading room.
  matte('Matte'),

  /// Electric, glowing fills. In light mode their text and icon tones are
  /// darker steps of the same hue, because a neon on white cannot be read.
  neon('Neon'),

  /// Saturated primaries: confident, high-contrast.
  bold('Bold');

  final String label;
  const AccentFamily(this.label);
}

/// The accent colours for one brightness.
class AccentTones {
  /// Icons, borders, the scrubber: needs 3:1 against surfaces.
  final Color accent;

  /// Accent-coloured text: needs 4.5:1 against surfaces and the wash.
  final Color accentText;

  /// Filled controls (the play button, selected segments).
  final Color accentFill;

  /// Text and icons drawn on [accentFill]: needs 4.5:1 against it.
  final Color textOnAccent;

  const AccentTones({
    required this.accent,
    required this.accentText,
    required this.accentFill,
    required this.textOnAccent,
  });
}

class AccentPalette {
  final String id;
  final String name;
  final AccentFamily family;
  final AccentTones light;
  final AccentTones dark;

  const AccentPalette({
    required this.id,
    required this.name,
    required this.family,
    required this.light,
    required this.dark,
  });

  AccentTones tones(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const AccentPalette fallback = teal;
  static const AccentPalette teal = AccentPalette(
      id: 'teal',
      name: 'Teal',
      family: AccentFamily.matte,
      light: AccentTones(
          accent: Color(0xFF2E6D7D),
          accentText: Color(0xFF265A68),
          accentFill: Color(0xFF2E6D7D),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFF7FB2BF),
          accentText: Color(0xFF7FB2BF),
          accentFill: Color(0xFF7FB2BF),
          textOnAccent: Color(0xFF101417)));
  static const AccentPalette sage = AccentPalette(
      id: 'sage',
      name: 'Sage',
      family: AccentFamily.matte,
      light: AccentTones(
          accent: Color(0xFF4F6B55),
          accentText: Color(0xFF435C49),
          accentFill: Color(0xFF4F6B55),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFF9DB8A2),
          accentText: Color(0xFF9DB8A2),
          accentFill: Color(0xFF9DB8A2),
          textOnAccent: Color(0xFF101417)));
  static const AccentPalette clay = AccentPalette(
      id: 'clay',
      name: 'Clay',
      family: AccentFamily.matte,
      light: AccentTones(
          accent: Color(0xFF9A5B45),
          accentText: Color(0xFF854D3A),
          accentFill: Color(0xFF9A5B45),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFFD6A08C),
          accentText: Color(0xFFD6A08C),
          accentFill: Color(0xFFD6A08C),
          textOnAccent: Color(0xFF101417)));
  static const AccentPalette slate = AccentPalette(
      id: 'slate',
      name: 'Slate',
      family: AccentFamily.matte,
      light: AccentTones(
          accent: Color(0xFF4E5D78),
          accentText: Color(0xFF434F66),
          accentFill: Color(0xFF4E5D78),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFFA3B1CC),
          accentText: Color(0xFFA3B1CC),
          accentFill: Color(0xFFA3B1CC),
          textOnAccent: Color(0xFF101417)));
  static const AccentPalette mauve = AccentPalette(
      id: 'mauve',
      name: 'Mauve',
      family: AccentFamily.matte,
      light: AccentTones(
          accent: Color(0xFF7A5470),
          accentText: Color(0xFF694760),
          accentFill: Color(0xFF7A5470),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFFC9A3BE),
          accentText: Color(0xFFC9A3BE),
          accentFill: Color(0xFFC9A3BE),
          textOnAccent: Color(0xFF101417)));
  static const AccentPalette cyan = AccentPalette(
      id: 'cyan',
      name: 'Cyan',
      family: AccentFamily.neon,
      light: AccentTones(
          accent: Color(0xFF00788A),
          accentText: Color(0xFF006575),
          accentFill: Color(0xFF00E5FF),
          textOnAccent: Color(0xFF0A1A1F)),
      dark: AccentTones(
          accent: Color(0xFF00E5FF),
          accentText: Color(0xFF00E5FF),
          accentFill: Color(0xFF00E5FF),
          textOnAccent: Color(0xFF04161A)));
  static const AccentPalette magenta = AccentPalette(
      id: 'magenta',
      name: 'Magenta',
      family: AccentFamily.neon,
      light: AccentTones(
          accent: Color(0xFFB0128F),
          accentText: Color(0xFF9A0F7D),
          accentFill: Color(0xFFFF2BD6),
          textOnAccent: Color(0xFF1A0416)),
      dark: AccentTones(
          accent: Color(0xFFFF66E0),
          accentText: Color(0xFFFF66E0),
          accentFill: Color(0xFFFF66E0),
          textOnAccent: Color(0xFF1A0416)));
  static const AccentPalette lime = AccentPalette(
      id: 'lime',
      name: 'Lime',
      family: AccentFamily.neon,
      light: AccentTones(
          accent: Color(0xFF4E7A00),
          accentText: Color(0xFF426800),
          accentFill: Color(0xFFB6FF1A),
          textOnAccent: Color(0xFF142000)),
      dark: AccentTones(
          accent: Color(0xFFB6FF1A),
          accentText: Color(0xFFB6FF1A),
          accentFill: Color(0xFFB6FF1A),
          textOnAccent: Color(0xFF142000)));
  static const AccentPalette volt = AccentPalette(
      id: 'volt',
      name: 'Volt',
      family: AccentFamily.neon,
      light: AccentTones(
          accent: Color(0xFFA34E00),
          accentText: Color(0xFF8F4400),
          accentFill: Color(0xFFFF9E1A),
          textOnAccent: Color(0xFF1F1000)),
      dark: AccentTones(
          accent: Color(0xFFFFA31A),
          accentText: Color(0xFFFFA31A),
          accentFill: Color(0xFFFFA31A),
          textOnAccent: Color(0xFF1F1000)));
  static const AccentPalette ultraviolet = AccentPalette(
      id: 'ultraviolet',
      name: 'Ultraviolet',
      family: AccentFamily.neon,
      light: AccentTones(
          accent: Color(0xFF6B2FD6),
          accentText: Color(0xFF5E27C0),
          accentFill: Color(0xFFB388FF),
          textOnAccent: Color(0xFF12052A)),
      dark: AccentTones(
          accent: Color(0xFFB388FF),
          accentText: Color(0xFFB388FF),
          accentFill: Color(0xFFB388FF),
          textOnAccent: Color(0xFF12052A)));
  static const AccentPalette cobalt = AccentPalette(
      id: 'cobalt',
      name: 'Cobalt',
      family: AccentFamily.bold,
      light: AccentTones(
          accent: Color(0xFF1F4FD1),
          accentText: Color(0xFF1A44B5),
          accentFill: Color(0xFF1F4FD1),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFF7FA2FF),
          accentText: Color(0xFF7FA2FF),
          accentFill: Color(0xFF7FA2FF),
          textOnAccent: Color(0xFF0A1022)));
  static const AccentPalette crimson = AccentPalette(
      id: 'crimson',
      name: 'Crimson',
      family: AccentFamily.bold,
      light: AccentTones(
          accent: Color(0xFFC0182F),
          accentText: Color(0xFFA51428),
          accentFill: Color(0xFFC0182F),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFFFF7A8A),
          accentText: Color(0xFFFF7A8A),
          accentFill: Color(0xFFFF7A8A),
          textOnAccent: Color(0xFF22060A)));
  static const AccentPalette emerald = AccentPalette(
      id: 'emerald',
      name: 'Emerald',
      family: AccentFamily.bold,
      light: AccentTones(
          accent: Color(0xFF0B7A43),
          accentText: Color(0xFF096838),
          accentFill: Color(0xFF0B7A43),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFF4FD68F),
          accentText: Color(0xFF4FD68F),
          accentFill: Color(0xFF4FD68F),
          textOnAccent: Color(0xFF04160D)));
  static const AccentPalette saffron = AccentPalette(
      id: 'saffron',
      name: 'Saffron',
      family: AccentFamily.bold,
      light: AccentTones(
          accent: Color(0xFF9E5F00),
          accentText: Color(0xFF8A5200),
          accentFill: Color(0xFFE08A00),
          textOnAccent: Color(0xFF1F1200)),
      dark: AccentTones(
          accent: Color(0xFFFFB84D),
          accentText: Color(0xFFFFB84D),
          accentFill: Color(0xFFFFB84D),
          textOnAccent: Color(0xFF1F1200)));
  static const AccentPalette royal = AccentPalette(
      id: 'royal',
      name: 'Royal',
      family: AccentFamily.bold,
      light: AccentTones(
          accent: Color(0xFF5B2BB5),
          accentText: Color(0xFF4F25A0),
          accentFill: Color(0xFF5B2BB5),
          textOnAccent: Color(0xFFFFFFFF)),
      dark: AccentTones(
          accent: Color(0xFFB69CFF),
          accentText: Color(0xFFB69CFF),
          accentFill: Color(0xFFB69CFF),
          textOnAccent: Color(0xFF12062A)));

  static const List<AccentPalette> all = [
    teal,
    sage,
    clay,
    slate,
    mauve,
    cyan,
    magenta,
    lime,
    volt,
    ultraviolet,
    cobalt,
    crimson,
    emerald,
    saffron,
    royal
  ];

  static AccentPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => fallback);
}

/// The surfaces and borders for one brightness. Text colours are not part
/// of a background: the default warm text tones read on every option.
class BackgroundTones {
  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color surfaceRaised;
  final Color border;
  final Color borderContrast;

  const BackgroundTones({
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.border,
    required this.borderContrast,
  });
}

/// A matched pair: one background for light mode, one for dark.
class BackgroundPair {
  final String id;
  final String name;
  final BackgroundTones light;
  final BackgroundTones dark;

  const BackgroundPair({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });

  BackgroundTones tones(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const BackgroundPair fallback = paper;
  static const BackgroundPair paper = BackgroundPair(
      id: 'paper',
      name: 'Paper & Ink',
      light: BackgroundTones(
          bg: Color(0xFFF8F8F5),
          surface: Color(0xFFFFFFFF),
          surfaceSunken: Color(0xFFEFEEE8),
          surfaceRaised: Color(0xFFFFFFFF),
          border: Color(0xFFE0DED6),
          borderContrast: Color(0xFF767268)),
      dark: BackgroundTones(
          bg: Color(0xFF101417),
          surface: Color(0xFF181C20),
          surfaceSunken: Color(0xFF14181C),
          surfaceRaised: Color(0xFF22272C),
          border: Color(0xFF2E353B),
          borderContrast: Color(0xFF666F77)));
  static const BackgroundPair snow = BackgroundPair(
      id: 'snow',
      name: 'Snow & Graphite',
      light: BackgroundTones(
          bg: Color(0xFFF5F6F7),
          surface: Color(0xFFFFFFFF),
          surfaceSunken: Color(0xFFECEEF0),
          surfaceRaised: Color(0xFFFFFFFF),
          border: Color(0xFFDDE0E3),
          borderContrast: Color(0xFF6B7178)),
      dark: BackgroundTones(
          bg: Color(0xFF121212),
          surface: Color(0xFF1C1C1E),
          surfaceSunken: Color(0xFF161618),
          surfaceRaised: Color(0xFF262628),
          border: Color(0xFF38383B),
          borderContrast: Color(0xFF6E6E73)));
  static const BackgroundPair sepia = BackgroundPair(
      id: 'sepia',
      name: 'Sepia & Espresso',
      light: BackgroundTones(
          bg: Color(0xFFF4ECDC),
          surface: Color(0xFFFBF6EC),
          surfaceSunken: Color(0xFFF3ECDF),
          surfaceRaised: Color(0xFFFBF6EC),
          border: Color(0xFFD9CBB2),
          borderContrast: Color(0xFF7A6A52)),
      dark: BackgroundTones(
          bg: Color(0xFF16110D),
          surface: Color(0xFF201914),
          surfaceSunken: Color(0xFF1A1410),
          surfaceRaised: Color(0xFF2A221B),
          border: Color(0xFF3D3228),
          borderContrast: Color(0xFF7A6A58)));
  static const BackgroundPair mist = BackgroundPair(
      id: 'mist',
      name: 'Mist & Midnight',
      light: BackgroundTones(
          bg: Color(0xFFEEF2F6),
          surface: Color(0xFFFAFCFE),
          surfaceSunken: Color(0xFFE9EEF3),
          surfaceRaised: Color(0xFFFFFFFF),
          border: Color(0xFFD2DBE5),
          borderContrast: Color(0xFF5F6B7A)),
      dark: BackgroundTones(
          bg: Color(0xFF0B1220),
          surface: Color(0xFF121B2E),
          surfaceSunken: Color(0xFF0E1626),
          surfaceRaised: Color(0xFF1A2538),
          border: Color(0xFF2A3650),
          borderContrast: Color(0xFF5F6F8C)));
  static const BackgroundPair moss = BackgroundPair(
      id: 'moss',
      name: 'Moss & Forest',
      light: BackgroundTones(
          bg: Color(0xFFEFF2EC),
          surface: Color(0xFFFAFBF8),
          surfaceSunken: Color(0xFFEAEEE7),
          surfaceRaised: Color(0xFFFFFFFF),
          border: Color(0xFFD3DACC),
          borderContrast: Color(0xFF646F5C)),
      dark: BackgroundTones(
          bg: Color(0xFF0D1410),
          surface: Color(0xFF141D17),
          surfaceSunken: Color(0xFF101812),
          surfaceRaised: Color(0xFF1C2820),
          border: Color(0xFF2C3A30),
          borderContrast: Color(0xFF62735F)));
  static const BackgroundPair oled = BackgroundPair(
      id: 'oled',
      name: 'Daylight & Black',
      light: BackgroundTones(
          bg: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          surfaceSunken: Color(0xFFF2F2F2),
          surfaceRaised: Color(0xFFFFFFFF),
          border: Color(0xFFDDDDDD),
          borderContrast: Color(0xFF6E6E6E)),
      dark: BackgroundTones(
          bg: Color(0xFF000000),
          surface: Color(0xFF0E0E0E),
          surfaceSunken: Color(0xFF070707),
          surfaceRaised: Color(0xFF1A1A1A),
          border: Color(0xFF2E2E2E),
          borderContrast: Color(0xFF6A6A6A)));

  static const List<BackgroundPair> all = [
    paper,
    snow,
    sepia,
    mist,
    moss,
    oled
  ];

  static BackgroundPair byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => fallback);
}

/// Drop shadows under cards, tiles and buttons (Settings > Colours). A dark
/// shadow in light mode; in dark mode, where a dark shadow would vanish, a
/// faded glow of the accent colour instead.
enum ShadowStyle {
  off('Off'),
  soft('Soft'),
  strong('Strong');

  final String label;
  const ShadowStyle(this.label);

  static ShadowStyle fromName(String? name) => ShadowStyle.values
      .firstWhere((s) => s.name == name, orElse: () => ShadowStyle.off);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/theme/app_theme.dart';

/// Every accent x background x brightness the Settings pickers can produce
/// must meet WCAG AA, the same bar `design/tokens.md` sets for the default
/// palette: 4.5:1 for text, 3:1 for icons, borders and the focus ring.
void main() {
  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  for (final brightness in Brightness.values) {
    for (final background in BackgroundPair.all) {
      for (final accent in AccentPalette.all) {
        final name = '${accent.id} on ${background.id} (${brightness.name})';
        test(name, () {
          final c = AppColors.themed(brightness,
              accent: accent, background: background);
          void atLeast(String what, Color fg, Color bg, double min) {
            expect(ratio(fg, bg), greaterThanOrEqualTo(min),
                reason: '$what in $name');
          }

          for (final (label, surface) in [
            ('bg', c.bg),
            ('surface', c.surface),
            ('sunken', c.surfaceSunken),
            ('raised', c.surfaceRaised),
          ]) {
            atLeast('text on $label', c.text, surface, 4.5);
            atLeast('textSecondary on $label', c.textSecondary, surface, 4.5);
            atLeast('textMuted on $label', c.textMuted, surface, 4.5);
          }
          for (final (label, surface) in [
            ('bg', c.bg),
            ('surface', c.surface),
            ('sunken', c.surfaceSunken),
            ('accentWash', c.accentWash),
          ]) {
            atLeast('accentText on $label', c.accentText, surface, 4.5);
          }
          atLeast('accent on bg', c.accent, c.bg, 3);
          atLeast('accent on surface', c.accent, c.surface, 3);
          atLeast('focusRing on surface', c.focusRing, c.surface, 3);
          atLeast('borderContrast on surface', c.borderContrast, c.surface, 3);
          atLeast(
              'textOnAccent on accentFill', c.textOnAccent, c.accentFill, 4.5);
        });
      }
    }
  }

  test('the default choice is the hand-measured token set, untouched', () {
    expect(
        identical(AppColors.themed(Brightness.light), AppColors.light), isTrue);
    expect(
        identical(AppColors.themed(Brightness.dark), AppColors.dark), isTrue);
  });

  test('unknown stored ids fall back to the defaults', () {
    expect(AccentPalette.byId('nope'), AccentPalette.fallback);
    expect(BackgroundPair.byId(null), BackgroundPair.fallback);
  });
}

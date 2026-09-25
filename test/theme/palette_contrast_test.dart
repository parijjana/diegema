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

  group('drop shadows', () {
    test('off by default: no UI shadow, default tokens untouched', () {
      expect(AppColors.themed(Brightness.light).shadowUi, isEmpty);
      expect(AppColors.themed(Brightness.dark).shadowUi, isEmpty);
    });

    test('light mode casts a dark shadow', () {
      for (final style in [ShadowStyle.soft, ShadowStyle.strong]) {
        final c = AppColors.themed(Brightness.light,
            accent: AccentPalette.lime, shadows: style);
        expect(c.shadowUi, isNotEmpty);
        for (final s in c.shadowUi) {
          expect(
              s.color.withValues(alpha: 1).computeLuminance(), lessThan(0.05),
              reason: 'a dark colour, not the accent');
        }
        expect(c.shadow2, c.shadowUi, reason: 'elevation tokens follow');
      }
    });

    test('dark mode glows in a faded accent', () {
      for (final accent in AccentPalette.all) {
        final c = AppColors.themed(Brightness.dark,
            accent: accent, shadows: ShadowStyle.soft);
        final glow = c.shadowUi.first.color;
        expect(glow.withValues(alpha: 1), accent.dark.accent,
            reason: accent.id);
        expect(glow.a, lessThan(1), reason: 'faded');
      }
    });

    test('strong is heavier than soft', () {
      final soft = AppColors.themed(Brightness.dark, shadows: ShadowStyle.soft);
      final strong =
          AppColors.themed(Brightness.dark, shadows: ShadowStyle.strong);
      expect(strong.shadowUi.first.color.a,
          greaterThan(soft.shadowUi.first.color.a));
      expect(strong.shadowUi.first.blurRadius,
          greaterThan(soft.shadowUi.first.blurRadius));
    });
  });
}

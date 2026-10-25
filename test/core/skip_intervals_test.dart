import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('skip interval storage', () {
    test('defaults to 15 both ways', () async {
      const prefs = UiPreferences(overrides: <String, Object>{});
      expect(await prefs.getSkipBackSeconds(), 15);
      expect(await prefs.getSkipForwardSeconds(), 15);
    });

    test('the legacy skipSeconds seeds both new values', () async {
      const prefs = UiPreferences(overrides: <String, Object>{
        'playback.skip_seconds': 30,
      });
      expect(await prefs.getSkipBackSeconds(), 30);
      expect(await prefs.getSkipForwardSeconds(), 30);
    });

    test('a new value wins over the legacy one, per direction', () async {
      const prefs = UiPreferences(overrides: <String, Object>{
        'playback.skip_seconds': 30,
        'playback.skip_forward_seconds': 10,
      });
      expect(await prefs.getSkipBackSeconds(), 30);
      expect(await prefs.getSkipForwardSeconds(), 10);
    });

    test('unknown values fall back to the legacy value, then the default',
        () async {
      const prefs = UiPreferences(overrides: <String, Object>{
        'playback.skip_back_seconds': 7,
        'playback.skip_forward_seconds': 'x',
        'playback.skip_seconds': 60,
      });
      expect(await prefs.getSkipBackSeconds(), 60);
      expect(await prefs.getSkipForwardSeconds(), 60);

      const bad = UiPreferences(overrides: <String, Object>{
        'playback.skip_back_seconds': 7,
        'playback.skip_seconds': 8,
      });
      expect(await bad.getSkipBackSeconds(), 15);
    });

    test('AppSettings round-trips both values by name', () async {
      final store = <String, Object>{};
      final settings =
          AppSettings(preferences: UiPreferences(overrides: store));
      await settings.setSkipBackSeconds(30);
      await settings.setSkipForwardSeconds(10);
      expect(store['playback.skip_back_seconds'], 30);
      expect(store['playback.skip_forward_seconds'], 10);

      final reloaded =
          AppSettings(preferences: UiPreferences(overrides: store));
      await reloaded.load();
      expect(reloaded.skipBackSeconds, 30);
      expect(reloaded.skipForwardSeconds, 10);
    });

    test('AppSettings.load migrates a legacy value into both', () async {
      final settings = AppSettings(
          preferences: const UiPreferences(
              overrides: <String, Object>{'playback.skip_seconds': 10}));
      await settings.load();
      expect(settings.skipBackSeconds, 10);
      expect(settings.skipForwardSeconds, 10);
    });

    test('AppSettings ignores intervals outside the options', () async {
      final settings = AppSettings(
          preferences: const UiPreferences(overrides: <String, Object>{}));
      await settings.setSkipBackSeconds(7);
      expect(settings.skipBackSeconds, 15);
    });
  });
}

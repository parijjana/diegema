import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/librivox_service.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// The theme choice used to live in `_AudiobookAppState` as a plain `bool`
/// seeded from the demo deep link, so **every cold start fell back to
/// light** however many times you had picked dark, and "follow the system"
/// could not be expressed at all. These tests pin the fix: the choice is
/// written through [UiPreferences] and read back on the next launch.
///
/// A restart is simulated by pumping a second [AudiobookApp] over the same
/// overrides map — that map is exactly what survives a process in
/// production, so carrying it across is the honest equivalent.
void main() {
  MockClient buildMockClient() => MockClient((request) async {
        if (request.url.host == 'librivox.org') {
          return http.Response('{"books": []}', 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.host == 'archive.org') {
          return http.Response('{"response": {"docs": []}}', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

  // Built in `setUp`, not in the test body — see the long note in
  // `responsive_layout_test.dart`; constructing it inside `FakeAsync`
  // deadlocks the binding.
  late FakePlaybackService audio;

  setUp(() {
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
  });

  /// Pumps the app over [store], leaving `initialThemeMode` unset so the
  /// stored preference is what decides — which is the whole point here.
  Future<AppDatabase> pumpApp(
    WidgetTester tester,
    Map<String, Object> store,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(AudiobookApp(
      database: db,
      audioService: audio,
      libriVoxService: LibriVoxService(
        client: buildMockClient(),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
      ),
      preferences: UiPreferences(overrides: store),
    ));
    await pumpFrames(tester);
    return db;
  }

  ThemeMode themeModeOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  /// Opens the panel by tapping the nav destination, scoped to the
  /// navigation bar so it cannot hit the screen's own 'Settings' heading.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Settings'),
    ));
    await pumpFrames(tester);
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.text(option));
    await pumpFrames(tester);
  }

  testWidgets('a fresh install follows the system', (tester) async {
    await pumpApp(tester, <String, Object>{});

    expect(themeModeOf(tester), ThemeMode.system,
        reason: 'an install that has expressed no preference should follow '
            'the OS, not pin itself to light');

    await unmount(tester);
  });

  testWidgets('a choice made in the panel survives a restart', (tester) async {
    final store = <String, Object>{};

    await pumpApp(tester, store);
    expect(themeModeOf(tester), ThemeMode.system);

    await openSettings(tester);
    await choose(tester, 'Dark');
    expect(themeModeOf(tester), ThemeMode.dark);

    await unmount(tester);

    // Relaunch over the same store.
    await pumpApp(tester, store);

    expect(themeModeOf(tester), ThemeMode.dark,
        reason: 'this is the regression: the choice was previously held only '
            'in State, so the relaunch came up light');

    await unmount(tester);
  });

  testWidgets('choosing light persists light, not system', (tester) async {
    final store = <String, Object>{'appearance.theme_mode': 'dark'};

    await pumpApp(tester, store);
    expect(themeModeOf(tester), ThemeMode.dark);

    await openSettings(tester);
    await choose(tester, 'Light');

    expect(themeModeOf(tester), ThemeMode.light);
    expect(store['appearance.theme_mode'], 'light',
        reason: 'an explicit light choice must be distinguishable from '
            'never having chosen — otherwise it cannot survive a restart '
            'on a dark-themed OS');

    await unmount(tester);
  });

  testWidgets('System is reachable again once chosen away from',
      (tester) async {
    // The whole reason the panel exists rather than another two-state
    // toggle: a one-button control could leave System but never return.
    final store = <String, Object>{'appearance.theme_mode': 'light'};

    await pumpApp(tester, store);
    await openSettings(tester);
    await choose(tester, 'System');

    expect(themeModeOf(tester), ThemeMode.system);
    expect(store['appearance.theme_mode'], 'system');

    await unmount(tester);
  });

  testWidgets('an unreadable stored value falls back to the default',
      (tester) async {
    // What an older build would see after a newer one wrote a mode it does
    // not know about. A preference must never be able to break a screen.
    await pumpApp(tester, <String, Object>{'appearance.theme_mode': 'sepia'});

    expect(themeModeOf(tester), ThemeMode.system);

    await unmount(tester);
  });
}

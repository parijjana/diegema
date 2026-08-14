import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/widgets/player_transport.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// Overflow guard.
///
/// Raising the type floor from 10px to 13px and retiring the letter-spaced
/// all-caps labels makes every horizontal row tighter than it used to be,
/// and a `RenderFlex overflowed` error can be invisible in a screenshot
/// (the content is simply clipped) while still throwing. A sibling project
/// had a store submission blocked by exactly this class of bug, so each
/// supported width is asserted here rather than eyeballed.
///
/// 360×800 is the narrowest width worth supporting (Galaxy S series);
/// 430×932 is the wide-phone end (iPhone Plus/Max); 1440×900 is desktop.
void main() {
  const sizes = <String, Size>{
    'android narrow 360x800': Size(360, 800),
    'iphone 390x844': Size(390, 844),
    'iphone max 430x932': Size(430, 932),
    'desktop 1440x900': Size(1440, 900),
  };

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

  // A fake, not the real service: the real `AudioPlayer` reaches for its
  // platform channel, which has no implementation under `flutter_test`.
  //
  // Built in `setUp`, NOT inside the `testWidgets` body, and this placement
  // is load-bearing. A `testWidgets` body runs inside `FakeAsync`, so a
  // `FakePlaybackService()` constructed there runs the real
  // `AudioPlaybackService` constructor under `super()` — creating the
  // `AudioPlayer`'s stream subscription and `_startProgressAutoSave()`'s
  // periodic timer as *fake-zone* objects. `pumpFrames` then waits on them
  // inside `runAsync`, in real time, while only fake time could ever
  // advance them: the binding deadlocks at `+0` and not even `--timeout`
  // interrupts it, because the wait is below the framework. `setUp` runs in
  // the real async zone, which is why `now_playing_screen_test.dart` — same
  // fake, same app — has always passed.
  late FakePlaybackService audio;

  setUp(() {
    audio = FakePlaybackService();
  });

  // Disposed in `tearDown` rather than `addTearDown`: `addTearDown`
  // callbacks run after the binding's pending-timer invariant check, too
  // late to cancel the service's periodic progress-save timer — the same
  // ordering issue worked around the same way in
  // `now_playing_fade_golden_test.dart`.
  tearDown(() async {
    await audio.dispose().catchError((_) {});
  });

  for (final entry in sizes.entries) {
    for (final dark in [false, true]) {
      final themeName = dark ? 'dark' : 'light';
      testWidgets('${entry.key} / $themeName lays out with no overflow',
          (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        {
          // Long titles and author names are the realistic worst case for
          // a horizontal row, so the seeded data uses them deliberately.
          //
          // `positionSeconds` is seeded so this book lands in the
          // continue-listening rows: a long title inside a horizontal row
          // is the specific overflow stress case this file exists for. An
          // earlier revision dropped it while chasing a hang that was
          // wrongly attributed to the Task 3 restore path; the hang was
          // actually the fake being constructed inside `FakeAsync` (see
          // the note on `audio` above), so the coverage is restored.
          await seedBook(db,
              id: 'a',
              title: 'The Extraordinarily Long Title of a Victorian Novel, '
                  'Volume the Second',
              positionSeconds: 120);
          await seedBook(db, id: 'b', title: 'Middlemarch');
          await seedBook(db, id: 'c', title: 'Persuasion');
          await db.pinBook('c');
          await seedBook(db, id: 'd', title: 'A Pinned Book Not In Progress');
          await db.pinBook('d');

          await setSurface(tester, entry.value);

          await tester.pumpWidget(AudiobookApp(
            initialThemeMode: dark ? ThemeMode.dark : ThemeMode.light,
            database: db,
            audioService: audio,
            libriVoxService: LibriVoxService(
              client: buildMockClient(),
              // Zero cooldown: the real 1s-per-call delays are wall-clock
              // waits inside `runAsync`, which widget tests cannot advance
              // — Discover fans out across every category shelf and the
              // pending timers hang the binding outright. See the doc on
              // `RateLimitDispatcher.cooldownOverride`.
              rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
            ),
            preferences: const UiPreferences(overrides: <String, Object>{}),
          ));
          await pumpFrames(tester);

          // Book 'a' has the most recent progress, so Task 3 restores it
          // into the player on the first frame and the player view is what
          // this first assertion checks (cover, title, chapter line,
          // transport). The seeded long title is exercised by the
          // continue-listening rows reached via the tab-walk below.
          expect(tester.takeException(), isNull,
              reason: 'Now Playing overflowed at ${entry.key}');

          // Walk all four screens at this width. The bottom `NavigationBar`
          // is the navigation at every width as of 08-14, so there is no
          // longer a wide-layout variant to find. Settings joined this walk
          // with the panel itself — a fourth destination makes the bar a
          // quarter tighter per item, and 'Now playing' is its longest
          // label, so 360px is the case that matters.
          final navFinder = find.byType(NavigationBar);

          for (final label in [
            'Library',
            'Discover',
            'Settings',
            'Now playing',
          ]) {
            await tester.tap(find.descendant(
              of: navFinder,
              matching: find.text(label),
            ));
            await pumpFrames(tester);
            if (label == 'Discover') await drainRateLimiter(tester);
            expect(tester.takeException(), isNull,
                reason: '$label overflowed at ${entry.key}');
          }

          await unmount(tester);
        }
      });
    }
  }

  // The loop above only ever runs at the default text scale, which is how a
  // 64px overflow inside the sleep-timer chip survived it: the chip's label
  // is the one piece of the player that grows without bound. This app's
  // stated audience explicitly includes low-vision readers, so a doubled
  // text scale on the narrowest supported phone is a supported case.
  //
  // The player is asserted directly rather than through the tab-walk
  // because the chips only exist once a book is loaded, and the launch
  // auto-restore that used to provide one was removed.
  for (final scale in [1.3, 2.0]) {
    testWidgets('player controls survive text scale $scale at 360x800',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await setSurface(tester, const Size(360, 800));
      await tester.pumpWidget(AudiobookApp(
        initialThemeMode: ThemeMode.light,
        database: db,
        audioService: audio,
        libriVoxService: LibriVoxService(
          client: buildMockClient(),
          rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
        ),
        preferences: const UiPreferences(overrides: <String, Object>{}),
      ));
      await pumpFrames(tester);

      final book = await seedBook(db, id: 'z', title: 'Persuasion');
      await audio.loadBook(book);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull,
          reason: 'player overflowed at 360x800, text scale $scale');

      // The sleep-timer chip is the specific control that overflowed, so
      // assert it is actually on screen and not merely non-throwing.
      expect(find.byType(SleepTimerSelector), findsOneWidget);

      await unmount(tester);
    });
  }

  // The theme toggle is deliberately in exactly one place per layout: the
  // top tab bar when wide, the Now Playing title bar when narrow. Loading a
  // book swaps that title bar out for the player — and the player had no
  // toggle, so on a phone the control disappeared entirely for as long as
  // anything was playing. Desktop hid the bug because its tab bar keeps a
  // copy regardless.
  //
  // The ad-hoc toggle is now gone entirely: Settings owns the theme, and
  // the control exists in exactly one place at every width and in every
  // playback state. This test kept its shape when the toggle was replaced
  // — the failure it guards against is unchanged, only its subject moved.
  // Two toggles on desktop was as much a regression as none on mobile, and
  // a theme control drifting back into a screen heading would be the same
  // bug a third time.
  for (final entry in {
    'mobile 390x844': const Size(390, 844),
    'desktop 1440x900': const Size(1440, 900),
  }.entries) {
    testWidgets('the theme control lives only in Settings on ${entry.key}',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await setSurface(tester, entry.value);
      await tester.pumpWidget(AudiobookApp(
        initialThemeMode: ThemeMode.light,
        database: db,
        audioService: audio,
        libriVoxService: LibriVoxService(
          client: buildMockClient(),
          rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
        ),
        preferences: const UiPreferences(overrides: <String, Object>{}),
      ));
      await pumpFrames(tester);

      expect(find.text('Theme'), findsNothing,
          reason: 'no book loaded, ${entry.key}');

      final book = await seedBook(db, id: 'z', title: 'Persuasion');
      await audio.loadBook(book);
      await pumpFrames(tester);

      expect(find.text('Theme'), findsNothing,
          reason: 'book loaded and player showing, ${entry.key}');

      await goToSettings(tester);
      expect(find.text('Theme'), findsOneWidget,
          reason: 'settings open, ${entry.key}');

      await unmount(tester);
    });
  }
}

/// Taps the Settings destination. Scoped to the navigation bar so it cannot
/// accidentally hit the screen's own 'Settings' heading once the panel is
/// open.
Future<void> goToSettings(WidgetTester tester) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Settings'),
  ));
  await pumpFrames(tester);
}

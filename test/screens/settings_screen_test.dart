import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/ambience_service.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/theme/app_theme.dart';

import '../services/ambience_service_test.dart' show FakeChannel;
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// The settings panel — Phase 1 of `settings_panel_plan.md`.
///
/// Theme persistence has its own file (`theme_persistence_test.dart`); this
/// one covers the skip interval and what the About section is obliged to
/// say.
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

  // See the note in `responsive_layout_test.dart`: constructing this inside
  // the test body puts it in `FakeAsync` and deadlocks the binding.
  late FakePlaybackService audio;

  setUp(() {
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
  });

  Future<AppDatabase> pumpApp(
    WidgetTester tester,
    Map<String, Object> store, {
    AmbienceService? ambience,
  }) async {
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
      ambience: ambience,
    ));
    await pumpFrames(tester);
    return db;
  }

  Future<void> goTo(WidgetTester tester, String destination) async {
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(destination),
    ));
    await pumpFrames(tester);
  }

  // The panel is a lazy `ListView` taller than a phone, so a row further
  // down has to be scrolled into view before it exists to be found.
  Future<void> reveal(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 120,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);

  testWidgets('the skip interval reaches the transport controls',
      (tester) async {
    final store = <String, Object>{};
    final db = await pumpApp(tester, store);

    final book = await seedBook(db, id: 'z', title: 'Persuasion');
    await audio.loadBook(book);
    await pumpFrames(tester);

    // The default, and the number the buttons are stamped with.
    expect(find.bySemanticsLabel('Skip forward 15 seconds'), findsOneWidget);

    await goTo(tester, 'Settings');
    await reveal(tester, find.text('30 seconds'));
    await tester.ensureVisible(find.text('30 seconds'));
    await pumpFrames(tester);
    await tester.tap(find.text('30 seconds'));
    await pumpFrames(tester);

    await goTo(tester, 'Now playing');

    expect(find.bySemanticsLabel('Skip forward 30 seconds'), findsOneWidget,
        reason: 'the seek and the number on the glyph come from one value, '
            'so the label moving proves both did');
    expect(find.bySemanticsLabel('Skip back 30 seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Skip forward 15 seconds'), findsNothing);

    expect(store['playback.skip_seconds'], 30);

    await unmount(tester);
  });

  testWidgets('the Player buttons toggle reshapes the action row and persists',
      (tester) async {
    final store = <String, Object>{};
    final db = await pumpApp(tester, store);

    final book = await seedBook(db, id: 'z', title: 'Persuasion');
    await audio.loadBook(book);
    await pumpFrames(tester);

    // Tiles by default: every action carries a caption over its value.
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);

    await goTo(tester, 'Settings');
    expect(find.bySemanticsLabel('Tiles'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Round').first);
    await pumpFrames(tester);
    await tester.tap(find.text('Round').first);
    await pumpFrames(tester);
    expect(store['now_playing.controls_style'], 'round');

    await goTo(tester, 'Now playing');
    // Round and bar show one short word each, so no "Speed" caption.
    expect(find.text('Speed'), findsNothing);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);

    await goTo(tester, 'Settings');
    await tester.ensureVisible(find.text('Bar').first);
    await pumpFrames(tester);
    await tester.tap(find.text('Bar').first);
    await pumpFrames(tester);
    expect(store['now_playing.controls_style'], 'bar');

    await goTo(tester, 'Now playing');
    expect(find.text('Speed'), findsNothing);
    expect(find.bySemanticsLabel('Playback speed, currently 1.0x'),
        findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
      'the Playback controls toggle reshapes the transport and persists',
      (tester) async {
    final store = <String, Object>{};
    final db = await pumpApp(tester, store);

    final book = await seedBook(db, id: 'z', title: 'Persuasion');
    await audio.loadBook(book);
    await pumpFrames(tester);

    for (final style in ['Tiles', 'Bar', 'Round']) {
      await goTo(tester, 'Settings');
      final option = find.text(style).last;
      await reveal(tester, option);
      await tester.ensureVisible(option);
      await pumpFrames(tester);
      await tester.tap(option);
      await pumpFrames(tester);
      expect(store['now_playing.transport_style'], style.toLowerCase());
      // The first toggle (Player buttons) is untouched.
      expect(store['now_playing.controls_style'], isNull);

      await goTo(tester, 'Now playing');
      // Every shape keeps every control and its accessible name.
      for (final label in [
        'Previous chapter',
        'Skip back 15 seconds',
        'Skip forward 15 seconds',
        'Next chapter',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget,
            reason: '$label in $style');
      }
      expect(find.bySemanticsLabel(RegExp(r'^(Play|Pause|Loading)$')),
          findsOneWidget,
          reason: 'play/pause in $style');
      expect(tester.takeException(), isNull);
    }

    await unmount(tester);
  });

  testWidgets('choosing a background and an accent recolours the app',
      (tester) async {
    final store = <String, Object>{};
    await pumpApp(tester, store);
    await goTo(tester, 'Settings');

    Color bg() => Theme.of(tester.element(find.text('Settings').last))
        .extension<AppColors>()!
        .bg;
    Color fill() => Theme.of(tester.element(find.text('Settings').last))
        .extension<AppColors>()!
        .accentFill;
    expect(bg(), AppColors.light.bg);

    final sepia = find.bySemanticsLabel('Sepia & Espresso background');
    await reveal(tester, sepia);
    await tester.ensureVisible(sepia);
    await pumpFrames(tester);
    await tester.tap(sepia);
    await pumpFrames(tester);
    expect(store['appearance.background'], 'sepia');
    expect(bg(), BackgroundPair.sepia.light.bg);

    final cyan = find.bySemanticsLabel('Cyan, neon accent');
    await reveal(tester, cyan);
    await tester.ensureVisible(cyan);
    await pumpFrames(tester);
    await tester.tap(cyan);
    await pumpFrames(tester);
    expect(store['appearance.accent'], 'cyan');
    expect(fill(), AccentPalette.cyan.light.accentFill);

    await unmount(tester);
  });

  testWidgets('the Shadows toggle turns drop shadows on and persists',
      (tester) async {
    final store = <String, Object>{};
    await pumpApp(tester, store);
    await goTo(tester, 'Settings');

    List<BoxShadow> shadows() =>
        Theme.of(tester.element(find.text('Settings').last))
            .extension<AppColors>()!
            .shadowUi;
    expect(shadows(), isEmpty);

    final strong = find.text('Strong');
    await reveal(tester, strong);
    await tester.ensureVisible(strong);
    await pumpFrames(tester);
    await tester.tap(strong);
    await pumpFrames(tester);
    expect(store['appearance.shadows'], 'strong');
    expect(shadows(), isNotEmpty);

    await unmount(tester);
  });

  testWidgets('a stored colour choice is applied on launch', (tester) async {
    await pumpApp(tester, {
      'appearance.background': 'mist',
      'appearance.accent': 'crimson',
    });
    await goTo(tester, 'Settings');
    final colors = Theme.of(tester.element(find.text('Settings').last))
        .extension<AppColors>()!;
    expect(colors.bg, BackgroundPair.mist.light.bg);
    expect(colors.accentFill, AccentPalette.crimson.light.accentFill);
    await unmount(tester);
  });

  testWidgets(
      'Ambience is its own screen; Now Playing has only a small on/off pill',
      (tester) async {
    final store = <String, Object>{};
    final ambience = AmbienceService(
      book: audio,
      preferences: UiPreferences(overrides: store),
      channelFactory: FakeChannel.new,
      fade: Duration.zero,
      useAudioSession: false,
    );
    final db = await pumpApp(tester, store, ambience: ambience);

    final book = await seedBook(db, id: 'z', title: 'Persuasion');
    await audio.loadBook(book);
    await pumpFrames(tester);

    // No ambience action in the Up next / Speed / Sleep row any more.
    expect(find.bySemanticsLabel(RegExp(r'^Ambience, ')), findsNothing);
    final pill = find.bySemanticsLabel('Ambience');
    expect(pill, findsOneWidget);

    // With nothing chosen yet, the pill opens the Ambience screen.
    await tester.tap(pill);
    await pumpFrames(tester);
    expect(find.text('Play with the book'), findsOneWidget);

    final rain = find.bySemanticsLabel('Rain');
    await tester.scrollUntilVisible(rain, 150,
        scrollable: find.byType(Scrollable).last);
    await pumpFrames(tester);
    await tester.tap(rain);
    await pumpFrames(tester);
    expect(ambience.state.value.mix.keys, ['rain']);
    expect(ambience.state.value.on, isTrue);
    // The sound just added gets its own level slider (the master volume
    // slider may have scrolled out of the lazy list by now).
    expect(find.byType(Slider), findsWidgets);

    // Back on the player, the pill now just switches the mix off and on.
    await goTo(tester, 'Now playing');
    await tester.tap(find.bySemanticsLabel('Ambience'));
    await pumpFrames(tester);
    expect(ambience.state.value.on, isFalse);
    expect(find.text('Play with the book'), findsNothing,
        reason: 'a quick toggle, not a trip to the screen');
    await tester.tap(find.bySemanticsLabel('Ambience'));
    await pumpFrames(tester);
    expect(ambience.state.value.on, isTrue);

    // Inside the body, not addTearDown: its futures belong to this test's
    // fake-async zone and would never complete from outside it.
    await unmount(tester);
    await ambience.dispose();
  });

  testWidgets('a stored skip interval is applied on launch', (tester) async {
    final db =
        await pumpApp(tester, <String, Object>{'playback.skip_seconds': 60});

    final book = await seedBook(db, id: 'z', title: 'Persuasion');
    await audio.loadBook(book);
    await pumpFrames(tester);

    expect(find.bySemanticsLabel('Skip forward 60 seconds'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('an interval the panel can no longer offer is discarded',
      (tester) async {
    // Otherwise a value written by a build with different options would be
    // stuck on the device with no UI able to change it.
    final db =
        await pumpApp(tester, <String, Object>{'playback.skip_seconds': 7});

    final book = await seedBook(db, id: 'z', title: 'Persuasion');
    await audio.loadBook(book);
    await pumpFrames(tester);

    expect(find.bySemanticsLabel('Skip forward 15 seconds'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('About credits the cover art and offers the licences',
      (tester) async {
    await pumpApp(tester, <String, Object>{});
    await goTo(tester, 'Settings');

    await reveal(tester, find.text('About'));
    expect(find.text('About'), findsOneWidget);
    await reveal(tester, find.textContaining('Version'));
    expect(find.textContaining('Version'), findsOneWidget);
    await reveal(tester, find.textContaining('covers/CREDITS.md'));
    expect(find.textContaining('covers/CREDITS.md'), findsOneWidget,
        reason: 'the bundled covers are public domain but the record of '
            'which item each came from is what was actually missing');
    await reveal(tester, find.text('Open source licences'));
    await reveal(tester, find.textContaining('BigSoundBank'));
    expect(find.textContaining('BigSoundBank'), findsOneWidget,
        reason: 'the ambience recordings are credited to their author');
    expect(find.text('Open source licences'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('About credits LibriVox and disclaims any affiliation',
      (tester) async {
    await pumpApp(tester, <String, Object>{});
    await goTo(tester, 'Settings');

    await reveal(
        tester, find.textContaining('come from LibriVox (librivox.org)'));
    expect(find.textContaining('come from LibriVox (librivox.org)'),
        findsOneWidget);
    await reveal(tester, find.text('Visit librivox.org'));
    expect(find.text('Visit librivox.org'), findsOneWidget,
        reason: 'LibriVox asks for credit with a link to its site');
    await reveal(tester, find.textContaining('strongly support LibriVox'));
    expect(find.textContaining('strongly support LibriVox'), findsOneWidget);
    await reveal(tester,
        find.textContaining('not affiliated with or endorsed by LibriVox'));
    expect(find.textContaining('not affiliated with or endorsed by LibriVox'),
        findsOneWidget);
    await reveal(tester, find.text('Volunteer for LibriVox'));
    expect(find.text('Volunteer for LibriVox'), findsOneWidget);

    await unmount(tester);
  });
}

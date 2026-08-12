import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/core/ui_preferences.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/domain/models/audiobook.dart';
import 'package:unamedaudiobookplayer/screens/now_playing_screen.dart';
import 'package:unamedaudiobookplayer/services/audio_playback_service.dart';
import 'package:unamedaudiobookplayer/theme/app_theme.dart';

import '../support/fake_playback_service.dart';
import '../support/golden_fonts.dart';
import '../support/test_harness.dart';

/// The idle -> playing fade is the centrepiece of the redesign and the one
/// thing nobody could actually *see*: two earlier attempts to verify it
/// through headless Chrome failed for a structural reason — Flutter web
/// renders into a single `<canvas>`, so there are no DOM nodes to drive and
/// both attempts ended up screenshotting an unrelated modal.
///
/// So the transition is verified here instead, where the animation clock is
/// ours: every frame is pumped by hand (never `pumpAndSettle`, which would
/// skip straight to the end and prove nothing) and written out as a golden
/// PNG. The frames are committed, so a regression in the curve, the
/// stagger, the offsets or the layout shows up as a pixel diff.
///
/// Frame budget: the controller runs 320ms, sampled every 80ms, plus the
/// settled state at each end.
void main() {
  /// Sampled at the handover (96ms = 30% of 320ms, where the outgoing
  /// layer ends and the incoming one starts) and either side of it, since
  /// that is the moment a fade-through can look broken or empty.
  const sampleMs = <int>[0, 48, 96, 144, 240, 320, 400];
  const surface = Size(390, 844);

  late AppDatabase db;
  late FakePlaybackService audio;
  late UnifiedAudiobook book;

  // Without real fonts every glyph is a filled rectangle, which would make
  // these goldens useless for judging the transition by eye.
  setUpAll(loadGoldenFonts);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();

    // Deliberately no `positionSeconds` on any of these: since the "always
    // show the player when something was last played" behaviour (see the
    // restore test below and `_maybeRestoreLastPlayed` in
    // `now_playing_screen.dart`) loads a paused player the instant a
    // `PlaybackProgress` row exists, a seeded progress row would make the
    // screen start already in the player rather than the idle list — which
    // is exactly what these frame-by-frame tests need to NOT happen, so the
    // tap-driven fade they exercise stays isolated from the restore
    // feature. The pinned row still renders from `dracula` alone.
    book = await seedBook(db, id: 'middlemarch', title: 'Middlemarch');
    await seedBook(db, id: 'persuasion', title: 'Persuasion');
    await seedBook(db, id: 'dracula', title: 'Dracula');
    await db.pinBook('dracula');
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget wrap() => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: NowPlayingScreen(
            db: db,
            audioService: audio,
            preferences: const UiPreferences(overrides: <String, Object>{}),
            onGoToDiscover: () {},
          ),
        ),
      );

  Future<void> expectFrame(WidgetTester tester, String name) =>
      expectLater(find.byType(NowPlayingScreen),
          matchesGoldenFile('goldens/$name.png'));

  testWidgets('idle -> playing fades frame by frame', (tester) async {
    await setSurface(tester, surface);
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    await expectFrame(tester, 'fade_forward_idle');

    // Starting playback is what drives the fade; nothing in the screen is
    // tapped, so this is the real production trigger.
    await audio.loadBook(book);

    var elapsed = 0;
    for (final ms in sampleMs) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await expectFrame(tester, 'fade_forward_${ms.toString().padLeft(3, '0')}ms');
    }

    // The last sample is past the controller's 320ms, so it doubles as the
    // proof that nothing settles late: it must equal the 320ms frame.
    expect(
      File('test/screens/goldens/fade_forward_320ms.png').readAsBytesSync(),
      File('test/screens/goldens/fade_forward_400ms.png').readAsBytesSync(),
    );

    await unmount(tester);
  });

  testWidgets('back to the list keeps playing, and fades back frame by frame',
      (tester) async {
    await setSurface(tester, surface);
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    await audio.loadBook(book);
    await pumpFrames(tester);

    // Sanity: we really are in the player before going back.
    expect(find.text('Up next'), findsOneWidget);

    final positionBefore = audio.positionNotifier.value;

    // Unloading the book is what drives the reverse fade now. The old
    // "Your list" peek used to trigger it while a book stayed loaded; that
    // affordance is gone (continue-listening lives in Library's "In
    // progress" section), but the transition itself is unchanged and its
    // frame-by-frame tuning is still worth guarding.
    audio.currentBookNotifier.value = null;

    var elapsed = 0;
    for (final ms in sampleMs) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await expectFrame(tester, 'fade_reverse_${ms.toString().padLeft(3, '0')}ms');
    }

    expect(
      File('test/screens/goldens/fade_reverse_320ms.png').readAsBytesSync(),
      File('test/screens/goldens/fade_reverse_400ms.png').readAsBytesSync(),
    );

    // Playback is genuinely untouched: the service was never paused or
    // seeked, the state is still `playing`, the position never moved and
    // the book is still loaded. (Asserting only on the notifier would pass
    // even if the screen had paused the audio on the way out.)
    expect(audio.pauseCalls, 0);
    expect(audio.seekCalls, 0);
    expect(audio.loadCalls, 1);
    expect(audio.stateNotifier.value, PlaybackState.playing);
    expect(audio.positionNotifier.value, positionBefore);

    await unmount(tester);
  });

  testWidgets('no animation when the platform asks for reduced motion',
      (tester) async {
    await setSurface(tester, surface);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: wrap(),
    ));
    await pumpFrames(tester);

    await audio.loadBook(book);
    await tester.pump();

    // Straight to the player on the very next frame — no intermediate
    // opacity, nothing to make a vestibular-sensitive user unwell.
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Continue listening'), findsNothing);

    await unmount(tester);
  });

  // Coverage for "always restore the last-played book, paused" (Task 3)
  // lives in test/screens/now_playing_screen_test.dart instead of here: it
  // reuses that file's already-proven `db`/`audio`/`tearDown` setup rather
  // than standing up a second `AppDatabase(NativeDatabase.memory())` and a
  // second `FakePlaybackService` (with its own real, undisposed
  // `AudioPlayer`) inside an individual test — doing that here was
  // extremely slow under `flutter test` and is not worth chasing down for
  // a golden-frame file that is about the animation curve, not the restore
  // feature itself.
}

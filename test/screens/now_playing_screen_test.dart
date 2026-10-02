import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/now_playing_screen.dart';
import 'package:diegema/theme/app_theme.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  // A fake, not the real `AudioPlaybackService`: Task 3's restore feature
  // (see `_maybeRestoreLastPlayed` in `now_playing_screen.dart`) means
  // almost every test in this file that seeds a `PlaybackProgress` row now
  // exercises `loadBook` on mount, unprompted. The real service's
  // `AudioPlayer` (just_audio) reaches for its platform channel the first
  // time anything actually loads a URL, which under `flutter_test` throws
  // `MissingPluginException` from inside the plugin's own unawaited
  // futures — not something a try/catch in app code can catch, and it was
  // observed bleeding across into unrelated tests in this same file. The
  // fake mirrors every real `ValueNotifier` the screen reads, so nothing
  // about what these tests actually assert changes.
  late FakePlaybackService audio;
  late Map<String, Object> prefs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
    prefs = <String, Object>{};
  });

  tearDown(() async {
    // Cancels the service's periodic progress-save timer; without this the
    // test binding reports a pending timer after the tree is torn down.
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget wrap({VoidCallback? onGoToDiscover}) => MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            // The screen jumps the fade straight to its target when
            // animations are disabled (see `_syncFade`). These tests assert
            // *what* is on screen, not how it got there, and letting the
            // 320ms controller run made them timing-dependent: the leaving
            // layer was still mounted when an expectation ran, so a book
            // title matched twice. The transition itself is covered
            // frame-by-frame by `now_playing_fade_golden_test.dart`.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: NowPlayingScreen(
                db: db,
                audioService: audio,
                preferences: UiPreferences(overrides: prefs),
                onGoToDiscover: onGoToDiscover ?? () {},
              ),
            ),
          ),
        ),
      );

  group('idle state', () {
    testWidgets('shows the empty state when nothing is in progress',
        (tester) async {
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      expect(find.text('Nothing in progress'), findsOneWidget);
      expect(find.text('Browse Discover'), findsOneWidget);
    });

    testWidgets('lists started-but-unfinished books', (tester) async {
      // Explicit, increasing `updatedAt` so the shortlist's ordering is
      // deterministic — three rows saved back-to-back can otherwise tie on
      // `DateTime.now()`.
      final now = DateTime.now();
      // Under the 30s floor: sampled, not started.
      await seedBook(db,
          id: 'b',
          title: 'Barely Opened',
          positionSeconds: 10,
          updatedAt: now.subtract(const Duration(minutes: 2)));
      // Past 95% of a 3600s runtime: effectively finished.
      await seedBook(db,
          id: 'c',
          title: 'Nearly Done',
          positionSeconds: 3500,
          updatedAt: now.subtract(const Duration(minutes: 1)));
      await seedBook(db,
          id: 'a', title: 'Middlemarch', positionSeconds: 600, updatedAt: now);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      // Matched on the row key rather than raw title text so the assertion
      // stays unambiguous if the same title renders elsewhere on screen.
      expect(find.byKey(const ValueKey('continue-a')), findsOneWidget);
      expect(find.text('Barely Opened'), findsNothing);
      expect(find.text('Nearly Done'), findsNothing);
    });
  });

  group('hide and undo', () {
    testWidgets(
        'dismissing hides from the list without deleting book or progress',
        (tester) async {
      await seedBook(db, id: 'a', title: 'Middlemarch', positionSeconds: 600);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);
      final row = find.byKey(const ValueKey('continue-a'));
      expect(row, findsOneWidget);

      await tester.drag(row, const Offset(-500, 0));
      await pumpFrames(tester);

      expect(find.byKey(const ValueKey('continue-a')), findsNothing);

      // The book and its progress row both survive; only the surface flag
      // changed. Hiding it from Continue listening is not the same as
      // deleting it.
      expect(await db.getAudiobook('a'), isNotNull);
      final progress = await db.getProgress('a');
      expect(progress, isNotNull);
      expect(progress!.positionSeconds, 600);
      expect(await db.getContinueListening(), isEmpty);
    });

    testWidgets('undo brings the book back', (tester) async {
      await seedBook(db, id: 'a', title: 'Middlemarch', positionSeconds: 600);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      await tester.drag(
          find.byKey(const ValueKey('continue-a')), const Offset(-500, 0));
      await pumpFrames(tester);

      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await pumpFrames(tester);

      expect(await db.getContinueListening(), hasLength(1));
      expect(find.byKey(const ValueKey('continue-a')), findsOneWidget);
    });
  });

  group('pinning', () {
    testWidgets('refuses a 6th pin with a user-visible message',
        (tester) async {
      // Five books pinned to the cap, none of them in progress, so the
      // continue-listening list holds exactly the candidate for a 6th pin.
      for (var i = 0; i < 5; i++) {
        await seedBook(db, id: 'p$i', title: 'Pinned $i');
        await db.pinBook('p$i');
      }
      await seedBook(db,
          id: 'sixth', title: 'Sixth Book', positionSeconds: 100);

      // Accessible names only exist once the semantics tree is built.
      final semantics = tester.ensureSemantics();
      await setSurface(tester, const Size(430, 932));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      final pinToggle = find.byKey(const ValueKey('pin-toggle-sixth'));
      expect(tester.getSemantics(pinToggle).label, contains('Pin Sixth Book'));
      await tester.tap(pinToggle);
      await pumpFrames(tester);

      expect(
        find.textContaining('You can pin up to 5 books'),
        findsOneWidget,
      );
      // The refusal is real: nothing was evicted and nothing was added.
      final pinned = await db.getPinnedBooks();
      expect(pinned, hasLength(5));
      expect(pinned.map((b) => b.id), isNot(contains('sixth')));
      semantics.dispose();
    });

    testWidgets('a pinned in-progress book appears once, with an indicator',
        (tester) async {
      await seedBook(db, id: 'a', title: 'Middlemarch', positionSeconds: 600);
      await db.pinBook('a');

      final semantics = tester.ensureSemantics();
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      // Once, in Continue listening — not duplicated into the pinned row.
      expect(find.byKey(const ValueKey('continue-a')), findsOneWidget);
      final pinToggle = find.byKey(const ValueKey('pin-toggle-a'));
      expect(pinToggle, findsOneWidget);
      expect(
          tester.getSemantics(pinToggle).label, contains('Unpin Middlemarch'));
      semantics.dispose();
    });

    testWidgets('pinned row visibility toggles and persists', (tester) async {
      await seedBook(db, id: 'a', title: 'Pinned Only');
      await db.pinBook('a');
      await seedBook(db, id: 'b', title: 'In Progress', positionSeconds: 600);

      final semantics = tester.ensureSemantics();
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      expect(find.text('Pinned Only'), findsOneWidget);

      final rowToggle = find.byKey(const ValueKey('pinned-row-toggle'));
      expect(
          tester.getSemantics(rowToggle).label, contains('Hide pinned books'));
      await tester.tap(rowToggle);
      await pumpFrames(tester);

      expect(find.text('Pinned Only'), findsNothing);
      expect(prefs['now_playing.pinned_row_visible'], isFalse);

      // A fresh mount reads the persisted preference back.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);
      expect(find.text('Pinned Only'), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('pinned-row-toggle')))
            .label,
        contains('Show 1 pinned books'),
      );
      semantics.dispose();
    });
  });

  group('launching with saved progress', () {
    testWidgets('does NOT auto-load the last-played book', (tester) async {
      // Now Playing used to restore the most recent book into the player on
      // the very first frame. That made the player the landing state for
      // anyone who had ever listened to anything, which in turn made this
      // screen's own continue-listening list unreachable — the old "peek"
      // existed purely to get back to it. Continue-listening now lives in
      // Library's "In progress" section, and launching leaves playback
      // alone.
      //
      // 161s total, seeded to 48s: a realistic mid-book position.
      await seedBook(db,
          id: 'gettysburg',
          title: 'The Gettysburg Address',
          runtimeSeconds: 161,
          positionSeconds: 48);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      // Nothing was loaded and nothing plays until the user asks.
      expect(audio.currentBookNotifier.value, isNull);
      expect(audio.loadCalls, 0);
      expect(audio.playCalls, 0);

      // The shortlist is what greets them instead, with the book on it.
      expect(find.byKey(const ValueKey('continue-gettysburg')), findsOneWidget);
    });

    testWidgets('a brand-new install with no progress stays on the empty state',
        (tester) async {
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      expect(find.text('Nothing in progress'), findsOneWidget);
      expect(audio.currentBookNotifier.value, isNull);
    });
  });

  group('phone player action row', () {
    // The "Up next" control used to be a top-left `TextButton` above the
    // player. It now lives in the bottom action-tile row alongside Speed
    // and Sleep, in the thumb zone — this asserts the new home works and
    // the old row is gone.
    testWidgets('the top-left Up next row is gone; the tile opens the queue',
        (tester) async {
      final book = await seedBook(db,
          id: 'a', title: 'Middlemarch', runtimeSeconds: 600);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);
      await audio.loadBook(book);
      await pumpFrames(tester);

      // No stray `TextButton` reading "Up next" above the player any more.
      expect(
        find.widgetWithText(TextButton, 'Up next'),
        findsNothing,
      );

      final upNextTile = find.text('Up next');
      expect(upNextTile, findsOneWidget);
      await tester.tap(upNextTile);
      await pumpFrames(tester);

      // The queue sheet opened over the player.
      expect(find.text('Middlemarch'), findsWidgets);
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/core/ui_preferences.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/screens/now_playing_screen.dart';
import 'package:unamedaudiobookplayer/services/audio_playback_service.dart';
import 'package:unamedaudiobookplayer/theme/app_theme.dart';

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

  /// Now Playing always shows the player when anything was ever played
  /// (any saved `PlaybackProgress` row — see `_maybeRestoreLastPlayed` in
  /// `now_playing_screen.dart`), so every test in this file that seeds
  /// progress mounts straight into the restored player rather than the
  /// idle list. Tapping "Your list" is the documented way back to it
  /// (same affordance the screen already offers while genuinely playing);
  /// a no-op when the screen is already showing the list (the genuinely-
  /// empty case has no "Your list" button at all).
  Future<void> revealList(WidgetTester tester) async {
    // "Your list" belongs to the player layer, so it is a reliable sentinel
    // for that layer being present. Both waits below are bounded rather than
    // a fixed pump budget because the restore is asynchronous — a DB read
    // and then `loadBook` — and a fixed budget raced it: the tap landed
    // before the player existed, the restore completed afterwards, and the
    // book title then matched twice (once in each layer).
    Future<bool> pumpUntil(bool Function() done) async {
      for (var i = 0; i < 12; i++) {
        if (done()) return true;
        await pumpFrames(tester, frames: 4);
      }
      return done();
    }

    // Nothing to go back from if the player never arrives (the genuinely-
    // empty case has no "Your list" button at all).
    final arrived = await pumpUntil(
      () => find.text('Your list').evaluate().isNotEmpty,
    );
    if (!arrived) return;

    await tester.tap(find.text('Your list').first);

    // The screen drops the player layer entirely once the reverse fade
    // reaches 0 (see `playerGone` in `now_playing_screen.dart`), so the
    // sentinel disappearing means the layer has genuinely left the tree.
    await pumpUntil(() => find.text('Your list').evaluate().isEmpty);
  }

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
      // Explicit, increasing `updatedAt` so `getMostRecentProgress` (and
      // therefore the Task 3 restore) deterministically lands on 'a' —
      // otherwise three rows saved back-to-back can tie on `DateTime.now()`
      // and which book gets restored (and therefore which title also shows
      // in the peek strip below the list, see `revealList`) becomes
      // arbitrary.
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
      // Some book with progress now restores straight into the player
      // (Task 3) — "Your list" is the way back to the shortlist this test
      // actually cares about.
      await revealList(tester);

      // The row itself, not raw title text: Middlemarch is also the
      // restored book, so its title legitimately appears a second time in
      // the "back to the player" peek strip (see `_PeekPlayerStrip` in
      // `now_playing_screen.dart`) — a key on the continue-listening row
      // is unambiguous regardless.
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
      await revealList(tester);
      final row = find.byKey(const ValueKey('continue-a'));
      expect(row, findsOneWidget);

      await tester.drag(row, const Offset(-500, 0));
      await pumpFrames(tester);

      expect(find.byKey(const ValueKey('continue-a')), findsNothing);

      // The book and its progress row both survive; only the surface flag
      // changed. It is also still the loaded (restored) book, so its title
      // legitimately remains visible in the peek strip — hiding it from
      // Continue listening is not the same as unloading it.
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
      await revealList(tester);

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
      await seedBook(db, id: 'sixth', title: 'Sixth Book', positionSeconds: 100);

      // Accessible names only exist once the semantics tree is built.
      final semantics = tester.ensureSemantics();
      await setSurface(tester, const Size(430, 932));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);
      await revealList(tester);

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
      await revealList(tester);

      // Once, in Continue listening — not duplicated into the pinned row.
      // (It also legitimately appears a second time in the peek strip,
      // since it is the restored/loaded book — see the row-key comment in
      // the 'idle state' group above.)
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
      await revealList(tester);

      expect(find.text('Pinned Only'), findsOneWidget);

      final rowToggle = find.byKey(const ValueKey('pinned-row-toggle'));
      expect(tester.getSemantics(rowToggle).label, contains('Hide pinned books'));
      await tester.tap(rowToggle);
      await pumpFrames(tester);

      expect(find.text('Pinned Only'), findsNothing);
      expect(prefs['now_playing.pinned_row_visible'], isFalse);

      // A fresh mount reads the persisted preference back. The audio
      // service instance (and its `currentBookNotifier`) survives the
      // remount, so the new screen restores straight into the player
      // again and needs the same "Your list" tap.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);
      await revealList(tester);
      expect(find.text('Pinned Only'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('pinned-row-toggle')))
            .label,
        contains('Show 1 pinned books'),
      );
      semantics.dispose();
    });
  });

  group('restoring the last-played book', () {
    testWidgets(
        'a saved PlaybackProgress row loads the player paused, unprompted',
        (tester) async {
      // 161s total, seeded to 48s — same numbers Task 4 seeds for the demo
      // build, reused here because they are a realistic mid-book position.
      await seedBook(db,
          id: 'gettysburg',
          title: 'The Gettysburg Address',
          runtimeSeconds: 161,
          positionSeconds: 48);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      // The player is showing without a single tap: no play was pressed,
      // no book was picked.
      expect(find.text('Your list'), findsOneWidget);

      // Genuinely paused, not auto-played, at the saved position.
      expect(audio.stateNotifier.value, PlaybackState.paused);
      expect(audio.currentBookNotifier.value?.id, 'gettysburg');
      expect(audio.positionNotifier.value, const Duration(seconds: 48));

      // The way back to the continue-listening list is still reachable,
      // and the restored book legitimately also appears there (it clears
      // the 30s continue-listening floor) — via its row key, since the
      // title itself also renders a second time in the peek strip below
      // the list (it is still the loaded book).
      await revealList(tester);
      expect(find.byKey(const ValueKey('continue-gettysburg')), findsOneWidget);
      expect(find.text('Player'), findsOneWidget);
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
}

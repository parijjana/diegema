import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/core/ui_preferences.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/screens/now_playing_screen.dart';
import 'package:unamedaudiobookplayer/services/audio_playback_service.dart';
import 'package:unamedaudiobookplayer/theme/app_theme.dart';

import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late AudioPlaybackService audio;
  late Map<String, Object> prefs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioPlaybackService(db: db);
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
        home: Scaffold(
          body: NowPlayingScreen(
            db: db,
            audioService: audio,
            preferences: UiPreferences(overrides: prefs),
            onGoToDiscover: onGoToDiscover ?? () {},
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
      await seedBook(db, id: 'a', title: 'Middlemarch', positionSeconds: 600);
      // Under the 30s floor: sampled, not started.
      await seedBook(db, id: 'b', title: 'Barely Opened', positionSeconds: 10);
      // Past 95% of a 3600s runtime: effectively finished.
      await seedBook(db, id: 'c', title: 'Nearly Done', positionSeconds: 3500);

      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap());
      await pumpFrames(tester);

      expect(find.text('Middlemarch'), findsOneWidget);
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
      expect(find.text('Middlemarch'), findsOneWidget);

      await tester.drag(find.text('Middlemarch'), const Offset(-500, 0));
      await pumpFrames(tester);

      expect(find.text('Middlemarch'), findsNothing);

      // The book and its progress row both survive; only the surface flag
      // changed.
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

      await tester.drag(find.text('Middlemarch'), const Offset(-500, 0));
      await pumpFrames(tester);

      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await pumpFrames(tester);

      expect(await db.getContinueListening(), hasLength(1));
      expect(find.text('Middlemarch'), findsOneWidget);
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
      expect(find.text('Middlemarch'), findsOneWidget);
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
      expect(tester.getSemantics(rowToggle).label, contains('Hide pinned books'));
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
        tester.getSemantics(find.byKey(const ValueKey('pinned-row-toggle')))
            .label,
        contains('Show 1 pinned books'),
      );
      semantics.dispose();
    });
  });
}

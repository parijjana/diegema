import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/library_book_detail_overlay.dart';

import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late AudioPlaybackService audio;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioPlaybackService(db: db);
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget wrap({LibraryScanner? scanLibrary}) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryScreen(
            db: db,
            audioService: audio,
            onGoToDiscover: () {},
            scanLibrary: scanLibrary,
          ),
        ),
      );

  testWidgets('shows the empty state when the scan finds nothing',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (_) async {}));
    await pumpFrames(tester);

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('lists whatever the scan registered', (tester) async {
    var scans = 0;
    Future<void> scan(AppDatabase db) async {
      scans++;
      await seedBook(db, id: 'scanned', title: 'Scanned From Disk');
    }

    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: scan));
    await pumpFrames(tester);

    expect(scans, 1);
    expect(find.text('Scanned From Disk'), findsOneWidget);
    expect(find.text('Library (1 book)'), findsOneWidget);
  });

  testWidgets('a failing scan surfaces the error state, not a silent empty',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester
        .pumpWidget(wrap(scanLibrary: (_) async => throw StateError('disk')));
    await pumpFrames(tester);

    expect(find.text('Could not read your library'), findsOneWidget);
  });

  testWidgets('the default scanner is a no-op without path_provider',
      (tester) async {
    // The real default used to throw MissingPluginException under the test
    // binding and print "LibraryScreen: scan failed" on every run.
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Could not read your library'), findsNothing);
  });

  testWidgets('a book with saved progress appears in the In progress section',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (db) async {
      await seedBook(db,
          id: 'started',
          title: 'Started Book',
          runtimeSeconds: 1000,
          positionSeconds: 500);
      await seedBook(db, id: 'untouched', title: 'Untouched Book');
    }));
    await pumpFrames(tester);

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('All books'), findsOneWidget);
    // The in-progress book appears twice — once per section — by design;
    // its title is not required to be unique on screen.
    expect(find.text('Started Book'), findsNWidgets(2));
    expect(find.text('Untouched Book'), findsOneWidget);
    expect(find.text('50% listened'), findsOneWidget);
  });

  testWidgets(
      'the In progress section is omitted entirely when nothing qualifies',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (db) async {
      // No `positionSeconds`, and a position under the 30-second floor —
      // neither should ever surface in "In progress".
      await seedBook(db, id: 'untouched', title: 'Untouched Book');
      await seedBook(db,
          id: 'barely-started',
          title: 'Barely Started Book',
          positionSeconds: 5);
    }));
    await pumpFrames(tester);

    expect(find.text('In progress'), findsNothing);
    expect(find.text('All books'), findsNothing);
    expect(find.text('Untouched Book'), findsOneWidget);
    expect(find.text('Barely Started Book'), findsOneWidget);
  });

  testWidgets('tapping an In progress row opens the same detail overlay',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (db) async {
      await seedBook(db,
          id: 'started',
          title: 'Started Book',
          runtimeSeconds: 1000,
          positionSeconds: 500);
    }));
    await pumpFrames(tester);

    // Tap the In progress row specifically (the first of the two "Started
    // Book" rows on screen).
    await tester.tap(find.text('Started Book').first);
    await pumpFrames(tester);

    expect(find.byType(LibraryBookDetailOverlay), findsOneWidget);
  });
}

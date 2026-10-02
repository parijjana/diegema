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

  testWidgets('cards use the accent for progress and chevrons', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (db) async {
      await seedBook(db,
          id: 'started',
          title: 'Started Book',
          runtimeSeconds: 1000,
          positionSeconds: 500);
    }));
    await pumpFrames(tester);

    final c = AppTheme.light().extension<AppColors>()!;
    final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first);
    expect(bar.valueColor!.value, c.accentFill);
    expect(bar.minHeight, greaterThanOrEqualTo(8));
    final chevron =
        tester.widget<Icon>(find.byIcon(Icons.chevron_right_rounded).first);
    expect(chevron.color, c.accentText);
  });

  testWidgets('an in-progress book is marked in All books too', (tester) async {
    await setSurface(tester, const Size(390, 1200));
    await tester.pumpWidget(wrap(scanLibrary: (db) async {
      await seedBook(db,
          id: 'started',
          title: 'Started Book',
          runtimeSeconds: 1000,
          positionSeconds: 500);
      await seedBook(db, id: 'untouched', title: 'Untouched Book');
    }));
    await pumpFrames(tester);

    expect(find.text('In progress · 50%'), findsOneWidget);
    // In-progress card + All books marker for the one book; none for the other.
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('Started Book'), findsNWidgets(2));
  });

  testWidgets('empty-state actions are a matched pair', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (_) async {}));
    await pumpFrames(tester);

    final import =
        tester.getSize(find.widgetWithText(FilledButton, 'Import a book'));
    final browse =
        tester.getSize(find.widgetWithText(OutlinedButton, 'Browse Discover'));
    expect(import.height, browse.height);
    expect(import.width, browse.width);
  });

  testWidgets('empty state and cards do not overflow at 2x text',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(wrap(scanLibrary: (_) async {}));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox()); // force a fresh state
    await tester.pumpWidget(wrap(scanLibrary: (db) async {
      await seedBook(db,
          id: 'started',
          title: 'Started Book',
          runtimeSeconds: 1000,
          positionSeconds: 500);
    }));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
  });

  group('phone one-handed layout', () {
    testWidgets(
        'the header Import/Refresh icons are gone; a floating button imports',
        (tester) async {
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap(scanLibrary: (db) async {
        await seedBook(db, id: 'a', title: 'A Book');
      }));
      await pumpFrames(tester);

      expect(find.byTooltip('Import a book'), findsNothing);
      expect(find.byTooltip('Refresh library'), findsNothing);

      final fab = find.bySemanticsLabel('Import a book');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await pumpFrames(tester);

      // Wired to the same `LocalAudiobookImporter.showOptionsModal` the
      // header icon used to call — its options sheet appearing is enough
      // to show the button drives the real action, not a no-op.
      expect(find.text('Add a library folder'), findsOneWidget);
    });

    testWidgets('pull-to-refresh re-runs the scan', (tester) async {
      var scans = 0;
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap(scanLibrary: (db) async {
        scans++;
        await seedBook(db, id: 'a', title: 'A Book');
      }));
      await pumpFrames(tester);
      expect(scans, 1);

      await tester.fling(find.text('A Book'), const Offset(0, 300), 1000);
      await pumpFrames(tester, frames: 10);

      expect(scans, 2);
    });

    testWidgets('a short list gets the Room for more prompt', (tester) async {
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap(scanLibrary: (db) async {
        await seedBook(db, id: 'a', title: 'Only Book');
      }));
      await pumpFrames(tester);

      expect(
        find.text(
            'Room for more. Find a free classic, or import one you already '
            'have.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Browse Discover'),
          findsOneWidget);
    });

    testWidgets('the prompt follows the last card, centred', (tester) async {
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(wrap(scanLibrary: (db) async {
        await seedBook(db, id: 'a', title: 'Only Book');
      }));
      await pumpFrames(tester);

      final card = tester.getRect(find.text('Only Book'));
      final prompt = tester.getRect(find.textContaining('Room for more'));
      // Close beneath the card, not pinned to the bottom of the screen.
      expect(prompt.top - card.bottom, lessThan(120));
      expect(prompt.center.dx, closeTo(390 / 2, 1));
    });
  });
}

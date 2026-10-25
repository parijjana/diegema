import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/widgets/bookmarks_sheet.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// The bookmarks sheet against a real in-memory database (the same API the
/// sync layer watches) and the fake player.
void main() {
  late AppDatabase db;
  late FakePlaybackService audio;
  late UnifiedAudiobook book;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
    book = UnifiedAudiobook(
      id: 'b',
      title: 'Frankenstein',
      author: 'Mary Shelley',
      description: 'desc',
      source: 'LibriVox',
      origin: 'librivox',
      chapters: [
        for (var i = 0; i < 3; i++)
          AudiobookChapter(
            id: 'b-$i',
            title: 'Letter ${i + 1}',
            audioPathOrUrl: 'https://example.invalid/$i.mp3',
            durationSeconds: 1000,
            isStream: true,
          ),
      ],
    );
    audio.currentBookNotifier.value = book;
    audio.chapterIndexNotifier.value = 1;
    audio.positionNotifier.value = const Duration(seconds: 754);
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Future<void> seed(String id, int chapter, int pos, String note,
      {DateTime? at}) async {
    await db.addBookmark(
        id: id,
        audiobookId: 'b',
        chapterIndex: chapter,
        positionSeconds: pos,
        note: note);
    if (at != null) {
      await db.customUpdate(
        'UPDATE bookmarks SET created_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(at.millisecondsSinceEpoch ~/ 1000),
          Variable.withString(id),
        ],
        updates: {db.bookmarks},
      );
    }
  }

  // Opens the sheet through a button so Navigator.pop in a jump has a route.
  Future<void> open(WidgetTester tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showBookmarks(context, book: book, audioService: audio, db: db),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpFrames(tester, frames: 4);
  }

  testWidgets('lists newest first with chapter, time and note', (tester) async {
    await tester.runAsync(() async {
      await seed('1', 0, 65, 'old one', at: DateTime(2026, 1, 1));
      await seed('2', 2, 3700, 'new one', at: DateTime(2026, 2, 1));
    });
    await open(tester);

    expect(find.text('Letter 3 · 1:01:40'), findsOneWidget);
    expect(find.text('Letter 1 · 01:05'), findsOneWidget);
    final newer = tester.getTopLeft(find.text('new one')).dy;
    final older = tester.getTopLeft(find.text('old one')).dy;
    expect(newer, lessThan(older));
  });

  testWidgets('shows an empty state', (tester) async {
    await open(tester);
    expect(find.textContaining('No bookmarks yet'), findsOneWidget);
  });

  testWidgets('adds a bookmark at the current position with a note',
      (tester) async {
    await open(tester);
    // After open(): the fake's inherited position stream resets it to zero
    // while the real-async frames run (see up_next_sheet_test.dart).
    audio.positionNotifier.value = const Duration(seconds: 754);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'the creature wakes');
    await tester.tap(find.text('Bookmark 12:34'));
    await pumpFrames(tester, frames: 4);

    final rows = await tester.runAsync(() => db.getBookmarks('b'));
    expect(rows, hasLength(1));
    expect(rows!.single.chapterIndex, 1);
    expect(rows.single.positionSeconds, 754);
    expect(rows.single.note, 'the creature wakes');
    expect(find.text('Letter 2 · 12:34'), findsOneWidget);
    expect(find.text('the creature wakes'), findsOneWidget);
  });

  testWidgets('tapping an entry in the current chapter seeks', (tester) async {
    await tester.runAsync(() => seed('1', 1, 100, 'here'));
    await open(tester);
    await tester.tap(find.text('Letter 2 · 01:40'));
    await pumpFrames(tester, frames: 6);

    expect(audio.seekCalls, 1);
    expect(audio.positionNotifier.value, const Duration(seconds: 100));
    expect(audio.loadCalls, 0);
    expect(find.text('Bookmarks'), findsNothing);
  });

  testWidgets('tapping an entry in another chapter switches chapter',
      (tester) async {
    await tester.runAsync(() => seed('1', 2, 42, 'there'));
    await open(tester);
    await tester.tap(find.text('Letter 3 · 00:42'));
    await pumpFrames(tester, frames: 3);

    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 2);
    expect(audio.positionNotifier.value, const Duration(seconds: 42));
  });

  testWidgets('edits a note', (tester) async {
    await tester.runAsync(() => seed('1', 0, 5, 'before'));
    await open(tester);
    await tester.tap(find.byTooltip('Edit note'));
    await pumpFrames(tester, frames: 3);
    await tester.enterText(find.widgetWithText(TextField, 'before'), 'after');
    await tester.tap(find.text('Save'));
    await pumpFrames(tester, frames: 4);

    expect(find.text('after'), findsOneWidget);
    final rows = await tester.runAsync(() => db.getBookmarks('b'));
    expect(rows!.single.note, 'after');
  });

  testWidgets('delete can be undone', (tester) async {
    await tester.runAsync(() => seed('1', 0, 5, 'keep me'));
    await open(tester);
    await tester.tap(find.byTooltip('Delete bookmark'));
    await tester.pump();
    expect(find.text('keep me'), findsNothing);
    expect(find.text('Bookmark deleted'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Undo'));
    await pumpFrames(tester, frames: 8, step: const Duration(seconds: 1));
    expect(find.text('keep me'), findsOneWidget);
    final rows = await tester.runAsync(() => db.getBookmarks('b'));
    expect(rows, hasLength(1));
  });

  testWidgets('delete becomes final when the undo window passes',
      (tester) async {
    await tester.runAsync(() => seed('1', 0, 5, 'drop me'));
    await open(tester);
    await tester.tap(find.byTooltip('Delete bookmark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await pumpFrames(tester, frames: 4);

    final rows = await tester.runAsync(() => db.getBookmarks('b'));
    expect(rows, isEmpty);
    expect(find.text('drop me'), findsNothing);
  });

  testWidgets('works at 2x text scale with 48dp targets', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(
        () => seed('1', 0, 5, 'a fairly long note that has to wrap around'));
    await open(tester);

    expect(tester.takeException(), isNull);
    for (final tip in ['Edit note', 'Delete bookmark']) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48));
  });
}

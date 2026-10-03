import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/book_detail_parts.dart';
import 'package:diegema/widgets/library_book_detail_overlay.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// The Library book detail (phone sheet + wide two-column dialog): one
/// primary action, actions behind the menu, progress summary, chapter
/// states, and no overflow at 2.0x text.
void main() {
  late AppDatabase db;
  late FakePlaybackService audio;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  UnifiedAudiobook makeBook({bool local = false}) => UnifiedAudiobook(
        id: 'tenn',
        title: '3 SF Stories by William Tenn',
        author: 'William Tenn',
        description:
            'Three short science-fiction stories by William Tenn, whose '
            'satire turns first contact, scientific progress and human vanity '
            'inside out. Each story stands alone; together they show why Tenn '
            'was one of the sharpest comic voices of the 1950s magazines. This '
            'recording is part of the LibriVox collection of public-domain '
            'works, read with great energy by a volunteer narrator who also '
            'recorded many other short fiction collections for the project.',
        origin: BookIdentity.originLibrivox,
        narrators: const ['phil chenevert'],
        isDownloaded: local,
        chapters: [
          for (var i = 0; i < 3; i++)
            AudiobookChapter(
              id: 'c$i',
              title: i == 0
                  ? '3sfstoriesbywilliamtenn_01_tenn_64kb'
                  : ['', 'Null-P', 'The Liberation of Earth'][i],
              audioPathOrUrl:
                  local ? '/books/tenn/0$i.mp3' : 'https://x/$i.mp3',
              durationSeconds: 1000,
              isStream: !local,
            ),
        ],
      );

  Future<void> pumpOverlay(
    WidgetTester tester,
    UnifiedAudiobook book, {
    int? chapterIndex,
    int? positionSeconds,
    bool wide = false,
    bool dark = false,
    VoidCallback? onRemoved,
  }) async {
    await tester.runAsync(() async {
      await db.saveAudiobook(book);
      if (chapterIndex != null) {
        await db.saveProgress(
            audiobookId: book.id,
            chapterIndex: chapterIndex,
            positionSeconds: positionSeconds ?? 0);
      }
    });
    await setSurface(
        tester, wide ? const Size(1280, 800) : const Size(390, 844));
    final overlay = LibraryBookDetailOverlay(
      book: book,
      audioService: audio,
      db: db,
      documentsPath: '/nonexistent-docs',
      onRemoved: onRemoved,
      wide: wide,
    );
    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: wide
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: Dim.detailDialogMaxWidth, maxHeight: 680),
                  child: overlay)
              : overlay,
        ),
      ),
    ));
    await pumpFrames(tester);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await pumpFrames(tester);
  }

  testWidgets('one primary action: Play with no progress', (tester) async {
    await pumpOverlay(tester, makeBook());
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(FilledButton), matching: find.text('Play')),
        findsOneWidget);
    expect(find.byType(DetailStickyFooter), findsOneWidget);
    // Secondary actions are not on the surface.
    expect(find.text('Mark as finished'), findsNothing);
    expect(find.text('Remove from library…'), findsNothing);
    expect(find.byType(BookProgressSummary), findsNothing);
  });

  testWidgets('primary action resumes at the saved chapter and time',
      (tester) async {
    await pumpOverlay(tester, makeBook(),
        chapterIndex: 1, positionSeconds: 400);
    expect(find.text('Resume · Ch 2, 06:40'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('menu lists the actions; Remove is in the danger colour',
      (tester) async {
    await pumpOverlay(tester, makeBook());
    await openMenu(tester);
    expect(find.text('Mark as finished'), findsOneWidget);
    expect(find.text('Reset progress…'), findsOneWidget);
    expect(find.text('Remove from library…'), findsOneWidget);
    // No local files / not a desktop: no folder item.
    expect(find.text('Show in Finder'), findsNothing);
    final c = AppTheme.light().extension<AppColors>()!;
    final remove = tester.widget<Text>(find.text('Remove from library…'));
    expect(remove.style!.color, c.danger);
  });

  testWidgets('menu offers Show in Finder on macOS for a local book',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await pumpOverlay(tester, makeBook(local: true));
    await openMenu(tester);
    expect(find.text('Show in Finder'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Remove from the menu still removes the book end to end',
      (tester) async {
    var removed = false;
    await pumpOverlay(tester, makeBook(), onRemoved: () => removed = true);
    await openMenu(tester);
    await tester.tap(find.text('Remove from library…'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove "3 SF Stories'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(await tester.runAsync(() => db.getAudiobook('tenn')), isNull);
  });

  testWidgets('progress summary: chapter, percentage and time left',
      (tester) async {
    // 3 x 1000 s; chapter 2 at 500 s -> 1500/3000 = 50%, 25 m... 1500 s left.
    await pumpOverlay(tester, makeBook(),
        chapterIndex: 1, positionSeconds: 500);
    expect(find.text('Chapter 2 of 3'), findsOneWidget);
    expect(find.text('50% · 25 m left'), findsOneWidget);
  });

  testWidgets('a finished book says Finished and starts over with Play',
      (tester) async {
    await pumpOverlay(tester, makeBook(),
        chapterIndex: 2, positionSeconds: AppDatabase.finishedPositionSeconds);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
  });

  testWidgets('chapter rows: finished, current and upcoming states',
      (tester) async {
    await pumpOverlay(tester, makeBook(),
        chapterIndex: 1, positionSeconds: 400);
    // Row 0: finished check, filename title prettified.
    expect(find.text('3sfstoriesbywilliamtenn_01_tenn_64kb'), findsNothing);
    expect(find.text('Part 1'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // Row 1: current, with its own mini bar and the time left.
    expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);
    expect(find.text('10:00 left'), findsOneWidget);
    final rows =
        tester.widgetList<ChapterListRow>(find.byType(ChapterListRow)).toList();
    expect(rows.map((r) => r.state), [
      ChapterRowState.finished,
      ChapterRowState.current,
      ChapterRowState.normal,
    ]);
    // Upcoming row shows its number and duration.
    expect(
        find.descendant(
            of: find.byType(ChapterListRow).last, matching: find.text('3')),
        findsOneWidget);
    expect(find.text('16:40'), findsNWidgets(2));
  });

  testWidgets('tapping a chapter plays that chapter', (tester) async {
    await pumpOverlay(tester, makeBook(),
        chapterIndex: 1, positionSeconds: 400);
    await tester.tap(find.text('The Liberation of Earth'));
    await pumpFrames(tester);
    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 2);
  });

  testWidgets('About collapses to three lines and expands', (tester) async {
    await pumpOverlay(tester, makeBook());
    expect(find.text('Read more'), findsOneWidget);
    await tester.tap(find.text('Read more'));
    await pumpFrames(tester);
    expect(find.text('Show less'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final wide in [false, true]) {
      testWidgets(
          'no overflow at 2.0x text, ${wide ? 'wide' : 'phone'}, $theme',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOverlay(tester, makeBook(local: true),
            chapterIndex: 1, positionSeconds: 400, wide: wide, dark: dark);
        expect(tester.takeException(), isNull);
        await openMenu(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

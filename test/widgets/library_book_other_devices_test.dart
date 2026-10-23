import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/library_book_detail_overlay.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late FakePlaybackService audio;

  final now = DateTime.now().millisecondsSinceEpoch;
  final book = UnifiedAudiobook(
    id: 'a',
    title: 'Emma',
    author: 'Jane Austen',
    description: '',
    source: 'LibriVox',
    origin: 'librivox',
    chapters: [
      for (var i = 0; i < 6; i++)
        AudiobookChapter(
          id: 'a-c$i',
          title: 'Chapter ${i + 1}',
          audioPathOrUrl: 'https://example.invalid/a$i.mp3',
          durationSeconds: 1800,
          isStream: true,
        ),
    ],
  );

  final names = [
    rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
    rec(SyncKind.device, 'pc', 'pc', 1, {'name': 'Desk PC'}),
  ];
  // This device is at chapter 2 (index 1), 100 s.
  final ahead = rec(SyncKind.position, 'lv:a', 'mac', 5,
      {'chapter': 3, 'seconds': 50, 'at': now - 2 * 3600000 - 5000});
  final behind = rec(SyncKind.position, 'lv:a', 'pc', 6,
      {'chapter': 0, 'seconds': 10, 'at': now - 26 * 3600000});
  final furthest =
      rec(SyncKind.furthest, 'lv:a', 'mac', 7, {'chapter': 4, 'seconds': 0});
  final finished = rec(SyncKind.finished, 'lv:a', 'pc', 8, {'finished': true});

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  FakeSyncController syncWith(List<SyncRecord> records) =>
      FakeSyncController(records: [...names, ...records], keys: {'a': 'lv:a'});

  /// Opens the overlay as a pushed route (it pops itself on a jump).
  Future<void> open(WidgetTester tester, FakeSyncController? sync,
      {bool wide = false, double textScale = 1.0}) async {
    await setSurface(
        tester, wide ? const Size(1100, 800) : const Size(390, 844));
    await tester.runAsync(() async {
      await db.saveAudiobook(book);
      await db.saveProgress(
          audiobookId: 'a', chapterIndex: 1, positionSeconds: 100);
    });
    final app = MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: LibraryBookDetailOverlay(
                      book: book, audioService: audio, db: db, wide: wide),
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
        sync == null ? app : SyncScope(controller: sync, child: app));
    await tester.tap(find.text('open'));
    await pumpFrames(tester);
  }

  testWidgets('no sync scope: no section', (tester) async {
    await open(tester, null);
    expect(find.text('Emma'), findsWidgets);
    expect(find.text('On your other devices'), findsNothing);
  });

  testWidgets('nothing on other devices: no section', (tester) async {
    await open(tester, syncWith([]));
    expect(find.text('On your other devices'), findsNothing);
  });

  testWidgets('lists each device with place, time and ahead/behind',
      (tester) async {
    await open(tester, syncWith([ahead, behind, furthest, finished]));

    expect(find.text('On your other devices'), findsOneWidget);
    expect(find.text('MacBook'), findsOneWidget);
    expect(find.text('Ch 4, 0:00:50 · 2 h ago'), findsOneWidget);
    expect(find.text('Ahead of this device'), findsOneWidget);
    expect(find.text('Desk PC'), findsOneWidget);
    expect(find.text('Ch 1, 0:00:10 · yesterday'), findsOneWidget);
    expect(find.text('Behind this device'), findsOneWidget);
    expect(find.text('Finished on Desk PC'), findsOneWidget);
    expect(find.text('Go to furthest'), findsOneWidget);
    expect(find.text('Jump here'), findsNWidgets(2));
  });

  testWidgets('no Go to furthest when nothing is further than here',
      (tester) async {
    final notFurther =
        rec(SyncKind.furthest, 'lv:a', 'mac', 7, {'chapter': 1, 'seconds': 20});
    await open(tester, syncWith([behind, notFurther]));
    expect(find.text('Jump here'), findsOneWidget);
    expect(find.text('Go to furthest'), findsNothing);
  });

  testWidgets('Jump here needs a tap, then loads that chapter and position',
      (tester) async {
    await open(tester, syncWith([ahead, behind]));
    expect(audio.loadCalls, 0, reason: 'showing the section moves nothing');

    await tester.tap(find.text('Jump here').first); // newest: MacBook
    await pumpFrames(tester);

    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 3);
    expect(audio.positionNotifier.value, const Duration(seconds: 50));
    expect(find.text('open'), findsOneWidget, reason: 'the detail closed');
  });

  testWidgets('Go to furthest jumps to the furthest place', (tester) async {
    await open(tester, syncWith([ahead, furthest]));
    await tester.tap(find.text('Go to furthest'));
    await pumpFrames(tester);

    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 4);
    expect(audio.positionNotifier.value, Duration.zero);
  });

  testWidgets('no overflow at 2.0 text scale (phone and wide)', (tester) async {
    await open(tester, syncWith([ahead, behind, furthest, finished]),
        textScale: 2.0);
    expect(find.text('On your other devices'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final tap =
        tester.getSize(find.widgetWithText(OutlinedButton, 'Jump here').first);
    expect(tap.height, greaterThanOrEqualTo(48));
  });

  testWidgets('wide dialog layout shows the section too', (tester) async {
    await open(tester, syncWith([ahead]), wide: true, textScale: 2.0);
    expect(find.text('On your other devices'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

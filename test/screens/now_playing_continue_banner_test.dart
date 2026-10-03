import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/screens/now_playing_screen.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/continue_from_banner.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late FakePlaybackService audio;

  final now = DateTime.now().millisecondsSinceEpoch;
  final localAt = now - 60 * 60000; // saved here an hour ago
  final book = UnifiedAudiobook(
    id: 'a',
    title: 'Emma',
    author: 'Jane Austen',
    description: '',
    source: 'LibriVox',
    origin: 'librivox',
    chapters: [
      for (var i = 0; i < 5; i++)
        AudiobookChapter(
          id: 'a-c$i',
          title: 'Chapter ${i + 1}',
          audioPathOrUrl: 'https://example.invalid/a$i.mp3',
          durationSeconds: 1800,
          isStream: true,
        ),
    ],
  );

  /// Another device's saved place in book 'lv:a'.
  SyncRecord remote({
    int chapter = 2,
    int seconds = 754,
    int? at,
  }) =>
      rec(SyncKind.position, 'lv:a', 'mac', 5, {
        'chapter': chapter,
        'seconds': seconds,
        'at': at ?? now - 5 * 60000 - 5000,
      });

  final macName = rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'});

  setUp(() async {
    ContinueFromBanner.debugResetClosed();
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget wrap(FakeSyncController? sync, {double textScale = 1.0}) {
    final app = MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: NowPlayingScreen(
              db: db,
              audioService: audio,
              preferences: const UiPreferences(overrides: <String, Object>{}),
              onGoToDiscover: () {},
            ),
          ),
        ),
      ),
    );
    return sync == null ? app : SyncScope(controller: sync, child: app);
  }

  /// Saved here at chapter 0, 100 s, an hour ago; the book is loaded.
  Future<void> open(WidgetTester tester, FakeSyncController? sync,
      {double textScale = 1.0}) async {
    await setSurface(tester, const Size(390, 844));
    await tester.runAsync(() async {
      await db.saveAudiobook(book);
      await db.saveProgress(
          audiobookId: 'a',
          chapterIndex: 0,
          positionSeconds: 100,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(localAt));
    });
    await audio.loadBook(book);
    audio.loadCalls = 0;
    await tester.pumpWidget(wrap(sync, textScale: textScale));
    await pumpFrames(tester);
  }

  FakeSyncController syncWith(List<SyncRecord> records) =>
      FakeSyncController(records: [macName, ...records], keys: {'a': 'lv:a'});

  const label = 'Continue from MacBook · Ch 3, 0:12:34 · 5 min ago';

  testWidgets('a newer position elsewhere offers Continue', (tester) async {
    await open(tester, syncWith([remote()]));
    expect(find.text(label), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(audio.loadCalls, 0, reason: 'showing the offer moves nothing');
    await unmount(tester);
  });

  testWidgets('no banner without a sync scope', (tester) async {
    await open(tester, null);
    expect(find.textContaining('Continue from'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no banner when the view is not ready', (tester) async {
    await open(tester, syncWith([remote()])..clearView());
    expect(find.textContaining('Continue from'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no banner when the other save is older than ours',
      (tester) async {
    await open(tester, syncWith([remote(at: localAt - 1000)]));
    expect(find.textContaining('Continue from'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no banner when it is the same place (within 15 s)',
      (tester) async {
    await open(tester, syncWith([remote(chapter: 0, seconds: 110)]));
    expect(find.textContaining('Continue from'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no banner for a book with no portable key', (tester) async {
    final sync = FakeSyncController(records: [macName, remote()]);
    await open(tester, sync);
    expect(find.textContaining('Continue from'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Continue seeks to that chapter and position, only on the tap',
      (tester) async {
    await open(tester, syncWith([remote()]));
    expect(audio.chapterIndexNotifier.value, 0);

    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);

    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 2);
    expect(audio.positionNotifier.value, const Duration(seconds: 754));
    expect(find.textContaining('Continue from'), findsNothing);
    await unmount(tester);
  });

  testWidgets('close hides that offer without seeking, for this run',
      (tester) async {
    final sync = syncWith([remote()]);
    await open(tester, sync);
    await tester.tap(find.byTooltip('Dismiss'));
    await pumpFrames(tester);

    expect(find.textContaining('Continue from'), findsNothing);
    expect(audio.loadCalls, 0);

    // A rebuild (new sync result, same offer) does not bring it back.
    sync.setRecords([macName, remote()]);
    await pumpFrames(tester);
    expect(find.textContaining('Continue from'), findsNothing);

    // A newer save from that device is a new offer.
    sync.setRecords([macName, remote(seconds: 900, at: now - 60000)]);
    await pumpFrames(tester);
    expect(find.textContaining('Continue from MacBook'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no overflow at 2.0 text scale', (tester) async {
    await open(tester, syncWith([remote()]), textScale: 2.0);
    expect(find.textContaining('Continue from MacBook'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.text('Continue'));
    expect(size.height, greaterThan(0));
    final tap = tester.getSize(find.widgetWithText(TextButton, 'Continue'));
    expect(tap.height, greaterThanOrEqualTo(48));
    await unmount(tester);
  });
}

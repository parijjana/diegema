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

  testWidgets('hidden without a sync scope', (tester) async {
    await open(tester, null);
    expect(find.text('Listeners'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('hidden when no device has anything on the book', (tester) async {
    await open(tester, syncWith([]));
    expect(find.text('Listeners'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('visible with content; opening shows device rows',
      (tester) async {
    final far =
        rec(SyncKind.furthest, 'lv:a', 'mac', 9, {'chapter': 4, 'seconds': 30});
    await open(tester, syncWith([remote(), far]));
    expect(find.text('Listeners'), findsOneWidget);
    expect(audio.loadCalls, 0);
    await tester.tap(find.text('Listeners'));
    await pumpFrames(tester);
    expect(find.text('Listeners'), findsNWidgets(2)); // button + sheet title
    expect(find.text('On your other devices'), findsNothing);
    expect(find.text('MacBook'), findsOneWidget);
    expect(find.text('Jump here'), findsOneWidget);
    expect(find.text('Go to furthest'), findsOneWidget);
    expect(audio.loadCalls, 0, reason: 'opening moves nothing');
    await unmount(tester);
  });

  testWidgets('Jump here seeks to that place and closes the sheet',
      (tester) async {
    await open(tester, syncWith([remote()]));
    await tester.tap(find.text('Listeners'));
    await pumpFrames(tester);
    await tester.tap(find.text('Jump here'));
    await pumpFrames(tester);
    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 2);
    expect(audio.positionNotifier.value, const Duration(seconds: 754));
    expect(find.text('Jump here'), findsNothing);
    expect(find.text('Go to furthest'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Go to furthest seeks to the furthest place', (tester) async {
    final far =
        rec(SyncKind.furthest, 'lv:a', 'mac', 9, {'chapter': 4, 'seconds': 30});
    await open(tester, syncWith([remote(), far]));
    await tester.tap(find.text('Listeners'));
    await pumpFrames(tester);
    await tester.tap(find.text('Go to furthest'));
    await pumpFrames(tester);
    expect(audio.chapterIndexNotifier.value, 4);
    expect(audio.positionNotifier.value, const Duration(seconds: 30));
    expect(find.text('Go to furthest'), findsNothing);
    await unmount(tester);
  });
}

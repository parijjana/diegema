// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/sync_flag.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/screens/now_playing_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// v1 ships with sync off (`DIEGEMA_SYNC` unset): the sync UI is absent and
/// no sync service is started, even when a controller is handed in. Each test
/// first proves the UI is there with sync on, so "absent" is not vacuous.
void main() {
  tearDown(() => syncEnabledForTesting = null);

  test('the default build has sync off', () {
    expect(kSyncEnabled, isFalse);
    expect(syncEnabled, isFalse);
  });

  test('no sync service is constructed while sync is off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(createSyncController(db), isNull);
  });

  group('Settings', () {
    late FakePlaybackService audio;
    setUp(() => audio = FakePlaybackService());
    tearDown(() async => audio.dispose().catchError((_) {}));

    Future<void> pump(WidgetTester tester, FakeSyncController sync) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(AudiobookApp(
        database: db,
        audioService: audio,
        sync: sync,
        libriVoxService: LibriVoxService(
          client: MockClient((r) async => http.Response('Not Found', 404)),
          rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
        ),
        preferences: const UiPreferences(overrides: <String, Object>{}),
      ));
      await pumpFrames(tester);
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byTooltip('Settings')));
      await pumpFrames(tester);
      await tester.scrollUntilVisible(find.text('Hidden books'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
    }

    testWidgets('sync on: Linked devices row shows', (tester) async {
      syncEnabledForTesting = true;
      await pump(tester, FakeSyncController());
      expect(find.text('Linked devices'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sync off: no Devices section, controller untouched',
        (tester) async {
      syncEnabledForTesting = false;
      final sync = FakeSyncController();
      await pump(tester, sync);
      expect(find.text('Hidden books'), findsOneWidget);
      expect(find.text('Linked devices'), findsNothing);
      expect(find.text('Devices'), findsNothing);
      expect(sync.refreshCalls, 0);
      expect(sync.syncNowCalls, 0);
      await unmount(tester);
    });
  });

  group('Now Playing', () {
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

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      audio = FakePlaybackService();
    });
    tearDown(() async {
      await audio.dispose().catchError((_) {});
      await db.close();
    });

    Future<FakeSyncController> open(WidgetTester tester) async {
      final sync = FakeSyncController(records: [
        rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
        rec(SyncKind.furthest, 'lv:a', 'mac', 9, {'chapter': 4, 'seconds': 30}),
        rec(SyncKind.position, 'lv:a', 'mac', 5,
            {'chapter': 2, 'seconds': 754, 'at': now - 5 * 60000}),
      ], keys: {
        'a': 'lv:a'
      });
      await setSurface(tester, const Size(390, 844));
      await tester.runAsync(() async {
        await db.saveAudiobook(book);
        await db.saveProgress(
            audiobookId: 'a',
            chapterIndex: 0,
            positionSeconds: 100,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(now - 3600000));
      });
      await audio.loadBook(book);
      await tester.pumpWidget(SyncScope(
        controller: sync,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: NowPlayingScreen(
              db: db,
              audioService: audio,
              preferences: const UiPreferences(overrides: <String, Object>{}),
              onGoToDiscover: () {},
            ),
          ),
        ),
      ));
      await pumpFrames(tester);
      return sync;
    }

    testWidgets('sync on: Listeners button shows', (tester) async {
      syncEnabledForTesting = true;
      await open(tester);
      expect(find.text('Listeners'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sync off: no Listeners button or continue banner',
        (tester) async {
      syncEnabledForTesting = false;
      final sync = await open(tester);
      expect(find.text('Emma'), findsWidgets);
      expect(find.text('Listeners'), findsNothing);
      expect(find.textContaining('MacBook'), findsNothing);
      expect(find.textContaining('Continue'), findsNothing);
      expect(sync.refreshCalls, 0);
      await unmount(tester);
    });
  });

  group('Library', () {
    late AppDatabase db;
    late AudioPlaybackService audio;
    final records = [
      rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
      rec(SyncKind.catalogue, 'ck:dune', 'mac', 4,
          {'title': 'Dune', 'author': 'Frank Herbert', 'origin': 'local'}),
    ];

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      audio = AudioPlaybackService(db: db);
    });
    tearDown(() async {
      await audio.dispose().catchError((_) {});
      await db.close();
    });

    Future<FakeSyncController> pump(WidgetTester tester) async {
      final sync = FakeSyncController(records: records);
      await setSurface(tester, const Size(390, 844));
      await tester.runAsync(() => seedBook(db, id: 'a', title: 'Alpha Book'));
      await tester.pumpWidget(SyncScope(
        controller: sync,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LibraryScreen(
              db: db,
              audioService: audio,
              onGoToDiscover: () {},
              hiddenStore:
                  HiddenBooksStore(overrides: <String, List<String>>{}),
              scanLibrary: (db) async {},
            ),
          ),
        ),
      ));
      await pumpFrames(tester);
      return sync;
    }

    testWidgets('sync on: "On your other devices" shows', (tester) async {
      syncEnabledForTesting = true;
      await pump(tester);
      expect(find.text('On your other devices'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sync off: no "On your other devices", no portable-key work',
        (tester) async {
      syncEnabledForTesting = false;
      final sync = await pump(tester);
      expect(find.text('Alpha Book'), findsOneWidget);
      expect(find.text('On your other devices'), findsNothing);
      expect(find.text('Dune'), findsNothing);
      expect(sync.refreshCalls, 0);
      await unmount(tester);
    });
  });
}

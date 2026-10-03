import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/screens/downloads_screen.dart';
import 'package:diegema/services/download_manager.dart';
import 'package:diegema/services/downloads_location_io.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/theme/app_theme.dart';

import '../support/fake_download_engine.dart';
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// Settings > Downloads: the Wi-Fi only toggle and the Downloads screen.
void main() {
  late FakePlaybackService audio;
  late FakeDownloadEngine engine;
  late AppDatabase db;
  late DownloadManager downloads;

  setUp(() async {
    audio = FakePlaybackService();
    engine = FakeDownloadEngine();
    db = AppDatabase(NativeDatabase.memory());
    downloads = DownloadManager(
        db: db,
        engine: engine,
        finish: (db, job, zip, root) async => job.toBook(const []),
        location: DownloadsLocation(
            documentsRoot: () async => '/docs', visibleRoot: () async => null));
    await downloads.start();
  });

  tearDown(() async {
    downloads.dispose();
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  DownloadJob job(String id, String title) => DownloadJob(
      id: id, url: 'https://archive.org/compress/$id', title: title);

  /// A queued download, a failed one and a finished book.
  Future<void> seedQueue() async {
    final emma = job('emma_librivox', 'Emma');
    final persuasion = job('persuasion_librivox', 'Persuasion');
    engine.persisted['emma_librivox'] =
        EngineUpdate(emma, status: EngineStatus.running, progress: 0.3);
    engine.persisted['persuasion_librivox'] =
        EngineUpdate(persuasion, status: EngineStatus.failed);
    await downloads.start();
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'tenn_librivox',
      title: 'Science Fiction Stories',
      author: 'William Tenn',
      description: '',
      source: 'Downloaded',
      origin: BookIdentity.originLibrivox,
      isDownloaded: true,
      chapters: [
        AudiobookChapter(
            id: 'c0',
            title: 'One',
            audioPathOrUrl: '/nowhere/01.mp3',
            durationSeconds: 60),
      ],
    ));
  }

  Future<Map<String, Object>> pumpApp(WidgetTester tester,
      {Map<String, Object>? store}) async {
    final prefs = store ?? <String, Object>{};
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(AudiobookApp(
      database: db,
      audioService: audio,
      downloads: downloads,
      libriVoxService: LibriVoxService(
        client: MockClient((_) async => http.Response('{"books": []}', 200)),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
      ),
      preferences: UiPreferences(overrides: prefs),
    ));
    await pumpFrames(tester);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Settings')));
    await pumpFrames(tester);
    final toggle = find.text('Download on Wi-Fi only');
    await tester.scrollUntilVisible(toggle, 120,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await pumpFrames(tester);
    return prefs;
  }

  testWidgets('the Wi-Fi only toggle persists and reaches the queue',
      (tester) async {
    final store = await pumpApp(tester);
    expect(downloads.wifiOnly, isFalse);

    await tester.tap(find.text('Download on Wi-Fi only'));
    await pumpFrames(tester);

    expect(store['downloads.wifi_only'], isTrue);
    expect(downloads.wifiOnly, isTrue);
    expect(engine.wifiSettings, [true]);
    await unmount(tester);
  });

  testWidgets('a stored Wi-Fi only choice is applied on launch',
      (tester) async {
    await pumpApp(tester, store: {'downloads.wifi_only': true});
    expect(downloads.wifiOnly, isTrue);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
    await unmount(tester);
  });

  testWidgets('Manage downloads lists the queue and the finished books',
      (tester) async {
    await seedQueue();
    await pumpApp(tester);
    final manage = find.text('Manage downloads (1 in progress)');
    await tester.scrollUntilVisible(manage, 120,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.tap(manage);
    await pumpFrames(tester);

    expect(find.byType(DownloadsScreen), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Downloading… 30%'), findsOneWidget);
    expect(find.text('Persuasion'), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.text('Science Fiction Stories'), findsOneWidget);
    expect(find.text('Files missing'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await pumpFrames(tester);
    expect(engine.enqueued.single.id, 'persuasion_librivox');

    await tester.tap(find.text('Cancel').first);
    await pumpFrames(tester);
    expect(engine.cancelled, ['emma_librivox']);
    expect(find.text('Emma'), findsNothing);
    await unmount(tester);
  });

  for (final wide in [false, true]) {
    testWidgets(
        'Downloads screen: no overflow at 2.0x text, '
        '${wide ? 'wide' : 'phone'}', (tester) async {
      await seedQueue();
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await setSurface(
          tester, wide ? const Size(1280, 800) : const Size(390, 844));
      final settings = AppSettings(preferences: const UiPreferences(overrides: {}));
      addTearDown(settings.dispose);
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: DownloadsScreen(db: db, manager: downloads),
        ),
      ));
      await pumpFrames(tester);
      expect(find.text('Download on Wi-Fi only'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // And the rows further down, which a lazy list only builds on scroll.
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await pumpFrames(tester);
      expect(find.text('Files missing'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}

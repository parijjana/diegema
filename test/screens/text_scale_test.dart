import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/ambience_service.dart';
import 'package:diegema/services/artwork_enrichment_service.dart';
import 'package:diegema/services/librivox_downloader.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/widgets/book_detail_pane.dart';
import 'package:diegema/widgets/up_next_sheet.dart';

import '../services/ambience_service_test.dart' show FakeChannel;
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// Overflow guard at 2.0x text on a phone. This app's audience includes
/// low-vision readers, so the screens other than the player (which
/// `responsive_layout_test.dart` covers) are asserted here: a `RenderFlex
/// overflowed` error is thrown, so `takeException` catches it.
void main() {
  const phone = Size(390, 844);

  MockClient buildMockClient() => MockClient((request) async {
        if (request.url.host == 'librivox.org') {
          return http.Response('{"books": []}', 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.host == 'archive.org') {
          return http.Response('{"response": {"docs": []}}', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

  // Built in `setUp`, not the test body: see `responsive_layout_test.dart`.
  late FakePlaybackService audio;

  setUp(() {
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
  });

  void doubleText(WidgetTester tester) {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ambience = AmbienceService(
      book: audio,
      preferences: const UiPreferences(overrides: <String, Object>{}),
      channelFactory: FakeChannel.new,
      fade: Duration.zero,
      useAudioSession: false,
    );
    await setSurface(tester, phone);
    await tester.pumpWidget(AudiobookApp(
      initialThemeMode: ThemeMode.light,
      database: db,
      audioService: audio,
      libriVoxService: LibriVoxService(
        client: buildMockClient(),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
      ),
      preferences: const UiPreferences(overrides: <String, Object>{}),
      ambience: ambience,
    ));
    await pumpFrames(tester);
  }

  for (final destination in ['Settings', 'Ambience', 'Discover']) {
    testWidgets('$destination survives text scale 2.0 at 390x844',
        (tester) async {
      doubleText(tester);
      await pumpApp(tester);

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(destination),
      ));
      await pumpFrames(tester);
      if (destination == 'Discover') await drainRateLimiter(tester);

      expect(tester.takeException(), isNull,
          reason: '$destination overflowed at text scale 2.0');

      await unmount(tester);
    });
  }

  testWidgets('Up next survives text scale 2.0 at 390x844', (tester) async {
    doubleText(tester);
    final book = UnifiedAudiobook(
      id: 'b',
      title: 'Frankenstein; or, The Modern Prometheus',
      author: 'Mary Wollstonecraft Shelley',
      description: 'desc',
      source: 'LibriVox',
      origin: 'librivox',
      chapters: [
        for (var i = 0; i < 4; i++)
          AudiobookChapter(
            id: 'b-$i',
            title: 'Letter ${i + 1}: To Mrs. Saville, England',
            audioPathOrUrl: 'https://example.invalid/$i.mp3',
            durationSeconds: 552 + i * 400,
            isStream: true,
          ),
      ],
    );
    audio.currentBookNotifier.value = book;
    audio.chapterIndexNotifier.value = 1;
    audio.positionNotifier.value = const Duration(seconds: 570);
    audio.durationNotifier.value = const Duration(seconds: 1000);

    await setSurface(tester, phone);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: UpNextSheet(book: book, audioService: audio)),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Up next overflowed at text scale 2.0');
  });

  testWidgets('Book detail survives text scale 2.0 at 390x844', (tester) async {
    doubleText(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final book = LibriVoxBook(
      id: '1205',
      title: 'Frankenstein; or, The Modern Prometheus',
      description: 'A monster story. ' * 20,
      totalTimeSecs: 30000,
      authors: [
        LibriVoxAuthor(id: '1', firstName: 'Mary', lastName: 'Shelley')
      ],
      urlRss: 'https://example.invalid/rss/1205',
      urlZipFile: 'https://archive.org/compress/frankenstein_1205_librivox',
      urlIarchive: 'https://archive.org/details/frankenstein_1205_librivox',
      language: 'English',
      narrators: const [],
    );
    const rss = '''<?xml version="1.0"?>
<rss version="2.0"><channel><title>Frankenstein</title>
<item><title>Letter 1</title><enclosure url="https://example.invalid/1.mp3" length="0" type="audio/mpeg"/></item>
</channel></rss>''';
    final httpClient = MockClient((request) async =>
        request.url.toString().contains('/rss/')
            ? http.Response(rss, 200)
            : http.Response('', 404));

    await setSurface(tester, phone);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookDetailPane(
          book: book,
          artworkService: ArtworkEnrichmentService(client: httpClient),
          downloader: LibriVoxStreamAndDownloader(client: httpClient),
          audioService: audio,
          db: db,
          libriVoxService: LibriVoxService(
            client: MockClient((request) async => http.Response(
                '{"result": [{"format": "64Kbps MP3", "size": "10485760"}]}',
                200)),
          ),
        ),
      ),
    ));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull,
        reason: 'Book detail overflowed at text scale 2.0');
  });
}

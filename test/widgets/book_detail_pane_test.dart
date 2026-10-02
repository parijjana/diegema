import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/artwork_enrichment_service.dart';
import 'package:diegema/services/librivox_downloader.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/widgets/book_detail_pane.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// Widget coverage for the phone redesign of `BookDetailPane`: the sticky
/// download footer (Close + "Download audiobook" / "ZIP · size") and the
/// empty-chapters note. The wide dialog path is left to its existing,
/// unchanged behaviour and is not re-asserted here.
void main() {
  late AppDatabase db;
  late FakePlaybackService audio;
  var rssStatus = 200;

  final book = LibriVoxBook(
    id: '1205',
    title: 'Frankenstein',
    description: 'A monster story.',
    totalTimeSecs: 30000,
    authors: [LibriVoxAuthor(id: '1', firstName: 'Mary', lastName: 'Shelley')],
    urlRss: 'https://example.invalid/rss/1205',
    urlZipFile: 'https://archive.org/compress/frankenstein_1205_librivox',
    urlIarchive: 'https://archive.org/details/frankenstein_1205_librivox',
    language: 'English',
    narrators: const [],
  );

  const rssWithOneChapter = '''<?xml version="1.0"?>
<rss version="2.0"><channel><title>Frankenstein</title>
<item><title>Letter 1</title><enclosure url="https://example.invalid/1.mp3" length="0" type="audio/mpeg"/></item>
</channel></rss>''';

  const rssWithNoChapters = '''<?xml version="1.0"?>
<rss version="2.0"><channel><title>Frankenstein</title></channel></rss>''';

  Widget wrap({required String rssBody, int? zipBytes}) {
    final httpClient = MockClient((request) async {
      if (request.url.toString().contains('/rss/')) {
        return http.Response(rssStatus == 200 ? rssBody : '', rssStatus);
      }
      // Cover art probe — a 404 is fine, the pane falls back to its
      // placeholder either way.
      return http.Response('', 404);
    });

    final librivoxService = zipBytes == null
        ? null
        : LibriVoxService(
            client: MockClient((request) async {
              return http.Response(
                  '{"result": [{"format": "64Kbps MP3", "size": "$zipBytes"}]}',
                  200);
            }),
          );

    return MaterialApp(
      home: Scaffold(
        body: BookDetailPane(
          book: book,
          artworkService: ArtworkEnrichmentService(client: httpClient),
          downloader: LibriVoxStreamAndDownloader(client: httpClient),
          audioService: audio,
          db: db,
          libriVoxService: librivoxService,
        ),
      ),
    );
  }

  setUp(() {
    rssStatus = 200;
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  testWidgets('phone: sticky footer shows Close and Download with the ZIP size',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
        wrap(rssBody: rssWithOneChapter, zipBytes: 10 * 1024 * 1024));
    await pumpFrames(tester);

    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.text('Download audiobook'), findsOneWidget);
    expect(find.text('ZIP · 10 MB'), findsOneWidget);

    // The old inline "Download Full Audiobook (ZIP)" button is gone from
    // the scrolling content on phone — the footer is the only download
    // control now.
    expect(find.text('Download Full Audiobook (ZIP)'), findsNothing);
  });

  testWidgets('phone: footer omits the size line when it is unknown',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(rssBody: rssWithOneChapter));
    await pumpFrames(tester);

    expect(find.text('Download audiobook'), findsOneWidget);
    expect(find.textContaining('ZIP ·'), findsNothing);
  });

  testWidgets(
      'phone: an empty chapter list shows the explanatory note, not a blank area',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(rssBody: rssWithNoChapters));
    await pumpFrames(tester);

    expect(find.text('Chapters (0)'), findsOneWidget);
    expect(
      find.text("The chapter list isn't available yet. Download the book to "
          'get every chapter.'),
      findsOneWidget,
    );
  });

  testWidgets('phone: a populated chapter list has no empty-state note',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(rssBody: rssWithOneChapter));
    await pumpFrames(tester);

    expect(find.text('Chapters (1)'), findsOneWidget);
    expect(find.byType(EmptyChaptersNote), findsNothing);
  });

  testWidgets('phone: a failed chapter fetch says so and Retry loads them',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    rssStatus = 503;
    await tester.pumpWidget(wrap(rssBody: rssWithOneChapter));
    await pumpFrames(tester);

    expect(find.textContaining("Couldn't load the chapters"), findsOneWidget);
    expect(find.textContaining("isn't available yet"), findsNothing);

    rssStatus = 200;
    await tester.tap(find.text('Retry'));
    await pumpFrames(tester);

    expect(find.textContaining("Couldn't load the chapters"), findsNothing);
    expect(find.text('Chapters (1)'), findsOneWidget);
  });

  testWidgets(
      'phone: a downloaded book shows its own chapters when the feed fails',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    rssStatus = 503;
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'frankenstein_1205_librivox',
      title: 'Frankenstein',
      author: 'Mary Shelley',
      description: '',
      source: 'Downloaded',
      origin: BookIdentity.originLibrivox,
      isDownloaded: true,
      chapters: [
        AudiobookChapter(
            id: 'c0',
            title: 'Letter 1',
            audioPathOrUrl: '/books/01.mp3',
            durationSeconds: 60),
        AudiobookChapter(
            id: 'c1',
            title: 'Letter 2',
            audioPathOrUrl: '/books/02.mp3',
            durationSeconds: 60),
      ],
    ));
    await tester.pumpWidget(wrap(rssBody: rssWithOneChapter));
    await pumpFrames(tester);

    expect(find.textContaining("Couldn't load the chapters"), findsNothing);
    expect(find.text('Chapters (2)'), findsOneWidget);
    rssStatus = 200;
  });
}

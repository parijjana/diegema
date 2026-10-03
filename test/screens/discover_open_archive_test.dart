import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/screens/discover_screen.dart';
import 'package:diegema/services/artwork_enrichment_service.dart';
import 'package:diegema/services/librivox_downloader.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

class _FakeLibriVox extends LibriVoxService {
  final LibriVoxBook? byId;
  final List<String> searches = [];
  final List<String> idLookups = [];

  _FakeLibriVox(this.byId)
      : super(
            rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero));

  @override
  Future<LibriVoxBook?> getBookById(String id) async {
    idLookups.add(id);
    return byId;
  }

  @override
  Future<List<LibriVoxBook>> searchBooks(String term,
      {int limit = 10, int offset = 0}) async {
    searches.add(term);
    return const [];
  }
}

void main() {
  late AppDatabase db;
  late FakePlaybackService audio;

  final book = LibriVoxBook(
    id: 'emma_librivox',
    title: 'Emma',
    description: 'A novel.',
    totalTimeSecs: 30000,
    authors: [LibriVoxAuthor(id: '1', firstName: 'Jane', lastName: 'Austen')],
    urlRss: 'https://example.invalid/rss/1',
    urlZipFile: 'https://archive.org/compress/emma_librivox',
    urlIarchive: 'https://archive.org/details/emma_librivox',
    language: 'English',
    narrators: const [],
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget wrap(_FakeLibriVox service) {
    final client = MockClient((r) async => http.Response('', 404));
    return MaterialApp(
      home: Scaffold(
        body: DiscoverScreen(
          db: db,
          audioService: audio,
          libriVoxService: service,
          artworkService: ArtworkEnrichmentService(client: client),
          downloader: LibriVoxStreamAndDownloader(client: client),
          openArchiveId: 'emma_librivox',
          openFallbackQuery: 'Emma Jane Austen',
        ),
      ),
    );
  }

  testWidgets('opens the book detail (with Download) by archive id',
      (tester) async {
    final service = _FakeLibriVox(book);
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(service));
    await pumpFrames(tester);

    expect(service.idLookups, ['emma_librivox']);
    expect(find.text('Emma'), findsWidgets);
    expect(find.textContaining('Download'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('falls back to searching "title author" if the lookup fails',
      (tester) async {
    final service = _FakeLibriVox(null);
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(service));
    await pumpFrames(tester);

    expect(service.searches, contains('Emma Jane Austen'));
    await unmount(tester);
  });
}

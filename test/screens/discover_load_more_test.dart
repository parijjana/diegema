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

LibriVoxBook _book(int i) => LibriVoxBook(
      id: 'book_$i',
      title: 'Book number $i',
      description: 'A novel.',
      totalTimeSecs: 3000,
      authors: [LibriVoxAuthor(id: '1', firstName: 'A', lastName: 'Author')],
      urlRss: 'https://example.invalid/rss/$i',
      urlZipFile: 'https://example.invalid/zip/$i',
      language: 'English',
      narrators: const [],
    );

/// Serves a fixed catalog of [total] books for the search term "tales" and
/// nothing for anything else (the shelves), honouring limit and offset like
/// the real service. Records every request so a test can count fetches.
class _PagedLibriVox extends LibriVoxService {
  final int total;

  /// Make the next call at this offset throw, once.
  int? failOnceAtOffset;
  final List<({String term, int limit, int offset})> calls = [];

  _PagedLibriVox(this.total)
      : super(
            rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero));

  @override
  Future<List<LibriVoxBook>> searchBooks(String term,
      {int limit = 10, int offset = 0}) async {
    if (term != 'tales') return const [];
    calls.add((term: term, limit: limit, offset: offset));
    if (failOnceAtOffset == offset) {
      failOnceAtOffset = null;
      throw StateError('offline');
    }
    return [
      for (var i = offset; i < offset + limit && i < total; i++) _book(i),
    ];
  }
}

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

  Widget wrap(LibriVoxService service) {
    final client = MockClient((r) async => http.Response('', 404));
    return MaterialApp(
      home: Scaffold(
        body: DiscoverScreen(
          db: db,
          audioService: audio,
          libriVoxService: service,
          artworkService: ArtworkEnrichmentService(client: client),
          downloader: LibriVoxStreamAndDownloader(client: client),
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpFrames(tester);
  }

  Future<void> pumpApp(WidgetTester tester, LibriVoxService service,
      {Size size = const Size(390, 844)}) async {
    await setSurface(tester, size);
    await tester.pumpWidget(wrap(service));
    await pumpFrames(tester);
  }

  Future<void> tapLoadMore(WidgetTester tester) async {
    final button = find.text('Load more');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump();
    await tester.tap(button);
    await pumpFrames(tester);
  }

  testWidgets('a full first page offers Load more and appends the next page',
      (tester) async {
    final service = _PagedLibriVox(35);
    await pumpApp(tester, service);
    await search(tester, 'tales');

    expect(find.text('20+ results'), findsOneWidget);
    expect(find.text('Load more'), findsNothing,
        reason: 'the button sits below the fold until scrolled to');
    // Nothing is fetched ahead of the tap.
    expect(service.calls.map((c) => c.offset), [0]);

    await tapLoadMore(tester);

    expect(service.calls.map((c) => (c.limit, c.offset)), [(20, 0), (20, 20)]);
    // 35 < 40 so page two came back short: that was the last page.
    expect(find.text('35 results'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a short first page has no Load more', (tester) async {
    final service = _PagedLibriVox(7);
    await pumpApp(tester, service);
    await search(tester, 'tales');

    expect(find.text('7 results'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    expect(service.calls, hasLength(1));
    await unmount(tester);
  });

  testWidgets('a repeated book is not listed twice', (tester) async {
    final service = _OverlappingLibriVox();
    await pumpApp(tester, service);
    await search(tester, 'tales');
    await tapLoadMore(tester);

    // Page two repeats book_19; 20 + 20 fetched, 39 distinct.
    expect(find.text('39+ results'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a failed page can be retried', (tester) async {
    final service = _PagedLibriVox(60)..failOnceAtOffset = 20;
    await pumpApp(tester, service);
    await search(tester, 'tales');
    await tapLoadMore(tester);

    expect(find.text('Could not load more. Try again'), findsOneWidget);
    expect(find.text('20+ results'), findsOneWidget);

    await tester.tap(find.text('Could not load more. Try again'));
    await pumpFrames(tester);
    expect(find.text('40+ results'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a new search starts again at the first page', (tester) async {
    final service = _PagedLibriVox(60);
    await pumpApp(tester, service);
    await search(tester, 'tales');
    await tapLoadMore(tester);
    await search(tester, 'tales');

    expect(find.text('20+ results'), findsOneWidget);
    expect(service.calls.last.offset, 0);
    await unmount(tester);
  });

  testWidgets('Load more is a 48dp target and fits at 2x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = _PagedLibriVox(60);
    await pumpApp(tester, service);
    await search(tester, 'tales');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(48));
    await unmount(tester);
  });
}

/// Page two repeats the last book of page one.
class _OverlappingLibriVox extends LibriVoxService {
  _OverlappingLibriVox()
      : super(
            rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero));

  @override
  Future<List<LibriVoxBook>> searchBooks(String term,
      {int limit = 10, int offset = 0}) async {
    if (term != 'tales') return const [];
    final start = offset == 0 ? 0 : 19;
    return [for (var i = start; i < start + limit; i++) _book(i)];
  }
}

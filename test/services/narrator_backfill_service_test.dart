import 'dart:convert';

import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/search_cache_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/services/narrator_backfill_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService extends LibriVoxService {
  final Map<String, List<String>?> answers;
  final bool fail;
  final bool emptySearch;
  final calls = <String>[];
  _FakeService(this.answers, {this.fail = false, this.emptySearch = false});

  @override
  Future<({List<String>? names, bool sawBooks})> narratorsForArchiveId(
      String archiveId, String title,
      {int maxPages = 2}) {
    calls.add(archiveId);
    if (fail) throw Exception('offline');
    final names = answers[archiveId];
    return Future.value((names: names, sawBooks: !emptySearch));
  }
}

UnifiedAudiobook _book(String id,
        {String origin = 'librivox', List<String> n = const []}) =>
    UnifiedAudiobook(
        id: id,
        title: id,
        author: 'A',
        description: '',
        origin: origin,
        narrators: n);

Map<String, Object?> _book2(String title, String iarchive, List<String> r) => {
      'id': '1',
      'title': title,
      'url_iarchive': iarchive,
      'authors': [],
      // As the live API: no book-level readers, only per-section ones.
      'sections': [
        for (final n in r)
          {
            'readers': [
              {'display_name': n}
            ]
          }
      ],
    };

LibriVoxService _live(
    Map<String, List<Map<String, Object?>>> byTerm, List<Uri> seen) {
  return LibriVoxService(
    rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
    cacheStore: const SearchCacheStore(),
    client: MockClient((req) async {
      seen.add(req.url);
      final t = req.url.queryParameters['title']!;
      final books = byTerm[t];
      if (books == null) {
        return http.Response('{"error":"Audiobooks could not be found"}', 404);
      }
      return http.Response(jsonEncode({'books': books}), 200);
    }),
  );
}

void main() {
  group('LibriVoxService.narratorsForArchiveId', () {
    test('resolves a Version 2 title through the base title and sections',
        () async {
      final seen = <Uri>[];
      final svc = _live({
        '^happy prince and other tales': [
          _book2(
              'Happy Prince and Other Tales',
              'https://www.archive.org/details/happyprince_1103_librivox',
              ['Ann']),
          _book2('Happy Prince and Other Tales (version 2)',
              'https://archive.org/details/happyprince_v2_librivox', ['Bob']),
        ],
      }, seen);
      final r = await svc.narratorsForArchiveId('happyprince_1103_librivox',
          'The Happy Prince and Other Tales, Version 2');
      expect(r.names, ['Ann']);
      expect(seen.single.queryParameters['title'],
          '^happy prince and other tales');
    });

    test('sci-fi volumes are found by their bare number', () async {
      final seen = <Uri>[];
      final svc = _live({
        '^short science fiction collection 001': [
          _book2('Short Science Fiction Collection 001',
              'https://www.archive.org/details/short_scifi_001_0711', ['Cy']),
        ],
        '^short science fiction collection 032': [
          _book2(
              'Short Science Fiction Collection 032',
              'https://www.archive.org/details/short_scifi_32_1001_librivox',
              ['Di', 'Ed']),
        ],
      }, seen);
      expect(
          (await svc.narratorsForArchiveId('short_scifi_001_0711',
                  'Short Science Fiction Collection Vol. 001'))
              .names,
          ['Cy']);
      expect(
          (await svc.narratorsForArchiveId('short_scifi_32_1001_librivox',
                  'Short Science Fiction Collection Vol. 032'))
              .names,
          ['Di', 'Ed']);
    });

    test('404 for every term: no books seen, no match', () async {
      final svc = _live({}, []);
      final r = await svc.narratorsForArchiveId('x_librivox', 'Nothing Here');
      expect(r.names, isNull);
      expect(r.sawBooks, isFalse);
    });
  });

  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.saveAudiobook(_book('a_1_librivox'));
    await db.saveAudiobook(_book('b_2_librivox', n: const ['Kept']));
    await db.saveAudiobook(_book('gone_3_librivox'));
    await db.saveAudiobook(_book('local_x', origin: 'local'));
  });
  tearDown(() => db.close());

  test('fills missing readers, skips filled and local, then stops rerunning',
      () async {
    final prefs = <String, Object>{};
    final svc = _FakeService({
      'a_1_librivox': ['Ann'],
      'gone_3_librivox': null
    });
    await NarratorBackfillService(db: db, service: svc, overrides: prefs).run();

    expect(svc.calls, ['a_1_librivox', 'gone_3_librivox']);
    expect((await db.getAudiobook('a_1_librivox'))!.narrators, ['Ann']);
    expect((await db.getAudiobook('b_2_librivox'))!.narrators, ['Kept']);
    expect(prefs[NarratorBackfillService.doneKey], 1);

    await NarratorBackfillService(db: db, service: svc, overrides: prefs).run();
    expect(svc.calls.length, 2);
  });

  test('searches that find nothing do not set the done flag', () async {
    final prefs = <String, Object>{};
    final svc = _FakeService({}, emptySearch: true);
    await NarratorBackfillService(db: db, service: svc, overrides: prefs).run();
    expect(prefs[NarratorBackfillService.doneKey], isNull);
    expect(prefs[NarratorBackfillService.attemptsKey], 1);
  });

  test('a failure leaves the flag unset and retries only up to the cap',
      () async {
    final prefs = <String, Object>{};
    final svc = _FakeService({}, fail: true);
    for (var i = 0; i < 5; i++) {
      await NarratorBackfillService(db: db, service: svc, overrides: prefs)
          .run();
    }
    expect(prefs[NarratorBackfillService.doneKey], isNull);
    // One call per launch (it stops at the first failure), 3 launches max.
    expect(svc.calls.length, NarratorBackfillService.maxAttempts);
  });
}

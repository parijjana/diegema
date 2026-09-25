import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/services/search_cache_store.dart';

void main() {
  group('LibriVoxService TDD Unit Tests', () {
    test('searchBooks returns parsed books from LibriVox API response',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'librivox.org') {
          const responseJson = '''
          {
            "books": [
              {
                "id": "101",
                "title": "Dracula",
                "description": "Vampire novel.",
                "totaltimesecs": "36000",
                "authors": [{"id": "1", "first_name": "Bram", "last_name": "Stoker"}],
                "url_rss": "https://librivox.org/rss/101",
                "url_zip_file": "https://librivox.org/zip/101",
                "url_iarchive": "http://www.archive.org/details/dracula_librivox",
                "language": "English"
              }
            ]
          }
          ''';
          return http.Response(responseJson, 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 444);
      });

      final service = LibriVoxService(client: mockClient);
      final books = await service.searchBooks('Dracula');

      expect(books.length, equals(1));
      expect(books.first.title, equals('Dracula'));
      expect(books.first.authorNames, equals('Bram Stoker'));
      expect(books.first.coverArtUrl,
          equals('https://archive.org/services/img/dracula_librivox'));
    });

    test(
        'searchBooks falls back to Internet Archive search when LibriVox returns empty',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'librivox.org') {
          return http.Response('{"books": []}', 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.host == 'archive.org') {
          const iaResponse = '''
          {
            "response": {
              "docs": [
                {
                  "identifier": "frankenstein_1205_librivox",
                  "title": "Frankenstein",
                  "description": "Monster story.",
                  "creator": "Mary Shelley"
                }
              ]
            }
          }
          ''';
          return http.Response(iaResponse, 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Error', 500);
      });

      final service = LibriVoxService(client: mockClient);
      final books = await service.searchBooks('Frankenstein');

      expect(books.length, equals(1));
      expect(books.first.title, equals('Frankenstein'));
      expect(books.first.authorNames, equals('Mary Shelley'));
      expect(
          books.first.coverArtUrl,
          equals(
              'https://archive.org/services/img/frankenstein_1205_librivox'));
    });
  });

  group('zipSizeBytes', () {
    test('sums the size of every 64Kbps MP3 file', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(),
            'https://archive.org/metadata/odyssey_1709_librivox/files');
        const responseJson = '''
        {
          "result": [
            {"name": "odyssey_01.mp3", "format": "64Kbps MP3", "size": "12000000"},
            {"name": "odyssey_02.mp3", "format": "64Kbps MP3", "size": "11000000"},
            {"name": "odyssey.ogg", "format": "Ogg Vorbis", "size": "9000000"},
            {"name": "odyssey_metadata.xml", "format": "Metadata"}
          ]
        }
        ''';
        return http.Response(responseJson, 200,
            headers: {'content-type': 'application/json'});
      });

      final service = LibriVoxService(client: mockClient);
      final bytes = await service.zipSizeBytes('odyssey_1709_librivox');

      expect(bytes, equals(23000000));
    });

    test('caches the result per identifier', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response(
            '{"result": [{"format": "64Kbps MP3", "size": "1000"}]}', 200,
            headers: {'content-type': 'application/json'});
      });

      final service = LibriVoxService(client: mockClient);
      await service.zipSizeBytes('a');
      await service.zipSizeBytes('a');

      expect(calls, equals(1));
    });

    test('never throws: a network failure resolves to null', () async {
      final mockClient = MockClient((request) async {
        throw Exception('offline');
      });

      final service = LibriVoxService(client: mockClient);
      final bytes = await service.zipSizeBytes('anything');

      expect(bytes, isNull);
    });

    test('resolves to null when no 64Kbps MP3 files are listed', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
            '{"result": [{"format": "Ogg Vorbis", "size": "500"}]}', 200,
            headers: {'content-type': 'application/json'});
      });

      final service = LibriVoxService(client: mockClient);
      final bytes = await service.zipSizeBytes('no-mp3');

      expect(bytes, isNull);
    });
  });

  group('search cache', () {
    const feed = '''{"books":[{"id":"101","title":"Dracula","description":"",
      "totaltimesecs":"36000","authors":[],"url_rss":"","url_zip_file":"",
      "url_iarchive":"http://www.archive.org/details/dracula_librivox",
      "language":"English"}]}''';

    late int calls;
    late DateTime now;
    late LibriVoxService service;
    late Map<String, String> disk;

    setUp(() {
      calls = 0;
      disk = {};
      now = DateTime(2026, 9, 24, 12);
      service = LibriVoxService(
        client: MockClient((request) async {
          calls++;
          return http.Response(feed, 200);
        }),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
        now: () => now,
        cacheStore: SearchCacheStore(overrides: disk),
      );
    });

    test('a revisit within the TTL makes no request', () async {
      await service.searchBooks('');
      now = now.add(const Duration(hours: 23));
      final again = await service.searchBooks('');

      expect(calls, 1);
      expect(again.single.title, 'Dracula');
    });

    test('an expired entry is fetched again', () async {
      await service.searchBooks('');
      now = now.add(const Duration(hours: 25));
      await service.searchBooks('');

      expect(calls, 2);
    });

    test('concurrent callers share one request', () async {
      await Future.wait([service.searchBooks(''), service.searchBooks('')]);

      expect(calls, 1);
    });

    test('an empty result is not cached', () async {
      final scratch = <String, String>{};
      final empty = LibriVoxService(
        client: MockClient((request) async {
          calls++;
          return http.Response('oops', 500);
        }),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
        cacheStore: SearchCacheStore(overrides: scratch),
      );
      await empty.searchBooks('');
      await empty.searchBooks('');

      expect(calls, 2);
    });

    LibriVoxService relaunch() => LibriVoxService(
          client: MockClient((request) async {
            calls++;
            return http.Response(feed, 200);
          }),
          rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
          now: () => now,
          cacheStore: SearchCacheStore(overrides: disk),
        );

    test('a fresh launch serves the shelf from disk', () async {
      await service.searchBooks('');
      now = now.add(const Duration(hours: 10));
      final books = await relaunch().searchBooks('');

      expect(calls, 1);
      expect(books.single.title, 'Dracula');
    });

    test('a stale disk entry is fetched again after a launch', () async {
      await service.searchBooks('');
      now = now.add(const Duration(hours: 25));
      await relaunch().searchBooks('');

      expect(calls, 2);
    });

    test('a corrupt disk cache is a cold start, not a crash', () async {
      disk['discover.search_cache.v1'] = '{not json';
      final books = await relaunch().searchBooks('');

      expect(books.single.title, 'Dracula');
      expect(calls, 1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/services/librivox_service.dart';

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
}

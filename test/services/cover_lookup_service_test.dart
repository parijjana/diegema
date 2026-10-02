import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/services/cover_lookup_service.dart';

void main() {
  test('finds a cover via LibriVox/archive.org on a strong title match',
      () async {
    final client = MockClient((request) async {
      expect(request.url.host, equals('archive.org'));
      expect(request.url.path, equals('/advancedsearch.php'));
      return http.Response(
        jsonEncode({
          'response': {
            'docs': [
              {
                'identifier': 'odyssey_boys_girls_librivox',
                'title': 'The Odyssey for Boys and Girls',
                'creator': 'Alfred J. Church',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoverLookupService(client: client);
    final url = await service.lookupCoverUrl(
      title: 'Odyssey for Boys and Girls',
      author: 'Alfred J. Church',
    );

    expect(url,
        equals('https://archive.org/services/img/odyssey_boys_girls_librivox'));
  });

  test('falls back to Open Library when archive.org has no strong match',
      () async {
    final client = MockClient((request) async {
      if (request.url.host == 'archive.org') {
        return http.Response(
          jsonEncode({
            'response': {'docs': <dynamic>[]}
          }),
          200,
        );
      }
      expect(request.url.host, equals('openlibrary.org'));
      return http.Response(
        jsonEncode({
          'docs': [
            {
              'title': 'Some Book',
              'author_name': ['Some Author'],
              'cover_i': 12345,
            },
          ],
        }),
        200,
      );
    });

    final service = CoverLookupService(client: client);
    final url =
        await service.lookupCoverUrl(title: 'Some Book', author: 'Some Author');

    expect(
        url,
        equals(
            'https://covers.openlibrary.org/b/id/12345-L.jpg?default=false'));
  });

  test('returns null when both sources have nothing', () async {
    final client = MockClient((request) async {
      final body = request.url.host == 'archive.org'
          ? {
              'response': {'docs': <dynamic>[]}
            }
          : {'docs': <dynamic>[]};
      return http.Response(jsonEncode(body), 200);
    });

    final service = CoverLookupService(client: client);
    final url = await service.lookupCoverUrl(title: 'Nothing Findable');

    expect(url, isNull);
  });

  test('rejects a weak match (title matches, authors disagree)', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'archive.org') {
        return http.Response(
          jsonEncode({
            'response': {
              'docs': [
                {
                  'identifier': 'wrong_author_book',
                  'title': 'Ambiguous Title',
                  'creator': 'A Totally Different Author',
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'docs': [
            {
              'title': 'Ambiguous Title',
              'author_name': ['Also A Different Author'],
              'cover_i': 999,
            },
          ],
        }),
        200,
      );
    });

    final service = CoverLookupService(client: client);
    final url = await service.lookupCoverUrl(
      title: 'Ambiguous Title',
      author: 'The Real Author',
    );

    expect(url, isNull);
  });

  test('a network error is swallowed and returns null', () async {
    final client = MockClient((request) async {
      throw Exception('network down');
    });

    final service = CoverLookupService(client: client);
    final url = await service.lookupCoverUrl(title: 'Anything');

    expect(url, isNull);
  });

  test('title normalisation ignores a leading "The" and a version suffix',
      () async {
    final client = MockClient((request) async {
      if (request.url.host != 'archive.org') {
        return http.Response(jsonEncode({'docs': <dynamic>[]}), 200);
      }
      return http.Response(
        jsonEncode({
          'response': {
            'docs': [
              {
                'identifier': 'match_id',
                'title': 'Great Expectations (version 3)',
              },
            ],
          },
        }),
        200,
      );
    });

    final service = CoverLookupService(client: client);
    final url = await service.lookupCoverUrl(title: 'The Great Expectations');

    expect(url, equals('https://archive.org/services/img/match_id'));
  });
}

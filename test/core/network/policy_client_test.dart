import 'dart:io';

import 'package:diegema/core/network/policy_client.dart';
import 'package:diegema/core/network/url_policy.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/artwork_enrichment_service.dart';
import 'package:diegema/services/cover_lookup_service.dart';
import 'package:diegema/services/librivox_downloader_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _redirect(String to, [int code = 302]) =>
    http.Response('', code, headers: {'location': to});

LibriVoxBook _book(
        {String zip = 'https://archive.org/d/x.zip', String rss = ''}) =>
    LibriVoxBook(
      id: 'abc',
      title: 'T',
      description: '',
      totalTimeSecs: 0,
      authors: const [],
      urlRss: rss,
      urlZipFile: zip,
      urlIarchive: 'https://archive.org/details/abc_librivox',
      language: 'English',
      narrators: const [],
    );

void main() {
  group('permittedFetchUrl', () {
    test('allows exact Open Library hosts, https only, no wildcard', () {
      expect(permittedFetchUrl('https://covers.openlibrary.org/b/id/1-L.jpg'),
          'https://covers.openlibrary.org/b/id/1-L.jpg');
      expect(permittedFetchUrl('http://openlibrary.org/search.json?a=1'),
          'https://openlibrary.org/search.json?a=1');
      expect(permittedFetchUrl('https://evil.openlibrary.org/x'), isNull);
      expect(permittedFetchUrl('https://openlibrary.org.evil.com/x'), isNull);
      expect(permittedFetchUrl('https://example.com/c.jpg'), isNull);
    });

    test('permittedRemoteUrl (audio/zip/feeds) does not allow Open Library',
        () {
      expect(
          permittedRemoteUrl('https://covers.openlibrary.org/a.mp3'), isNull);
    });
  });

  group('PolicyHttpClient redirects', () {
    test('follows allowed https hops', () async {
      final seen = <String>[];
      final c = PolicyHttpClient(MockClient((r) async {
        seen.add(r.url.toString());
        expect(r.followRedirects, isFalse);
        if (r.url.host == 'archive.org') {
          return _redirect('https://ia800.us.archive.org/f.zip');
        }
        return http.Response('ok', 200);
      }));
      final res = await c.get(Uri.parse('https://archive.org/a'));
      expect(res.body, 'ok');
      expect(seen,
          ['https://archive.org/a', 'https://ia800.us.archive.org/f.zip']);
    });

    test('refuses an https to http redirect', () async {
      final c = PolicyHttpClient(
          MockClient((r) async => _redirect('http://archive.org/b')));
      expect(c.get(Uri.parse('https://archive.org/a')),
          throwsA(isA<UrlPolicyException>()));
    });

    test('refuses an off-allowlist redirect', () async {
      var calls = 0;
      final c = PolicyHttpClient(MockClient((r) async {
        calls++;
        return _redirect('https://evil.example/x');
      }));
      await expectLater(c.get(Uri.parse('https://librivox.org/a')),
          throwsA(isA<UrlPolicyException>()));
      expect(calls, 1);
    });

    test('refuses a relative redirect that stays fine but loops past max',
        () async {
      final c = PolicyHttpClient(MockClient((r) async => _redirect('/again')),
          maxRedirects: 3);
      await expectLater(c.get(Uri.parse('https://archive.org/a')),
          throwsA(isA<UrlPolicyException>()));
    });

    test('refuses a disallowed first request without sending it', () async {
      var calls = 0;
      final c = PolicyHttpClient(MockClient((r) async {
        calls++;
        return http.Response('', 200);
      }));
      await expectLater(c.get(Uri.parse('http://archive.org/a')),
          throwsA(isA<UrlPolicyException>()));
      await expectLater(c.get(Uri.parse('https://example.com/a')),
          throwsA(isA<UrlPolicyException>()));
      expect(calls, 0);
    });

    test('refuses non-GET methods', () async {
      final c =
          PolicyHttpClient(MockClient((r) async => http.Response('', 200)));
      await expectLater(c.post(Uri.parse('https://archive.org/a')),
          throwsA(isA<UrlPolicyException>()));
    });
  });

  group('callers', () {
    test('ZIP download refuses a disallowed URL and never sends', () async {
      var calls = 0;
      final d = LibriVoxStreamAndDownloader(client: MockClient((r) async {
        calls++;
        return http.Response('', 200);
      }));
      for (final u in [
        'https://evil.example/x.zip',
        'file:///etc/passwd',
        'http://evil.example/x.zip'
      ]) {
        await expectLater(
            d.downloadAndExtractZip(_book(zip: u),
                saveDirectoryPath: Directory.systemTemp.path),
            throwsA(isA<UrlPolicyException>()));
      }
      expect(calls, 0);
    });

    test('ZIP download refuses a redirect off the allowlist', () async {
      final d = LibriVoxStreamAndDownloader(
          client: MockClient((r) async => _redirect('https://evil.example/x')));
      await expectLater(
          d.downloadAndExtractZip(_book(),
              saveDirectoryPath: Directory.systemTemp.path),
          throwsA(isA<UrlPolicyException>()));
    });

    test('artwork check refuses an off-policy cover URL without fetching',
        () async {
      var calls = 0;
      final s = ArtworkEnrichmentService(client: MockClient((r) async {
        calls++;
        return http.Response('', 200, headers: {'content-type': 'image/jpeg'});
      }));
      // coverArtUrl is always archive.org; a redirect off-policy yields null.
      final s2 = ArtworkEnrichmentService(
          client:
              MockClient((r) async => _redirect('http://evil.example/c.jpg')));
      expect(await s2.resolveCoverArtUrl(_book()), isNull);
      expect(await s.resolveCoverArtUrl(_book()), isNotNull);
      expect(calls, 1);
    });

    test('cover lookup: Open Library is reached; off-policy redirect is not',
        () async {
      final hosts = <String>[];
      final lookup = CoverLookupService(client: MockClient((r) async {
        hosts.add(r.url.host);
        if (r.url.host == 'archive.org') {
          return http.Response('{"response":{"docs":[]}}', 200);
        }
        return _redirect('https://evil.example/s');
      }));
      expect(await lookup.lookupCoverUrl(title: 'Emma'), isNull);
      expect(hosts, ['archive.org', 'openlibrary.org']);
    });
  });
}

import 'package:diegema/core/network/url_policy.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/download_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('permittedRemoteUrl', () {
    test('keeps https on allowed hosts', () {
      expect(permittedRemoteUrl('https://archive.org/download/x/x.zip'),
          'https://archive.org/download/x/x.zip');
      expect(permittedRemoteUrl('https://ia800000.us.archive.org/1/a.mp3'),
          'https://ia800000.us.archive.org/1/a.mp3');
      expect(permittedRemoteUrl('https://librivox.org/rss/101'),
          'https://librivox.org/rss/101');
      expect(permittedRemoteUrl('https://www.archive.org/details/x'),
          'https://www.archive.org/details/x');
    });

    test('upgrades http to https on allowed hosts, keeping path and query', () {
      expect(permittedRemoteUrl('http://www.archive.org/details/dracula'),
          'https://www.archive.org/details/dracula');
      expect(permittedRemoteUrl('http://librivox.org/a.zip?x=1'),
          'https://librivox.org/a.zip?x=1');
      expect(
          permittedRemoteUrl('HTTP://Archive.ORG/a'), 'https://archive.org/a');
    });

    test('refuses other schemes', () {
      for (final u in [
        'file:///etc/passwd',
        'file://archive.org/x',
        'ftp://archive.org/x',
        'javascript:alert(1)',
        'smb://archive.org/x',
        '/local/path.mp3',
        'archive.org/x',
        '',
      ]) {
        expect(permittedRemoteUrl(u), isNull, reason: u);
      }
    });

    test('refuses other hosts, lookalikes, userinfo tricks and odd ports', () {
      for (final u in [
        'https://example.com/a.mp3',
        'http://example.com/a.mp3',
        'https://evilarchive.org/a',
        'https://archive.org.evil.com/a',
        'https://archive.org@evil.com/a',
        'https://user:pw@archive.org/a',
        'https://archive.org:8443/a',
        'https://127.0.0.1/a',
      ]) {
        expect(permittedRemoteUrl(u), isNull, reason: u);
      }
    });
  });

  group('DownloadJob.fromLibriVox', () {
    LibriVoxBook book(String zip, {String iarchive = ''}) => LibriVoxBook(
        id: '1',
        title: 't',
        description: '',
        totalTimeSecs: 0,
        authors: const [],
        urlRss: '',
        urlZipFile: zip,
        urlIarchive: iarchive,
        language: 'English',
        narrators: const []);

    test('upgrades an http catalogue ZIP link', () {
      final job = DownloadJob.fromLibriVox(book('http://librivox.org/z/1.zip'));
      expect(job.url, 'https://librivox.org/z/1.zip');
    });

    test('refuses a ZIP link on another host', () {
      expect(() => DownloadJob.fromLibriVox(book('http://evil.example/z.zip')),
          throwsA(isA<UnsupportedUrlException>()));
    });
  });
}

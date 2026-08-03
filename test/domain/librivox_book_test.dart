import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/domain/models/librivox_book.dart';

void main() {
  group('LibriVoxBook Unit Tests', () {
    test('authorNames formats multiple authors correctly', () {
      final book = LibriVoxBook(
        id: '123',
        title: 'Pride and Prejudice',
        description: 'A classic novel.',
        totalTimeSecs: 3600,
        authors: [
          LibriVoxAuthor(id: '1', firstName: 'Jane', lastName: 'Austen'),
          LibriVoxAuthor(id: '2', firstName: 'Co', lastName: 'Author'),
        ],
        urlRss: 'https://librivox.org/rss/123',
        urlZipFile: 'https://librivox.org/zip/123',
        language: 'English',
        narrators: ['Narrator A'],
      );

      expect(book.authorNames, equals('Jane Austen, Co Author'));
    });

    test('authorNames handles empty author list', () {
      final book = LibriVoxBook(
        id: '124',
        title: 'Anonymous Work',
        description: 'No author listed.',
        totalTimeSecs: 1800,
        authors: [],
        urlRss: '',
        urlZipFile: '',
        language: 'English',
        narrators: [],
      );

      expect(book.authorNames, equals('Unknown Author'));
    });

    test('coverArtUrl resolves Internet Archive image URL from urlIarchive', () {
      final book = LibriVoxBook(
        id: '999',
        title: 'Moby Dick',
        description: 'Whale tale.',
        totalTimeSecs: 7200,
        authors: [LibriVoxAuthor(id: '3', firstName: 'Herman', lastName: 'Melville')],
        urlRss: '',
        urlZipFile: '',
        urlIarchive: 'http://www.archive.org/details/moby_dick_librivox',
        language: 'English',
        narrators: [],
      );

      expect(book.coverArtUrl, equals('https://archive.org/services/img/moby_dick_librivox'));
    });

    test('coverArtUrl resolves string ID identifier', () {
      final book = LibriVoxBook(
        id: 'war_and_peace_librivox',
        title: 'War and Peace',
        description: 'Epic story.',
        totalTimeSecs: 10000,
        authors: [LibriVoxAuthor(id: '4', firstName: 'Leo', lastName: 'Tolstoy')],
        urlRss: '',
        urlZipFile: '',
        language: 'English',
        narrators: [],
      );

      expect(book.coverArtUrl, equals('https://archive.org/services/img/war_and_peace_librivox'));
    });

    test('fromJson and toJson roundtrip correctly', () {
      final jsonMap = {
        'id': '555',
        'title': 'Test Book',
        'description': 'Description text',
        'totaltimesecs': '1200',
        'authors': [
          {'id': '10', 'first_name': 'First', 'last_name': 'Last'}
        ],
        'url_rss': 'https://example.com/rss',
        'url_zip_file': 'https://example.com/zip',
        'url_iarchive': 'https://archive.org/details/test_book',
        'language': 'English',
        'sections': [
          {
            'readers': [
              {'display_name': 'Reader One'}
            ]
          }
        ]
      };

      final book = LibriVoxBook.fromJson(jsonMap);
      expect(book.id, equals('555'));
      expect(book.title, equals('Test Book'));
      expect(book.narrators, contains('Reader One'));
      expect(book.coverArtUrl, equals('https://archive.org/services/img/test_book'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/domain/models/audiobook.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Persistence Unit Tests', () {
    test('saveAudiobook and getAudiobook persist book and chapters correctly', () async {
      final book = UnifiedAudiobook(
        id: 'book_001',
        title: 'Sherlock Holmes',
        author: 'Arthur Conan Doyle',
        description: 'Detective stories.',
        source: 'LibriVox',
        coverArtUrlOrPath: 'https://archive.org/services/img/sherlock',
        isDownloaded: true,
        chapters: [
          AudiobookChapter(
            id: 'ch_01',
            title: 'A Study in Scarlet',
            audioPathOrUrl: '/path/to/ch1.mp3',
            durationSeconds: 1800,
            isStream: false,
          ),
          AudiobookChapter(
            id: 'ch_02',
            title: 'The Sign of the Four',
            audioPathOrUrl: '/path/to/ch2.mp3',
            durationSeconds: 2400,
            isStream: false,
          ),
        ],
      );

      await db.saveAudiobook(book);

      final retrieved = await db.getAudiobook('book_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Sherlock Holmes'));
      expect(retrieved.author, equals('Arthur Conan Doyle'));
      expect(retrieved.chapters.length, equals(2));
      expect(retrieved.chapters[0].title, equals('A Study in Scarlet'));
      expect(retrieved.chapters[1].title, equals('The Sign of the Four'));
    });

    test('getAllAudiobooks retrieves all stored audiobooks', () async {
      final book1 = UnifiedAudiobook(
        id: 'book_a',
        title: 'Book A',
        author: 'Author A',
        description: 'Desc A',
        chapters: [],
      );

      final book2 = UnifiedAudiobook(
        id: 'book_b',
        title: 'Book B',
        author: 'Author B',
        description: 'Desc B',
        chapters: [],
      );

      await db.saveAudiobook(book1);
      await db.saveAudiobook(book2);

      final all = await db.getAllAudiobooks();
      expect(all.length, equals(2));
      expect(all.map((b) => b.title), containsAll(['Book A', 'Book B']));
    });

    test('saveProgress and getProgress update timestamp and position', () async {
      await db.saveProgress(
        audiobookId: 'book_001',
        chapterIndex: 2,
        positionSeconds: 145,
      );

      final progress = await db.getProgress('book_001');
      expect(progress, isNotNull);
      expect(progress!.chapterIndex, equals(2));
      expect(progress.positionSeconds, equals(145));
    });

    test('addBookmark and getBookmarks persist timestamp notes', () async {
      await db.addBookmark(
        id: 'bm_1',
        audiobookId: 'book_001',
        chapterIndex: 0,
        positionSeconds: 300,
        note: 'Important clue',
      );

      final bookmarks = await db.getBookmarks('book_001');
      expect(bookmarks.length, equals(1));
      expect(bookmarks.first.note, equals('Important clue'));
      expect(bookmarks.first.positionSeconds, equals(300));
    });
  });
}

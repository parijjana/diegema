// Tests for the schema-v2 DAO methods: pinning, hidden-from-continue,
// user cover art, bookmark/clip CRUD, and the continue-listening query
// (rework_plan.md Phase 1 item 8 / ui_redesign_plan.md's data-layer
// requirements). Runs against no network access, matching this
// project's test-suite convention.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';

Future<void> _seedBook(
  AppDatabase db, {
  required String id,
  String origin = 'local',
  List<AudiobookChapter> chapters = const [],
}) async {
  await db.saveAudiobook(
    UnifiedAudiobook(
      id: id,
      title: 'Book $id',
      author: 'Author',
      description: 'Description',
      origin: origin,
      chapters: chapters,
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Pinning', () {
    test('pinBook pins and getPinnedBooks returns pin order ascending',
        () async {
      await _seedBook(db, id: 'b1');
      await _seedBook(db, id: 'b2');
      await _seedBook(db, id: 'b3');

      await db.pinBook('b2');
      await db.pinBook('b1');
      await db.pinBook('b3');

      final pinned = await db.getPinnedBooks();
      expect(pinned.map((b) => b.id).toList(), equals(['b2', 'b1', 'b3']));
    });

    test('pinning the same book twice is a no-op, not an error', () async {
      await _seedBook(db, id: 'b1');
      await db.pinBook('b1');
      await db.pinBook('b1');

      final pinned = await db.getPinnedBooks();
      expect(pinned.length, equals(1));
    });

    test(
        'a 6th pin throws PinLimitExceededException and does not evict '
        'any existing pin', () async {
      for (var i = 0; i < 5; i++) {
        await _seedBook(db, id: 'b$i');
        await db.pinBook('b$i');
      }
      await _seedBook(db, id: 'b5');

      expect(
        () => db.pinBook('b5'),
        throwsA(isA<PinLimitExceededException>()),
      );

      final pinned = await db.getPinnedBooks();
      expect(pinned.length, equals(5));
      expect(pinned.map((b) => b.id), isNot(contains('b5')));
    });

    test('tryPinBook returns a typed result instead of throwing', () async {
      for (var i = 0; i < 5; i++) {
        await _seedBook(db, id: 'b$i');
        await db.pinBook('b$i');
      }
      await _seedBook(db, id: 'b5');

      final result = await db.tryPinBook('b5');
      expect(result, equals(PinResult.limitExceeded));

      final alreadyPinned = await db.tryPinBook('b0');
      expect(alreadyPinned, equals(PinResult.alreadyPinned));

      final notFound = await db.tryPinBook('does-not-exist');
      expect(notFound, equals(PinResult.notFound));
    });

    test('unpinBook removes the pin and frees a slot', () async {
      await _seedBook(db, id: 'b1');
      await db.pinBook('b1');
      await db.unpinBook('b1');

      final pinned = await db.getPinnedBooks();
      expect(pinned, isEmpty);

      // Slot is free again.
      await db.pinBook('b1');
      final pinnedAgain = await db.getPinnedBooks();
      expect(pinnedAgain.length, equals(1));
    });
  });

  group('Hidden-from-continue', () {
    test(
        'hiding a book removes it from continue-listening but keeps the '
        'book and its progress', () async {
      await _seedBook(db, id: 'b1');
      await db.saveProgress(
          audiobookId: 'b1', chapterIndex: 0, positionSeconds: 100);

      var continueList = await db.getContinueListening();
      expect(continueList.map((b) => b.id), contains('b1'));

      await db.hideFromContinue('b1');
      continueList = await db.getContinueListening();
      expect(continueList.map((b) => b.id), isNot(contains('b1')));

      // Book and progress both still exist.
      final book = await db.getAudiobook('b1');
      expect(book, isNotNull);
      final progress = await db.getProgress('b1');
      expect(progress, isNotNull);
      expect(progress!.positionSeconds, equals(100));

      await db.unhideFromContinue('b1');
      continueList = await db.getContinueListening();
      expect(continueList.map((b) => b.id), contains('b1'));
    });
  });

  group('User-supplied cover art', () {
    test('setUserCover takes precedence over the network cover', () async {
      await db.saveAudiobook(
        UnifiedAudiobook(
          id: 'b1',
          title: 'Book',
          author: 'Author',
          description: 'Desc',
          coverArtUrlOrPath: 'https://archive.org/services/img/b1',
        ),
      );

      var book = await db.getAudiobook('b1');
      expect(book!.coverArtUrlOrPath,
          equals('https://archive.org/services/img/b1'));

      await db.setUserCover('b1', '/local/path/to/cover.jpg');
      book = await db.getAudiobook('b1');
      expect(book!.coverArtUrlOrPath, equals('/local/path/to/cover.jpg'));

      await db.clearUserCover('b1');
      book = await db.getAudiobook('b1');
      expect(book!.coverArtUrlOrPath,
          equals('https://archive.org/services/img/b1'));
    });
  });

  group('Continue listening', () {
    test('excludes progress <= 30s', () async {
      await _seedBook(db, id: 'b1');
      await db.saveProgress(
          audiobookId: 'b1', chapterIndex: 0, positionSeconds: 30);

      final result = await db.getContinueListening();
      expect(result, isEmpty);
    });

    test('excludes books past 95% of known runtime', () async {
      await _seedBook(
        db,
        id: 'b1',
        chapters: [
          AudiobookChapter(
            id: 'b1_ch0',
            title: 'Ch 1',
            audioPathOrUrl: '/x.mp3',
            durationSeconds: 1000,
          ),
        ],
      );
      await db.saveProgress(
          audiobookId: 'b1', chapterIndex: 0, positionSeconds: 960); // 96%

      final result = await db.getContinueListening();
      expect(result, isEmpty);
    });

    test('includes books just under 95% of known runtime', () async {
      await _seedBook(
        db,
        id: 'b1',
        chapters: [
          AudiobookChapter(
            id: 'b1_ch0',
            title: 'Ch 1',
            audioPathOrUrl: '/x.mp3',
            durationSeconds: 1000,
          ),
        ],
      );
      await db.saveProgress(
          audiobookId: 'b1', chapterIndex: 0, positionSeconds: 900); // 90%

      final result = await db.getContinueListening();
      expect(result.map((b) => b.id), contains('b1'));
    });

    test(
        'unknown runtime (0): the 95% rule is skipped, book stays '
        'eligible for continue-listening', () async {
      // Local content whose durations were never probed — every chapter
      // reports durationSeconds == 0, so totalKnownRuntime == 0.
      await _seedBook(
        db,
        id: 'b1',
        chapters: [
          AudiobookChapter(
            id: 'b1_ch0',
            title: 'Ch 1',
            audioPathOrUrl: '/x.mp3',
            durationSeconds: 0,
          ),
        ],
      );
      await db.saveProgress(
          audiobookId: 'b1', chapterIndex: 0, positionSeconds: 5000);

      final result = await db.getContinueListening();
      expect(result.map((b) => b.id), contains('b1'));
    });

    test('most-recent-first ordering and a configurable limit', () async {
      await _seedBook(db, id: 'b1');
      await _seedBook(db, id: 'b2');
      await _seedBook(db, id: 'b3');

      final now = DateTime.now();
      await db.saveProgress(
        audiobookId: 'b1',
        chapterIndex: 0,
        positionSeconds: 100,
        updatedAt: now.subtract(const Duration(minutes: 10)),
      );
      await db.saveProgress(
        audiobookId: 'b2',
        chapterIndex: 0,
        positionSeconds: 100,
        updatedAt: now,
      );
      await db.saveProgress(
        audiobookId: 'b3',
        chapterIndex: 0,
        positionSeconds: 100,
        updatedAt: now.subtract(const Duration(minutes: 5)),
      );

      final result = await db.getContinueListening(limit: 2);
      expect(result.length, equals(2));
      expect(result.map((b) => b.id).toList(), equals(['b2', 'b3']));
    });
  });

  group('Bookmarks and clips', () {
    test('a point bookmark has a null endPositionSeconds', () async {
      await _seedBook(db, id: 'b1');
      await db.addBookmark(
        id: 'bm1',
        audiobookId: 'b1',
        chapterIndex: 0,
        positionSeconds: 120,
        note: 'A note',
      );

      final bookmarks = await db.getBookmarks('b1');
      expect(bookmarks.length, equals(1));
      expect(bookmarks.first.endPositionSeconds, isNull);
      expect(bookmarks.first.title, equals(''));

      final clips = await db.getClips('b1');
      expect(clips, isEmpty);
    });

    test(
        'a clip has a non-null endPositionSeconds and a title, and is '
        'returned by getClips', () async {
      await _seedBook(db, id: 'b1');
      await db.addBookmark(
        id: 'clip1',
        audiobookId: 'b1',
        chapterIndex: 0,
        positionSeconds: 100,
        endPositionSeconds: 130,
        title: 'Great quote',
        note: 'For the newsletter',
      );

      final clips = await db.getClips('b1');
      expect(clips.length, equals(1));
      expect(clips.first.endPositionSeconds, equals(130));
      expect(clips.first.title, equals('Great quote'));
      expect(clips.first.note, equals('For the newsletter'));
    });

    test('updateBookmark changes only the provided fields', () async {
      await _seedBook(db, id: 'b1');
      await db.addBookmark(
        id: 'bm1',
        audiobookId: 'b1',
        chapterIndex: 0,
        positionSeconds: 100,
        note: 'Original note',
        title: 'Original title',
      );

      await db.updateBookmark(id: 'bm1', title: 'New title');

      final bookmarks = await db.getBookmarks('b1');
      expect(bookmarks.first.title, equals('New title'));
      expect(bookmarks.first.note, equals('Original note'));
      expect(bookmarks.first.positionSeconds, equals(100));
    });

    test('deleteBookmark removes it', () async {
      await _seedBook(db, id: 'b1');
      await db.addBookmark(
        id: 'bm1',
        audiobookId: 'b1',
        chapterIndex: 0,
        positionSeconds: 100,
        note: 'Note',
      );
      await db.deleteBookmark('bm1');

      final bookmarks = await db.getBookmarks('b1');
      expect(bookmarks, isEmpty);
    });
  });

  group('Origin', () {
    test('saveAudiobook persists the origin field', () async {
      await _seedBook(db, id: 'b1', origin: 'librivox');
      final book = await db.getAudiobook('b1');
      expect(book!.origin, equals('librivox'));
    });
  });
}

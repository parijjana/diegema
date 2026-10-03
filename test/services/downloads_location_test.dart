import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/book_removal_io.dart';
import 'package:diegema/services/downloads_location_io.dart';
import 'package:diegema/services/library_locations_scanner_io.dart';
import 'package:diegema/services/library_locations_store.dart';
import 'package:diegema/services/local_library_scanner_io.dart';
import 'package:diegema/services/removed_books_store.dart';

void main() {
  late AppDatabase db;
  late Directory docs; // stands in for <application documents>
  late Directory music; // stands in for ~/Music or shared Audiobooks
  late DownloadsLocation location;
  late String private;
  late String visible;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    docs = await Directory.systemTemp.createTemp('docs');
    music = await Directory.systemTemp.createTemp('music');
    private = p.join(docs.path, 'diegema', 'downloads');
    visible = p.join(music.path, 'Diegema');
    location = DownloadsLocation(
        documentsRoot: () async => docs.path, visibleRoot: () async => visible);
  });

  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
    await music.delete(recursive: true);
  });

  String write(String path, [int bytes = 10]) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 1));
    return path;
  }

  UnifiedAudiobook book(String id, List<String> paths) => UnifiedAudiobook(
        id: id,
        title: id,
        author: 'A',
        description: '',
        source: 'Downloaded',
        origin: BookIdentity.originLibrivox,
        isDownloaded: true,
        chapters: [
          for (final (i, path) in paths.indexed)
            AudiobookChapter(
                id: '${id}_$i',
                title: 'c$i',
                audioPathOrUrl: path,
                durationSeconds: 0),
        ],
      );

  test('new downloads go to the visible folder; scans and removal see both',
      () async {
    expect(await location.current(), visible);
    expect(await location.all(), [visible, private]);

    final hidden = DownloadsLocation(
        documentsRoot: () async => docs.path, visibleRoot: () async => null);
    expect(await hidden.current(), private);
    expect(await hidden.all(), [private]);
  });

  test('existing downloads move once, with their progress, and stay unique',
      () async {
    final folder = p.join(private, 'Emma [emma_1]');
    write(p.join(folder, '01.mp3'), 30);
    write(p.join(folder, '02.mp3'), 20);
    write(p.join(folder, 'notes.txt'));
    await db.saveAudiobook(
        book('emma_1', [p.join(folder, '01.mp3'), p.join(folder, '02.mp3')]));
    await db.saveProgress(
        audiobookId: 'emma_1', chapterIndex: 1, positionSeconds: 42);

    expect(await moveDownloadsToVisibleFolder(db, location: location), 1);

    final dest = p.join(visible, 'Emma [emma_1]');
    final moved = (await db.getAudiobook('emma_1'))!;
    expect(moved.chapters.map((c) => c.audioPathOrUrl),
        [p.join(dest, '01.mp3'), p.join(dest, '02.mp3')]);
    expect(File(p.join(dest, '01.mp3')).lengthSync(), 30);
    expect(File(p.join(dest, 'notes.txt')).existsSync(), isFalse);
    expect(Directory(private).existsSync(), isFalse);
    expect((await db.getProgress('emma_1'))!.positionSeconds, 42);

    // Second launch: nothing left to move, and a scan adds no duplicate.
    expect(await moveDownloadsToVisibleFolder(db, location: location), 0);
    await scanDownloadedLibrary(db,
        downloads: location,
        locations: const LibraryLocationsStore(overrides: {}));
    expect(await db.getAllAudiobooks(), hasLength(1));
  });

  test('a scanned download is re-keyed to its new folder', () async {
    final folder = p.join(private, 'Odyssey');
    write(p.join(folder, '01.mp3'));
    final oldId = BookIdentity.localIdForPath(folder);
    await db.saveAudiobook(book(oldId, [p.join(folder, '01.mp3')]));

    await moveDownloadsToVisibleFolder(db, location: location);

    final newId = BookIdentity.localIdForPath(p.join(visible, 'Odyssey'));
    expect(await db.getAudiobook(oldId), isNull);
    expect(await db.getAudiobook(newId), isNotNull);
  });

  test('a folder that cannot be copied stays where it is', () async {
    final folder = p.join(private, 'Stuck');
    final mp3 = write(p.join(folder, '01.mp3'));
    await db.saveAudiobook(book('stuck', [mp3]));
    // A file where the destination folder should be: the copy must fail.
    write(p.join(visible, 'Stuck'));

    expect(await moveDownloadsToVisibleFolder(db, location: location), 0);
    expect(File(mp3).existsSync(), isTrue);
    expect(
        (await db.getAudiobook('stuck'))!.chapters.single.audioPathOrUrl, mp3);
  });

  test('no visible folder on this platform: nothing moves', () async {
    final mp3 = write(p.join(private, 'Keep', '01.mp3'));
    final hidden = DownloadsLocation(
        documentsRoot: () async => docs.path, visibleRoot: () async => null);
    expect(await moveDownloadsToVisibleFolder(db, location: hidden), 0);
    expect(File(mp3).existsSync(), isTrue);
  });

  test('the scan finds books in both roots', () async {
    write(p.join(private, 'Old', '01.mp3'));
    write(p.join(visible, 'New', '01.mp3'));
    await scanDownloadedLibrary(db,
        downloads: location,
        locations: const LibraryLocationsStore(overrides: {}));
    expect((await db.getAllAudiobooks()).map((b) => b.title).toSet(),
        {'Old', 'New'});
  });

  test('removing a book deletes its visible folder and nothing beside it',
      () async {
    final a = write(p.join(visible, 'Emma [1]', '01.mp3'), 100);
    final other = write(p.join(visible, 'Other [2]', '01.mp3'));
    final outside = write(p.join(music.path, 'Mine', '01.mp3'));
    final b = book('emma', [a]);
    await db.saveAudiobook(b);
    final hostile = book('hostile', [p.join(visible, '..', 'Mine', '01.mp3')]);
    await db.saveAudiobook(hostile);
    const removed = RemovedBooksStore(overrides: {});

    final freed = await removeBook(db, b,
        documentsPath: docs.path, downloads: location, removedStore: removed);
    await removeBook(db, hostile,
        documentsPath: docs.path, downloads: location, removedStore: removed);

    expect(freed, 100);
    expect(Directory(p.dirname(a)).existsSync(), isFalse);
    expect(File(other).existsSync(), isTrue);
    expect(File(outside).existsSync(), isTrue,
        reason: 'never delete outside a downloads root');
  });

  test(
      'a library folder that contains the downloads root does not import '
      'the downloads again, and an earlier duplicate is dropped', () async {
    SharedPreferences.setMockInitialValues({});
    final mp3 = write(p.join(visible, 'Emma [1]', '01.mp3'));
    await db.saveAudiobook(book('emma_1', [mp3]));
    // What the scan made before this fix: the same files as a folder book.
    final dupe = UnifiedAudiobook(
        id: 'local_dupe',
        title: 'Emma',
        author: 'A',
        description: '',
        source: kLibraryLocationSource,
        origin: BookIdentity.originLocal,
        chapters: [
          AudiobookChapter(
              id: 'd0', title: 'c0', audioPathOrUrl: mp3, durationSeconds: 0)
        ]);
    await db.saveAudiobook(dupe);
    write(p.join(music.path, 'Mine', '01.mp3'));

    await scanDownloadedLibrary(db,
        downloads: location,
        locations: LibraryLocationsStore(overrides: {
          'library_locations.v1': [music.path],
        }));

    final books = await db.getAllAudiobooks();
    expect(books.map((b) => b.id), isNot(contains('local_dupe')));
    expect(books.where((b) => b.chapters.first.audioPathOrUrl == mp3),
        hasLength(1));
    expect(books.map((b) => b.source), contains(kLibraryLocationSource),
        reason: 'the folder\'s own books are still read');
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/library_locations_scanner_io.dart';
import 'package:diegema/services/library_locations_store.dart';
import 'package:diegema/services/local_library_scanner.dart';

void main() {
  late AppDatabase db;
  late Directory location;
  late Map<String, List<String>> prefs;
  late LibraryLocationsStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    location = await Directory.systemTemp.createTemp('library_location');
    prefs = {};
    store = LibraryLocationsStore(overrides: prefs);
  });

  tearDown(() async {
    await db.close();
    if (await location.exists()) await location.delete(recursive: true);
  });

  String write(String relative) {
    final file = File(p.join(location.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [0]);
    return file.path;
  }

  /// Every path under the location with its size and mtime.
  Map<String, String> snapshot() => {
        for (final e in location.listSync(recursive: true))
          e.path: '${e.statSync().size}@${e.statSync().modified}',
      };

  test('a shelf of book folders becomes one book per folder, read in place',
      () async {
    final a1 = write('Austen/Emma/01.mp3');
    write('Austen/Emma/02.mp3');
    write('Homer/Odyssey/part1.mp3');
    write('Homer/Odyssey/cover.jpg');
    await store.add(location.path);

    expect(await scanLibraryLocations(db, store: store), 2);

    final books = await db.getAllAudiobooks();
    final emma = books.firstWhere((b) => b.title == 'Emma');
    expect(emma.id, BookIdentity.localIdForPath(p.dirname(a1)));
    expect(emma.source, kLibraryLocationSource);
    expect(emma.chapters.map((c) => c.audioPathOrUrl).first, a1,
        reason: 'chapters point at the original files, not a copy');
    final odyssey = books.firstWhere((b) => b.title == 'Odyssey');
    expect(odyssey.coverArtUrlOrPath,
        p.join(location.path, 'Homer', 'Odyssey', 'cover.jpg'));
  });

  test('a folder of several .m4b files gives one book per file', () async {
    write('Shelf/Emma.m4b');
    write('Shelf/Persuasion.m4b');

    expect(
        await scanLibraryLocations(db, store: store, only: location.path), 2);
    final titles = (await db.getAllAudiobooks()).map((b) => b.title).toSet();
    expect(titles, {'Emma', 'Persuasion'});
  });

  test('numbered .m4b parts of one book stay one book, titles trimmed',
      () async {
    for (final part in [
      '01 - Opening Credits',
      '02 - Dedication',
      '04 - Chapter 1'
    ]) {
      write('Desolation [152]/Desolation [152] - $part.m4b');
    }

    expect(
        await scanLibraryLocations(db, store: store, only: location.path), 1);
    final book = (await db.getAllAudiobooks()).single;
    expect(book.title, 'Desolation [152]');
    expect(book.chapters.map((c) => c.title),
        ['01 - Opening Credits', '02 - Dedication', '04 - Chapter 1']);
  });

  test('nothing in the location is created, changed or removed', () async {
    write('Book/01.mp3');
    write('Book/folder.jpg');
    await store.add(location.path);
    final before = snapshot();

    await scanLibraryLocations(db, store: store);
    await scanLibraryLocations(db, store: store);

    expect(snapshot(), before);
  });

  test('rescans add only new books', () async {
    write('One/01.mp3');
    await store.add(location.path);
    expect(await scanLibraryLocations(db, store: store), 1);
    expect(await scanLibraryLocations(db, store: store), 0);
    write('Two/01.mp3');
    expect(await scanLibraryLocations(db, store: store), 1);
  });

  test('hidden files and folders are skipped; missing locations are ignored',
      () async {
    write('.trash/Old/01.mp3');
    write('Book/._01.mp3');
    await store.add(location.path);
    await store.add(p.join(location.path, 'does-not-exist'));

    expect(await scanLibraryLocations(db, store: store), 0);
  });

  test('booksInLocation finds only that location\'s books', () async {
    write('Book/01.mp3');
    await store.add(location.path);
    await scanLibraryLocations(db, store: store);

    expect(await booksInLocation(db, location.path), hasLength(1));
    expect(await booksInLocation(db, p.join(location.path, 'Other')), isEmpty);
  });

  test('the Library refresh scans library locations too', () async {
    write('Book/01.mp3');
    await store.add(location.path);

    await scanDownloadedLibrary(db,
        documentsRoot: () async => null, locations: store);

    expect(await db.getAllAudiobooks(), hasLength(1));
  });

  test('the store keeps each location once and forgets removed ones', () async {
    expect(await store.add('/a'), isTrue);
    expect(await store.add('/a'), isFalse);
    await store.add('/b');
    await store.remove('/a');
    expect(await store.read(), ['/b']);
  });
}

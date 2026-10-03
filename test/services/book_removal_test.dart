import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/book_removal_io.dart';
import 'package:diegema/services/library_locations_scanner_io.dart';
import 'package:diegema/services/library_locations_store.dart';
import 'package:diegema/services/removed_books_store.dart';

void main() {
  late AppDatabase db;
  late Directory docs; // stands in for <application documents>
  late Directory outside; // user's own folder, outside the app
  late Map<String, List<String>> removedPrefs;
  late RemovedBooksStore removed;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    docs = await Directory.systemTemp.createTemp('docs');
    outside = await Directory.systemTemp.createTemp('outside');
    removedPrefs = {};
    removed = RemovedBooksStore(overrides: removedPrefs);
  });

  tearDown(() async {
    await db.close();
    for (final d in [docs, outside]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  });

  String write(Directory base, String relative, [int bytes = 10]) {
    final f = File(p.join(base.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 1));
    return f.path;
  }

  UnifiedAudiobook book(String id, List<String> paths,
      {String source = 'Downloaded', String? cover}) {
    return UnifiedAudiobook(
      id: id,
      title: id,
      author: 'A',
      description: '',
      source: source,
      origin: BookIdentity.originLocal,
      coverArtUrlOrPath: cover,
      chapters: [
        for (var i = 0; i < paths.length; i++)
          AudiobookChapter(
              id: '${id}_$i',
              title: 'c$i',
              audioPathOrUrl: paths[i],
              durationSeconds: 0),
      ],
    );
  }

  Future<UnifiedAudiobook> save(UnifiedAudiobook b) async {
    await db.saveAudiobook(b);
    await db.saveProgress(
        audiobookId: b.id, chapterIndex: 0, positionSeconds: 99);
    await db.addBookmark(
        id: 'bm_${b.id}',
        audiobookId: b.id,
        chapterIndex: 0,
        positionSeconds: 5,
        note: 'n');
    return b;
  }

  test('deletes a Discover download dir, its rows, progress and bookmarks',
      () async {
    final a = write(docs, 'diegema/downloads/Emma/01.mp3', 100);
    write(docs, 'diegema/downloads/Emma/02.mp3', 50);
    final other = write(docs, 'diegema/downloads/Other/01.mp3');
    final b = await save(book('emma', [a]));

    final freed = await removeBook(db, b,
        documentsPath: docs.path, removedStore: removed);

    expect(freed, 150);
    expect(Directory(p.dirname(a)).existsSync(), isFalse);
    expect(File(other).existsSync(), isTrue, reason: 'other books untouched');
    expect(Directory(p.join(docs.path, 'diegema', 'downloads')).existsSync(),
        isTrue);
    expect(await db.getAudiobook('emma'), isNull);
    expect(await db.getProgress('emma'), isNull);
    expect(await db.getBookmarks('emma'), isEmpty);
    expect(await removed.read(), isEmpty);
  });

  test('deletes a copied import dir and its cover', () async {
    final a = write(docs, 'diegema/library/loc_1/a.mp3', 40);
    final cover = write(docs, 'diegema/covers/loc_1.jpg', 7);
    final b = await save(book('loc_1', [a], cover: cover));

    final freed = await removeBook(db, b,
        documentsPath: docs.path, removedStore: removed);

    expect(freed, 47);
    expect(
        Directory(p.join(docs.path, 'diegema', 'library', 'loc_1'))
            .existsSync(),
        isFalse);
    expect(File(cover).existsSync(), isFalse);
  });

  test('library-folder book keeps its files, is hidden from rescans', () async {
    final a = write(outside, 'Austen/Emma/01.mp3');
    final cover = write(docs, 'diegema/covers/x.jpg', 3);
    final id = BookIdentity.localIdForPath(p.dirname(a));
    final b =
        await save(book(id, [a], source: kLibraryLocationSource, cover: cover));

    await removeBook(db, b, documentsPath: docs.path, removedStore: removed);

    expect(File(a).existsSync(), isTrue);
    expect(File(cover).existsSync(), isFalse, reason: 'app-owned cover goes');
    expect(await db.getAudiobook(id), isNull);
    expect(await removed.read(), {id});

    final locStore = LibraryLocationsStore(overrides: {
      'library_locations.v1': [outside.path]
    });
    expect(
        await scanLibraryLocations(db, store: locStore, removedStore: removed),
        0,
        reason: 'rescan must skip the removed book');
    expect(await db.getAudiobook(id), isNull);
  });

  test('never deletes outside the documents root, even if the DB says so',
      () async {
    final victim = write(outside, 'precious/song.mp3', 20);
    final victimCover = write(outside, 'cover.jpg');
    final traversal = p.join(docs.path, 'diegema', 'downloads', '..', '..',
        '..', p.basename(outside.path), 'precious', 'song.mp3');
    final b = await save(book('evil', [victim, traversal],
        source: 'Downloaded', cover: victimCover));
    // Hostile id too.
    final hostile =
        await save(book('../../${p.basename(outside.path)}', [victim]));

    final plan = await planBookRemoval(b, documentsPath: docs.path);
    expect(plan.deletePaths, isEmpty);

    await removeBook(db, b, documentsPath: docs.path, removedStore: removed);
    await removeBook(db, hostile,
        documentsPath: docs.path, removedStore: removed);

    expect(File(victim).existsSync(), isTrue);
    expect(File(victimCover).existsSync(), isTrue);
    expect(outside.existsSync(), isTrue);
    expect(await db.getAudiobook('evil'), isNull);
  });

  test('a path equal to a zone root is never deleted', () async {
    write(docs, 'diegema/downloads/Keep/01.mp3');
    final b = book('z', [p.join(docs.path, 'diegema', 'downloads')]);
    final plan = await planBookRemoval(b, documentsPath: docs.path);
    expect(plan.deletePaths, isEmpty);
  });

  test('stream chapters own no files', () async {
    final b = UnifiedAudiobook(
      id: 's',
      title: 's',
      author: 'a',
      description: '',
      source: 'LibriVox',
      chapters: [
        AudiobookChapter(
            id: 's0',
            title: 't',
            audioPathOrUrl: 'https://archive.org/x.mp3',
            durationSeconds: 1,
            isStream: true),
      ],
    );
    final plan = await planBookRemoval(b, documentsPath: docs.path);
    expect(plan.deletePaths, isEmpty);
    expect(plan.filesUntouched, isFalse);
  });
}

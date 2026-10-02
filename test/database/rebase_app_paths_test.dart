import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/app_paths.dart';
import 'package:diegema/services/local_library_scanner.dart';
import 'package:diegema/services/library_locations_store.dart';

void main() {
  late AppDatabase db;
  late Directory oldRoot;
  late Directory newRoot;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    oldRoot = await Directory.systemTemp.createTemp('old_container');
    newRoot = await Directory.systemTemp.createTemp('new_container');
  });

  tearDown(() async {
    await db.close();
    await oldRoot.delete(recursive: true);
    await newRoot.delete(recursive: true);
  });

  UnifiedAudiobook book(String id, List<String> paths,
          {String? cover, String origin = BookIdentity.originLocal}) =>
      UnifiedAudiobook(
        id: id,
        title: id,
        author: 'A',
        description: '',
        source: 'Local Storage',
        origin: origin,
        isDownloaded: true,
        coverArtUrlOrPath: cover,
        chapters: [
          for (final (i, path) in paths.indexed)
            AudiobookChapter(
                id: '${id}_ch_$i',
                title: 'c$i',
                audioPathOrUrl: path,
                durationSeconds: 0,
                isStream: path.startsWith('http')),
        ],
      );

  test(
      'a scanned download is rebased and re-keyed with its progress, '
      'and the next scan finds no duplicate', () async {
    final oldFolder = p.join(oldRoot.path, 'diegema', 'downloads', 'Odyssey');
    final oldId = BookIdentity.localIdForPath(oldFolder);
    await db.saveAudiobook(book(oldId, [p.join(oldFolder, '01.mp3')]));
    await db.saveProgress(
        audiobookId: oldId, chapterIndex: 0, positionSeconds: 42);
    await db.addBookmark(
        id: 'bm',
        audiobookId: oldId,
        chapterIndex: 0,
        positionSeconds: 10,
        note: 'n');

    expect(await db.rebaseAppPaths(oldRoot.path, newRoot.path), 1);

    final newFolder = p.join(newRoot.path, 'diegema', 'downloads', 'Odyssey');
    final newId = BookIdentity.localIdForPath(newFolder);
    expect(await db.getAudiobook(oldId), isNull);
    final moved = (await db.getAudiobook(newId))!;
    expect(moved.chapters.single.audioPathOrUrl, p.join(newFolder, '01.mp3'));
    expect((await db.getProgress(newId))!.positionSeconds, 42);
    expect(await db.getBookmarks(newId), hasLength(1));

    // The files really are in the new container: the scan must not add
    // the same folder again under another id.
    await File(p.join(newFolder, '01.mp3')).create(recursive: true);
    await scanDownloadedLibrary(db,
        documentsRoot: () async => newRoot.path,
        locations: LibraryLocationsStore(
            overrides: <String, List<String>>{}..clear()));
    expect(await db.getAllAudiobooks(), hasLength(1));
  });

  test(
      'other ids are kept; streams and paths outside the container are '
      'left alone; covers move', () async {
    final docs = oldRoot.path;
    await db.saveAudiobook(book(
      'odyssey_librivox',
      [
        p.join(docs, 'diegema', 'downloads', 'odyssey_librivox', '01.mp3'),
        'https://archive.org/download/x/02.mp3',
      ],
      cover: p.join(docs, 'diegema', 'covers', 'odyssey.jpg'),
      origin: BookIdentity.originLibrivox,
    ));
    await db.saveAudiobook(
        book('local_folderbook', ['/sdcard/Audiobooks/B/1.mp3']));

    expect(await db.rebaseAppPaths(docs, newRoot.path), 1);

    final lv = (await db.getAudiobook('odyssey_librivox'))!;
    expect(
        lv.chapters[0].audioPathOrUrl,
        p.join(newRoot.path, 'diegema', 'downloads', 'odyssey_librivox',
            '01.mp3'));
    expect(
        lv.chapters[1].audioPathOrUrl, 'https://archive.org/download/x/02.mp3');
    expect(lv.coverArtUrlOrPath,
        p.join(newRoot.path, 'diegema', 'covers', 'odyssey.jpg'));
    expect(
        (await db.getAudiobook('local_folderbook'))!
            .chapters
            .single
            .audioPathOrUrl,
        '/sdcard/Audiobooks/B/1.mp3');
  });

  test('a sibling folder sharing the prefix is not mistaken for the root',
      () async {
    await db.saveAudiobook(book('b', ['${oldRoot.path}-other/x.mp3']));
    expect(await db.rebaseAppPaths(oldRoot.path, newRoot.path), 0);
  });

  group('rebaseAppPathsIfMoved', () {
    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    test('first launch only records; a move rebases; same root is a no-op',
        () async {
      SharedPreferences.setMockInitialValues({});
      final path = p.join(oldRoot.path, 'a.mp3');
      await db.saveAudiobook(book('b', [path]));

      await rebaseAppPathsIfMoved(db,
          documentsRoot: () async => oldRoot.path, prefs: prefs);
      expect(
          (await db.getAudiobook('b'))!.chapters.single.audioPathOrUrl, path);

      await rebaseAppPathsIfMoved(db,
          documentsRoot: () async => newRoot.path, prefs: prefs);
      expect((await db.getAudiobook('b'))!.chapters.single.audioPathOrUrl,
          p.join(newRoot.path, 'a.mp3'));

      await rebaseAppPathsIfMoved(db,
          documentsRoot: () async => newRoot.path, prefs: prefs);
      expect((await db.getAudiobook('b'))!.chapters.single.audioPathOrUrl,
          p.join(newRoot.path, 'a.mp3'));
    });
  });
}

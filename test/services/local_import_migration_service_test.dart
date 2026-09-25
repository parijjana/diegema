import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/local_import_migration_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String docsPath;
  final String tempPath;
  _FakePathProviderPlatform({required this.docsPath, required this.tempPath});

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late Directory rootDir;
  late Directory docsDir;
  late Directory cacheDir;
  late AppDatabase db;

  setUp(() async {
    rootDir =
        await Directory.systemTemp.createTemp('local_import_migration_test_');
    docsDir = Directory(p.join(rootDir.path, 'docs'))..createSync();
    cacheDir = Directory(p.join(rootDir.path, 'cache'))..createSync();
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      docsPath: docsDir.path,
      tempPath: cacheDir.path,
    );
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  });

  String libraryPathFor(String bookId, [String? file]) => file == null
      ? p.join(docsDir.path, 'diegema', 'library', bookId)
      : p.join(docsDir.path, 'diegema', 'library', bookId, file);

  test('copies a cache-dir chapter file into the library dir and rewrites '
      'the chapter path', () async {
    final src = File(p.join(cacheDir.path, 'book.m4b'))
      ..writeAsBytesSync([1, 2, 3]);
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'book_1',
      title: 'Book',
      author: 'Author',
      description: '',
      origin: 'local',
      chapters: [
        AudiobookChapter(
          id: 'ch_01',
          title: 'One',
          audioPathOrUrl: src.path,
          durationSeconds: 100,
          startMs: 0,
          endMs: 5000,
        ),
      ],
    ));

    await LocalImportMigrationService(db: db).run();

    final updated = await db.getAudiobook('book_1');
    final chapter = updated!.chapters.single;
    expect(chapter.audioPathOrUrl, equals(libraryPathFor('book_1', 'book.m4b')));
    expect(File(chapter.audioPathOrUrl).readAsBytesSync(), equals([1, 2, 3]));
    expect(chapter.startMs, equals(0));
    expect(chapter.endMs, equals(5000));
    expect(chapter.id, equals('ch_01'));
  });

  test('two chapters sharing one M4B file are migrated to the same copy',
      () async {
    final src = File(p.join(cacheDir.path, 'book.m4b'))
      ..writeAsBytesSync([9, 9]);
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'book_2',
      title: 'Book',
      author: 'Author',
      description: '',
      origin: 'local',
      chapters: [
        AudiobookChapter(
          id: 'ch_01',
          title: 'One',
          audioPathOrUrl: src.path,
          durationSeconds: 100,
          startMs: 0,
          endMs: 5000,
        ),
        AudiobookChapter(
          id: 'ch_02',
          title: 'Two',
          audioPathOrUrl: src.path,
          durationSeconds: 100,
          startMs: 5000,
          endMs: 10000,
        ),
      ],
    ));

    await LocalImportMigrationService(db: db).run();

    final updated = await db.getAudiobook('book_2');
    final paths = updated!.chapters.map((c) => c.audioPathOrUrl).toSet();
    expect(paths, hasLength(1));
    expect(paths.single, equals(libraryPathFor('book_2', 'book.m4b')));
  });

  test('leaves a row alone when the chapter file no longer exists',
      () async {
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'book_3',
      title: 'Book',
      author: 'Author',
      description: '',
      origin: 'local',
      chapters: [
        AudiobookChapter(
          id: 'ch_01',
          title: 'One',
          audioPathOrUrl: p.join(cacheDir.path, 'gone.mp3'),
          durationSeconds: 100,
        ),
      ],
    ));

    await LocalImportMigrationService(db: db).run();

    final updated = await db.getAudiobook('book_3');
    expect(updated!.chapters.single.audioPathOrUrl,
        equals(p.join(cacheDir.path, 'gone.mp3')));
  });

  test('a chapter already under diegema/library is left untouched',
      () async {
    final durableDir = Directory(libraryPathFor('book_4'))
      ..createSync(recursive: true);
    final already = File(p.join(durableDir.path, 'book.mp3'))
      ..writeAsBytesSync([1]);
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'book_4',
      title: 'Book',
      author: 'Author',
      description: '',
      origin: 'local',
      chapters: [
        AudiobookChapter(
          id: 'ch_01',
          title: 'One',
          audioPathOrUrl: already.path,
          durationSeconds: 100,
        ),
      ],
    ));

    await LocalImportMigrationService(db: db).run();

    final updated = await db.getAudiobook('book_4');
    expect(updated!.chapters.single.audioPathOrUrl, equals(already.path));
  });

  test('skips non-local (librivox) origin books', () async {
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'lv_1',
      title: 'A LibriVox Book',
      author: 'Someone',
      description: '',
      origin: 'librivox',
      chapters: [
        AudiobookChapter(
          id: 'ch_01',
          title: 'One',
          audioPathOrUrl: 'https://archive.org/download/x/1.mp3',
          durationSeconds: 100,
        ),
      ],
    ));

    await LocalImportMigrationService(db: db).run();

    final updated = await db.getAudiobook('lv_1');
    expect(updated!.chapters.single.audioPathOrUrl,
        equals('https://archive.org/download/x/1.mp3'));
  });

  test('a filename collision with an already-migrated file gets a suffix',
      () async {
    final durableDir = Directory(libraryPathFor('book_5'))
      ..createSync(recursive: true);
    File(p.join(durableDir.path, 'book.mp3')).writeAsBytesSync([1]);

    final src = File(p.join(cacheDir.path, 'book.mp3'))
      ..writeAsBytesSync([2]);
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'book_5',
      title: 'Book',
      author: 'Author',
      description: '',
      origin: 'local',
      chapters: [
        AudiobookChapter(
          id: 'ch_01',
          title: 'One',
          audioPathOrUrl: src.path,
          durationSeconds: 100,
        ),
      ],
    ));

    await LocalImportMigrationService(db: db).run();

    final updated = await db.getAudiobook('book_5');
    final newPath = updated!.chapters.single.audioPathOrUrl;
    expect(newPath, equals(libraryPathFor('book_5', 'book_2.mp3')));
    expect(File(newPath).readAsBytesSync(), equals([2]));
  });
}

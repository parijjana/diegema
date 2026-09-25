import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:diegema/services/local_audiobook_storage_io.dart';

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
  late Directory outsideDir;

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp('local_audiobook_storage_test_');
    docsDir = Directory(p.join(rootDir.path, 'docs'))..createSync();
    cacheDir = Directory(p.join(rootDir.path, 'cache'))..createSync();
    outsideDir = Directory(p.join(rootDir.path, 'sdcard'))..createSync();
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      docsPath: docsDir.path,
      tempPath: cacheDir.path,
    );
  });

  tearDown(() async {
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  });

  String libraryPathFor(String bookId) =>
      p.join(docsDir.path, 'diegema', 'library', bookId);

  test('copies a cache original into the library dir and deletes the source',
      () async {
    final src = File(p.join(cacheDir.path, 'book.m4b'))
      ..writeAsBytesSync([1, 2, 3, 4, 5]);

    final result = await copyIntoLibrary(bookId: 'book_1', audioPaths: [src.path]);

    final newPath = result.audioPaths[src.path]!;
    expect(newPath, equals(p.join(libraryPathFor('book_1'), 'book.m4b')));
    expect(File(newPath).readAsBytesSync(), equals([1, 2, 3, 4, 5]));
    expect(await src.exists(), isFalse);
  });

  test('keeps an original that lives outside the cache dir', () async {
    final src = File(p.join(outsideDir.path, 'book.mp3'))
      ..writeAsBytesSync([9, 9, 9]);

    final result = await copyIntoLibrary(bookId: 'book_2', audioPaths: [src.path]);

    final newPath = result.audioPaths[src.path]!;
    expect(File(newPath).readAsBytesSync(), equals([9, 9, 9]));
    expect(await src.exists(), isTrue);
  });

  test('a filename collision within one book gets a numeric suffix',
      () async {
    final srcA = File(p.join(cacheDir.path, 'a', 'track.mp3'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    final srcB = File(p.join(cacheDir.path, 'b', 'track.mp3'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([2]);

    final result = await copyIntoLibrary(
        bookId: 'book_3', audioPaths: [srcA.path, srcB.path]);

    final pathA = result.audioPaths[srcA.path]!;
    final pathB = result.audioPaths[srcB.path]!;
    expect(pathA, isNot(equals(pathB)));
    expect(p.basename(pathA), equals('track.mp3'));
    expect(p.basename(pathB), equals('track_2.mp3'));
    expect(File(pathA).readAsBytesSync(), equals([1]));
    expect(File(pathB).readAsBytesSync(), equals([2]));
  });

  test('also copies and cache-cleans a folder cover image', () async {
    final audio = File(p.join(cacheDir.path, 'book.mp3'))
      ..writeAsBytesSync([1]);
    final cover = File(p.join(cacheDir.path, 'cover.jpg'))
      ..writeAsBytesSync([0xFF, 0xD8]);

    final result = await copyIntoLibrary(
      bookId: 'book_4',
      audioPaths: [audio.path],
      coverPath: cover.path,
    );

    expect(result.coverPath, isNotNull);
    expect(File(result.coverPath!).readAsBytesSync(), equals([0xFF, 0xD8]));
    expect(await cover.exists(), isFalse);
  });

  test('a failure partway through removes the partial library dir',
      () async {
    final goodSrc = File(p.join(cacheDir.path, 'good.mp3'))
      ..writeAsBytesSync([1, 2, 3]);
    final missingSrc = p.join(cacheDir.path, 'does_not_exist.mp3');

    await expectLater(
      copyIntoLibrary(
          bookId: 'book_5', audioPaths: [goodSrc.path, missingSrc]),
      throwsA(anything),
    );

    expect(await Directory(libraryPathFor('book_5')).exists(), isFalse);
  });
}

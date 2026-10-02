import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:diegema/services/local_book_metadata_io.dart';

import '../support/mp4_builder.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('local_book_metadata_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> writeFixture(String name, List<int> bytes) async {
    final path = p.join(tempDir.path, name);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  test('readEmbeddedMetadataForFiles picks the first file with metadata',
      () async {
    final noTags = await writeFixture('no_tags.mp3', [0xFF, 0xFB, 0, 0]);
    final tagged = await writeFixture(
      'tagged.m4b',
      buildM4bWithMetadata(album: 'Found Title', artist: 'Found Author'),
    );

    final result = await readEmbeddedMetadataForFiles([noTags, tagged]);

    expect(result, isNotNull);
    expect(result!.title, equals('Found Title'));
    expect(result.author, equals('Found Author'));
  });

  test('readEmbeddedMetadataForFiles returns null when nothing has tags',
      () async {
    final noTags = await writeFixture('no_tags.mp3', [0xFF, 0xFB, 0, 0]);
    final noTags2 = await writeFixture('no_chapters.m4b', buildNoChaptersM4b());

    final result = await readEmbeddedMetadataForFiles([noTags, noTags2]);

    expect(result, isNull);
  });

  test('saveCoverBytes writes to <appDocs>/diegema/covers/<id>.jpg', () async {
    final jpeg = syntheticJpegBytes();

    final savedPath = await saveCoverBytes(jpeg, 'image/jpeg', 'book_123');

    expect(savedPath, isNotNull);
    expect(savedPath, contains(p.join('diegema', 'covers')));
    expect(savedPath, endsWith('book_123.jpg'));
    final bytes = await File(savedPath!).readAsBytes();
    expect(bytes, equals(jpeg));
  });

  test('saveCoverBytes uses .png for image/png', () async {
    final png = syntheticPngBytes();

    final savedPath = await saveCoverBytes(png, 'image/png', 'book_456');

    expect(savedPath, endsWith('book_456.png'));
  });

  group('findFolderCoverImage', () {
    test('prefers a file named cover/folder/front/albumart, case-insensitive',
        () async {
      await writeFixture('track1.mp3', [0]);
      await writeFixture('random.jpg', [1]);
      await writeFixture('Cover.PNG', [2]);

      final found = await findFolderCoverImage(tempDir.path);

      expect(found, equals(p.join(tempDir.path, 'Cover.PNG')));
    });

    test('falls back to the sole image file in the folder', () async {
      await writeFixture('track1.mp3', [0]);
      await writeFixture('art.jpeg', [1]);

      final found = await findFolderCoverImage(tempDir.path);

      expect(found, equals(p.join(tempDir.path, 'art.jpeg')));
    });

    test('returns null with multiple unnamed images and no match', () async {
      await writeFixture('one.jpg', [0]);
      await writeFixture('two.png', [1]);

      final found = await findFolderCoverImage(tempDir.path);

      expect(found, isNull);
    });

    test('returns null when there is no image file at all', () async {
      await writeFixture('track1.mp3', [0]);

      final found = await findFolderCoverImage(tempDir.path);

      expect(found, isNull);
    });

    test('returns null for a nonexistent folder', () async {
      final found = await findFolderCoverImage(p.join(tempDir.path, 'missing'));

      expect(found, isNull);
    });
  });

  group('findFolderCoverImageForFiles', () {
    test('checks each distinct parent folder and returns the first hit',
        () async {
      final subA = Directory(p.join(tempDir.path, 'a'))..createSync();
      final subB = Directory(p.join(tempDir.path, 'b'))..createSync();
      final fileA = p.join(subA.path, 'track.mp3');
      File(fileA).writeAsBytesSync([0]);
      final coverB = p.join(subB.path, 'folder.jpg');
      File(coverB).writeAsBytesSync([1]);
      final fileB = p.join(subB.path, 'track.mp3');
      File(fileB).writeAsBytesSync([0]);

      final found = await findFolderCoverImageForFiles([fileA, fileB]);

      expect(found, equals(coverB));
    });
  });
}

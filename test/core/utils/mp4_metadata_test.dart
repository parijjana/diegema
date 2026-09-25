import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/mp4_metadata.dart';

import '../../support/mp4_builder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mp4_metadata_test_');
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

  test('reads a JPEG cover and title/author tags', () async {
    final jpeg = syntheticJpegBytes();
    final path = await writeFixture(
      'book.m4b',
      buildM4bWithMetadata(
        name: 'Chapter One',
        album: 'The Odyssey for Boys and Girls',
        artist: 'Some Narrator',
        albumArtist: 'Alfred J. Church',
        coverBytes: jpeg,
      ),
    );

    final result = await readMp4Metadata(path);

    expect(result, isNotNull);
    expect(result!.title, equals('The Odyssey for Boys and Girls'));
    expect(result.author, equals('Alfred J. Church'));
    expect(result.coverMime, equals('image/jpeg'));
    expect(result.coverBytes, equals(jpeg));
  });

  test('reads a PNG cover via explicit type code', () async {
    final png = syntheticPngBytes();
    final path = await writeFixture(
      'book.m4b',
      buildM4bWithMetadata(album: 'Alb', coverBytes: png, coverTypeCode: 14),
    );

    final result = await readMp4Metadata(path);

    expect(result!.coverMime, equals('image/png'));
    expect(result.coverBytes, equals(png));
  });

  test('sniffs cover type when the type code is 0', () async {
    final png = syntheticPngBytes();
    final path = await writeFixture(
      'book.m4b',
      buildM4bWithMetadata(album: 'Alb', coverBytes: png, coverTypeCode: 0),
    );

    final result = await readMp4Metadata(path);

    expect(result!.coverMime, equals('image/png'));
  });

  test('falls back to ©nam/©ART when ©alb/aART are absent', () async {
    final path = await writeFixture(
      'book.m4b',
      buildM4bWithMetadata(name: 'Just A Title', artist: 'Just An Artist'),
    );

    final result = await readMp4Metadata(path);

    expect(result!.title, equals('Just A Title'));
    expect(result.author, equals('Just An Artist'));
    expect(result.coverBytes, isNull);
  });

  test('reads meta when it sits directly under moov (no udta)', () async {
    final path = await writeFixture(
      'book.m4b',
      buildM4bWithMetadata(
        album: 'Direct Meta',
        metaUnderMoovDirectly: true,
      ),
    );

    final result = await readMp4Metadata(path);

    expect(result!.title, equals('Direct Meta'));
  });

  test('returns null for a file with no metadata at all', () async {
    final path = await writeFixture('book.m4b', buildNoChaptersM4b());

    final result = await readMp4Metadata(path);

    expect(result, isNull);
  });

  test('returns null for a nonexistent file', () async {
    final result =
        await readMp4Metadata(p.join(tempDir.path, 'missing.m4b'));

    expect(result, isNull);
  });

  test('returns null for a truncated/malformed file', () async {
    final path = await writeFixture('junk.m4b', [1, 2, 3, 4, 5]);

    final result = await readMp4Metadata(path);

    expect(result, isNull);
  });
}

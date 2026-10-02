import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/id3_metadata.dart';

import '../../support/id3_builder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('id3_metadata_test_');
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

  test('reads APIC cover and TALB/TPE2 tags (id3v2.3)', () async {
    final jpeg = syntheticJpegBytes();
    final path = await writeFixture(
      'book.mp3',
      buildMp3WithId3([
        textFrameV3('TIT2', 'Chapter One'),
        textFrameV3('TALB', 'The Odyssey for Boys and Girls'),
        textFrameV3('TPE1', 'Some Narrator'),
        textFrameV3('TPE2', 'Alfred J. Church'),
        apicFrame(jpeg),
      ], majorVersion: 3),
    );

    final result = await readId3Metadata(path);

    expect(result, isNotNull);
    expect(result!.title, equals('The Odyssey for Boys and Girls'));
    expect(result.author, equals('Alfred J. Church'));
    expect(result.coverMime, equals('image/jpeg'));
    expect(result.coverBytes, equals(jpeg));
  });

  test('reads APIC and text frames with id3v2.4 syncsafe frame sizes',
      () async {
    final jpeg = syntheticJpegBytes();
    final path = await writeFixture(
      'book.mp3',
      buildMp3WithId3([
        textFrameV3('TALB', 'V4 Title', majorVersion: 4),
        apicFrame(jpeg, majorVersion: 4),
      ], majorVersion: 4),
    );

    final result = await readId3Metadata(path);

    expect(result!.title, equals('V4 Title'));
    expect(result.coverBytes, equals(jpeg));
  });

  test('reads v2.2 PIC and 3-char frame ids', () async {
    final jpeg = syntheticJpegBytes();
    final path = await writeFixture(
      'book.mp3',
      buildMp3WithId3([
        textFrameV2('TAL', 'V2 Title'),
        textFrameV2('TP2', 'V2 Album Artist'),
        picFrameV2(jpeg, format: 'JPG'),
      ], majorVersion: 2),
    );

    final result = await readId3Metadata(path);

    expect(result!.title, equals('V2 Title'));
    expect(result.author, equals('V2 Album Artist'));
    expect(result.coverBytes, equals(jpeg));
  });

  test('falls back to TIT2/TPE1 when TALB/TPE2 are absent', () async {
    final path = await writeFixture(
      'book.mp3',
      buildMp3WithId3([
        textFrameV3('TIT2', 'Just A Title'),
        textFrameV3('TPE1', 'Just An Artist'),
      ]),
    );

    final result = await readId3Metadata(path);

    expect(result!.title, equals('Just A Title'));
    expect(result.author, equals('Just An Artist'));
    expect(result.coverBytes, isNull);
  });

  test('returns null when the file has no ID3 header', () async {
    final path = await writeFixture('plain.mp3', [0xFF, 0xFB, 0, 0, 0, 0]);

    final result = await readId3Metadata(path);

    expect(result, isNull);
  });

  test('returns null for a nonexistent file', () async {
    final result = await readId3Metadata(p.join(tempDir.path, 'missing.mp3'));

    expect(result, isNull);
  });

  test('returns null for a truncated/malformed file', () async {
    final path = await writeFixture('junk.mp3', [0x49, 0x44, 0x33, 3]);

    final result = await readId3Metadata(path);

    expect(result, isNull);
  });
}

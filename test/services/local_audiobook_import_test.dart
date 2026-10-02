import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/services/local_audiobook_import_io.dart';

import '../support/mp4_builder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chapters_for_files_test_');
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

  test('an m4b with chapter markers expands into one chapter per marker',
      () async {
    const chapters = [
      ChapterFixture('Intro', 0),
      ChapterFixture('Part One', 10000),
      ChapterFixture('Part Two', 25000),
    ];
    final path = await writeFixture(
      'book.m4b',
      buildQuickTimeChapterM4b(chapters: chapters, audioDurationMs: 40000),
    );

    final result = await chaptersForFiles('book_id', [path]);

    expect(result, hasLength(3));
    expect(
        result.map((c) => c.title), equals(['Intro', 'Part One', 'Part Two']));
    expect(result.map((c) => c.startMs), equals([0, 10000, 25000]));
    expect(result.map((c) => c.endMs), equals([10000, 25000, 40000]));
    expect(result.map((c) => c.durationSeconds), equals([10, 15, 15]));
    expect(result.map((c) => c.audioPathOrUrl), everyElement(equals(path)));
    expect(result.map((c) => c.id),
        equals(['book_id_ch_0', 'book_id_ch_1', 'book_id_ch_2']));
  });

  test('a blank marker title falls back to "Chapter N"', () async {
    const chapters = [
      ChapterFixture('', 0),
      ChapterFixture('Named', 5000),
    ];
    final path = await writeFixture(
      'blank_titles.m4b',
      buildQuickTimeChapterM4b(chapters: chapters, audioDurationMs: 10000),
    );

    final result = await chaptersForFiles('book_id', [path]);

    expect(result.map((c) => c.title), equals(['Chapter 1', 'Named']));
  });

  test('an m4b without chapter markers becomes a single whole-file chapter',
      () async {
    final path = await writeFixture(
      'no_chapters.m4b',
      buildNoChaptersM4b(audioDurationMs: 30000),
    );

    final result = await chaptersForFiles('book_id', [path]);

    expect(result, hasLength(1));
    expect(result.single.title, equals('no_chapters'));
    expect(result.single.startMs, isNull);
    expect(result.single.endMs, isNull);
    expect(result.single.durationSeconds, equals(0));
    expect(result.single.id, equals('book_id_ch_0'));
  });

  test('an mp3 and a chaptered m4b mix, with ids numbered continuously',
      () async {
    final mp3Path = await writeFixture('track.mp3', [0, 1, 2, 3]);
    const chapters = [
      ChapterFixture('A', 0),
      ChapterFixture('B', 5000),
    ];
    final m4bPath = await writeFixture(
      'book.m4b',
      buildQuickTimeChapterM4b(chapters: chapters, audioDurationMs: 10000),
    );

    final result = await chaptersForFiles('book_id', [mp3Path, m4bPath]);

    expect(result, hasLength(3));
    expect(result[0].title, equals('track'));
    expect(result[0].audioPathOrUrl, equals(mp3Path));
    expect(result[0].startMs, isNull);
    expect(result[1].title, equals('A'));
    expect(result[1].audioPathOrUrl, equals(m4bPath));
    expect(result[1].startMs, equals(0));
    expect(result[2].title, equals('B'));
    expect(result[2].startMs, equals(5000));
    expect(result.map((c) => c.id),
        equals(['book_id_ch_0', 'book_id_ch_1', 'book_id_ch_2']));
  });

  test('a single embedded chapter marker does not expand (needs 2+)', () async {
    const chapters = [ChapterFixture('Only One', 0)];
    final path = await writeFixture(
      'single_marker.m4b',
      buildQuickTimeChapterM4b(chapters: chapters, audioDurationMs: 20000),
    );

    final result = await chaptersForFiles('book_id', [path]);

    expect(result, hasLength(1));
    expect(result.single.title, equals('single_marker'));
    expect(result.single.startMs, isNull);
  });
}

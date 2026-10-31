import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/mp4_chapters.dart';

import '../../support/mp4_builder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mp4_chapters_test_');
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

  group('chpl only', () {
    test('reads Nero chpl chapters and mvhd duration', () async {
      const chapters = [
        ChapterFixture('Chapter One', 0),
        ChapterFixture('Chapter Two', 15000),
        ChapterFixture('Chapter Three', 42000),
      ];
      final path = await writeFixture(
        'chpl_only.m4b',
        buildChplOnlyM4b(chapters: chapters, audioDurationMs: 60000),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNotNull);
      expect(result!.durationMs, equals(60000));
      expect(result.chapters.map((c) => c.title),
          equals(['Chapter One', 'Chapter Two', 'Chapter Three']));
      expect(result.chapters.map((c) => c.startMs), equals([0, 15000, 42000]));
    });

    test('handles a 64-bit extended atom size', () async {
      const chapters = [
        ChapterFixture('Only Chapter', 0),
      ];
      final path = await writeFixture(
        'chpl_64bit.m4b',
        buildChplOnlyM4b(
          chapters: chapters,
          audioDurationMs: 5000,
          use64BitMoov: true,
        ),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNotNull);
      expect(result!.durationMs, equals(5000));
      expect(result.chapters, hasLength(1));
      expect(result.chapters.single.title, equals('Only Chapter'));
    });
  });

  group('QuickTime chapter track', () {
    test('reads chapters via tref/chap, preferring exact stts timing',
        () async {
      const chapters = [
        ChapterFixture('Intro', 0),
        ChapterFixture('Part One', 12345),
        ChapterFixture('Part Two', 98765),
      ];
      final path = await writeFixture(
        'qt_chapters.m4b',
        buildQuickTimeChapterM4b(
          chapters: chapters,
          audioDurationMs: 120000,
        ),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNotNull);
      expect(result!.durationMs, equals(120000));
      expect(result.chapters.map((c) => c.title),
          equals(['Intro', 'Part One', 'Part Two']));
      expect(result.chapters.map((c) => c.startMs), equals([0, 12345, 98765]));
    });

    test('reads UTF-16 (BOM-prefixed) titles', () async {
      const chapters = [
        ChapterFixture('Café', 0),
        ChapterFixture('日本語', 30000),
      ];
      final path = await writeFixture(
        'qt_utf16.m4b',
        buildQuickTimeChapterM4b(
          chapters: chapters,
          audioDurationMs: 60000,
          utf16Titles: true,
        ),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNotNull);
      expect(result!.chapters.map((c) => c.title), equals(['Café', '日本語']));
    });

    test('accepts an sbtl handler type as well as text', () async {
      const chapters = [ChapterFixture('Only', 0)];
      final path = await writeFixture(
        'qt_sbtl.m4b',
        buildQuickTimeChapterM4b(
          chapters: chapters,
          audioDurationMs: 5000,
          chapterHandlerType: 'sbtl',
        ),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNotNull);
      expect(result!.chapters.single.title, equals('Only'));
    });
  });

  group('both formats present', () {
    test('prefers the QuickTime track over chpl', () async {
      const qtChapters = [
        ChapterFixture('QT Chapter A', 0),
        ChapterFixture('QT Chapter B', 20000),
      ];
      const chplChapters = [
        ChapterFixture('CHPL Chapter A', 0),
        ChapterFixture('CHPL Chapter B', 25000),
      ];
      final path = await writeFixture(
        'both.m4b',
        buildQuickTimeChapterM4b(
          chapters: qtChapters,
          audioDurationMs: 40000,
          alsoChpl: chplChapters,
        ),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNotNull);
      expect(result!.chapters.map((c) => c.title),
          equals(['QT Chapter A', 'QT Chapter B']));
    });
  });

  group('no chapters / malformed input', () {
    test('returns null for a well-formed M4B with no chapter data', () async {
      final path = await writeFixture(
        'no_chapters.m4b',
        buildNoChaptersM4b(audioDurationMs: 30000),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNull);
    });

    test('returns null, not a throw, for a truncated file', () async {
      final full = buildChplOnlyM4b(
        chapters: const [ChapterFixture('X', 0)],
        audioDurationMs: 10000,
      );
      // Cut it off partway through the moov atom.
      final truncated = full.sublist(0, full.length - 10);
      final path = await writeFixture('truncated.m4b', truncated);

      expect(() async => readMp4Chapters(path), returnsNormally);
      final result = await readMp4Chapters(path);
      expect(result, isNull);
    });

    test('returns null, not a throw, for a non-MP4 file', () async {
      final path = await writeFixture(
        'not_mp4.txt',
        Uint8List.fromList('this is not an mp4 file at all'.codeUnits),
      );

      final result = await readMp4Chapters(path);

      expect(result, isNull);
    });

    test('returns null for a nonexistent path rather than throwing', () async {
      final path = p.join(tempDir.path, 'does_not_exist.m4b');

      final result = await readMp4Chapters(path);

      expect(result, isNull);
    });
  });

  group('malformed files are bounded, never a hang or crash', () {
    Uint8List valid() => buildQuickTimeChapterM4b(chapters: const [
          ChapterFixture('One', 0),
          ChapterFixture('Two', 10000),
          ChapterFixture('Three', 20000),
        ]);

    int indexOfType(Uint8List bytes, String type) {
      final needle = type.codeUnits;
      for (var i = 4; i + 4 <= bytes.length; i++) {
        var hit = true;
        for (var j = 0; j < 4; j++) {
          if (bytes[i + j] != needle[j]) {
            hit = false;
            break;
          }
        }
        if (hit) return i;
      }
      throw StateError('no $type atom');
    }

    void putU32(Uint8List bytes, int at, int v) =>
        ByteData.sublistView(bytes).setUint32(at, v, Endian.big);

    Future<Mp4Chapters?> readQuickly(Uint8List bytes) async {
      final path = await writeFixture('bad.m4b', bytes);
      return readMp4Chapters(path).timeout(const Duration(seconds: 10));
    }

    test('the unmodified fixture still reads', () async {
      final result = await readQuickly(valid());
      expect(result!.chapters.map((c) => c.title), ['One', 'Two', 'Three']);
    });

    test('stts claiming millions of samples is rejected', () async {
      final bytes = valid();
      final at = indexOfType(bytes, 'stts');
      putU32(bytes, at + 12, 4000000); // first run's sample_count
      expect(await readQuickly(bytes), isNull);
    });

    test('stts claiming billions of runs is rejected', () async {
      final bytes = valid();
      putU32(bytes, indexOfType(bytes, 'stts') + 8, 0xFFFFFFFF);
      expect(await readQuickly(bytes), isNull);
    });

    test('stsz claiming a huge sample count is rejected', () async {
      final bytes = valid();
      putU32(bytes, indexOfType(bytes, 'stsz') + 12, 0xFFFFFFFF);
      expect(await readQuickly(bytes), isNull);
    });

    test('stsz fixed-size form with a huge count is rejected', () async {
      final bytes = valid();
      final at = indexOfType(bytes, 'stsz');
      putU32(bytes, at + 8, 7); // sample_size != 0
      putU32(bytes, at + 12, 3000000);
      expect(await readQuickly(bytes), isNull);
    });

    test('stco claiming more offsets than it holds is rejected', () async {
      final bytes = valid();
      putU32(bytes, indexOfType(bytes, 'stco') + 8, 0x7FFFFFFF);
      expect(await readQuickly(bytes), isNull);
    });

    test('stsc entry count larger than the atom is rejected', () async {
      final bytes = valid();
      putU32(bytes, indexOfType(bytes, 'stsc') + 8, 0x7FFFFFFF);
      expect(await readQuickly(bytes), isNull);
    });

    test('a flood of tiny atoms stops at the cap', () async {
      final flood = <int>[for (var i = 0; i < 20000; i++) ...atom('free', [])];
      final bytes = Uint8List.fromList([
        ...ftyp(),
        ...container(
            'moov', [flood, mvhd(timescale: 1000, durationTicks: 1000)])
      ]);
      expect(await readQuickly(bytes), isNull);
    });

    test('truncated, zero-filled and random files read as no chapters',
        () async {
      final good = valid();
      expect(await readQuickly(Uint8List.sublistView(good, 0, 90)), isNull);
      expect(await readQuickly(Uint8List(4096)), isNull);
      expect(
          await readQuickly(
              Uint8List.fromList(List.generate(5000, (i) => (i * 37) & 0xFF))),
          isNull);
    });

    test('a scan with a bad file beside a good one keeps the good one',
        () async {
      final bad = valid();
      putU32(bad, indexOfType(bad, 'stts') + 12, 4000000);
      final badPath = await writeFixture('a_bad.m4b', bad);
      final goodPath = await writeFixture('b_good.m4b', valid());
      expect(await readMp4Chapters(badPath), isNull);
      expect((await readMp4Chapters(goodPath))!.chapters, hasLength(3));
    });
  });
}

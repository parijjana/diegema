import 'package:diegema/core/utils/chapter_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prettifyChapterTitle', () {
    test('turns a LibriVox file name into Part N', () {
      expect(prettifyChapterTitle('3sfstoriesbywilliamtenn_01_tenn_64kb'),
          'Part 1');
      expect(prettifyChapterTitle('3sfstoriesbywilliamtenn_12_tenn_64kb'),
          'Part 12');
    });

    test('uses Chapter N when the name says chapter', () {
      expect(prettifyChapterTitle('chapter_03_64kb'), 'Chapter 3');
      expect(prettifyChapterTitle('frankenstein_ch_07.mp3'), 'Chapter 7');
    });

    test('strips extension and bitrate', () {
      expect(prettifyChapterTitle('emma_02_austen.mp3'), 'Part 2');
      expect(prettifyChapterTitle('track_5_128kbps'), 'Part 5');
    });

    test('falls back to the index, then to spaces, when there is no number',
        () {
      expect(prettifyChapterTitle('prologue_intro_64kb', index: 0), 'Part 1');
      expect(prettifyChapterTitle('prologue_intro_64kb'), 'prologue intro');
    });

    test('leaves real titles untouched', () {
      for (final t in [
        'Null-P',
        'Venus and the Seven Sexes',
        'Chapter 1 - Letter 1',
        'Letter_1 to Mrs. Saville',
        '01 Introduction',
        'Chapter1',
        '',
      ]) {
        expect(prettifyChapterTitle(t, index: 3), t);
      }
    });
  });
}

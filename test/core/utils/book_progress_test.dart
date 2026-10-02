import 'package:diegema/core/utils/book_progress.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:flutter_test/flutter_test.dart';

AudiobookChapter ch(int secs) => AudiobookChapter(
    id: 'c$secs', title: 't', audioPathOrUrl: 'x', durationSeconds: secs);

void main() {
  test('fraction and time left sum prior chapters plus position', () {
    final p = BookProgress.from([ch(600), ch(600), ch(600)],
        savedChapterIndex: 1, savedPositionSeconds: 300)!;
    expect(p.chapterNumber, 2);
    expect(p.fraction, closeTo(0.5, 1e-9));
    expect(p.remainingSeconds, 900);
    expect(p.chapterRemainingSeconds, 300);
    expect(p.chapterFraction, closeTo(0.5, 1e-9));
  });

  test('unknown durations hide the dependent pieces', () {
    final p = BookProgress.from([ch(0), ch(0)],
        savedChapterIndex: 1, savedPositionSeconds: 30)!;
    expect(p.fraction, isNull);
    expect(p.remainingSeconds, isNull);
    expect(p.chapterRemainingSeconds, isNull);
    expect(p.chapterNumber, 2);
  });

  test('negative position is finished; nothing saved is null', () {
    final p = BookProgress.from([ch(10)],
        savedChapterIndex: 0, savedPositionSeconds: -1)!;
    expect(p.finished, isTrue);
    expect(p.fraction, 1);
    expect(
        BookProgress.from([ch(10)],
            savedChapterIndex: null, savedPositionSeconds: null),
        isNull);
  });

  test('formatting', () {
    expect(formatTimeLeft(3661), '1 h 01 m');
    expect(formatTimeLeft(2700), '45 m');
    expect(formatTimeLeft(20), '<1 m');
    expect(primaryActionLabel(null), 'Play');
    final p = BookProgress.from([ch(3000), ch(3000)],
        savedChapterIndex: 1, savedPositionSeconds: 1122)!;
    expect(primaryActionLabel(p), 'Resume · Ch 2, 18:42');
  });
}

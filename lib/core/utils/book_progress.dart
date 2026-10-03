import '../../domain/models/audiobook.dart';
import 'duration_format.dart';

/// Where a listener is in a book, derived from the saved position
/// (`PlaybackProgress`: a chapter index plus seconds *within* that chapter)
/// and the chapter durations. Unknown durations (`0`, as for local files
/// that were never probed) leave the dependent fields `null` rather than
/// inventing numbers.
class BookProgress {
  const BookProgress({
    required this.chapterIndex,
    required this.chapterCount,
    required this.positionSeconds,
    required this.finished,
    this.fraction,
    this.remainingSeconds,
    this.chapterDurationSeconds,
  });

  /// Zero-based current chapter (clamped into the book).
  final int chapterIndex;
  final int chapterCount;

  /// Seconds into [chapterIndex]; `0` when [finished].
  final int positionSeconds;
  final bool finished;

  /// 0..1 of the whole book, or null when total runtime is unknown.
  final double? fraction;
  final int? remainingSeconds;

  /// Duration of the current chapter, null when unknown.
  final int? chapterDurationSeconds;

  int get chapterNumber => chapterIndex + 1;

  /// Seconds left in the current chapter, null when its length is unknown.
  int? get chapterRemainingSeconds {
    final d = chapterDurationSeconds;
    if (d == null) return null;
    return (d - positionSeconds).clamp(0, d);
  }

  double? get chapterFraction {
    final d = chapterDurationSeconds;
    if (d == null) return null;
    return (positionSeconds / d).clamp(0.0, 1.0);
  }

  /// Builds the progress for [chapters]. A negative [savedPositionSeconds]
  /// is the "finished" marker (`AppDatabase.finishedPositionSeconds`).
  /// Returns null when there is nothing saved or the book has no chapters.
  static BookProgress? from(
    List<AudiobookChapter> chapters, {
    required int? savedChapterIndex,
    required int? savedPositionSeconds,
  }) {
    if (chapters.isEmpty ||
        savedChapterIndex == null ||
        savedPositionSeconds == null) {
      return null;
    }
    final finished = savedPositionSeconds < 0;
    final index = savedChapterIndex.clamp(0, chapters.length - 1);
    final total = chapters.fold<int>(0, (sum, c) => sum + c.durationSeconds);
    final position = finished ? 0 : savedPositionSeconds;
    final chapterDur = chapters[index].durationSeconds;

    double? fraction;
    int? remaining;
    if (finished) {
      fraction = 1;
      remaining = 0;
    } else if (total > 0) {
      var elapsed = position;
      for (var i = 0; i < index; i++) {
        elapsed += chapters[i].durationSeconds;
      }
      elapsed = elapsed.clamp(0, total);
      fraction = elapsed / total;
      remaining = total - elapsed;
    }
    return BookProgress(
      chapterIndex: index,
      chapterCount: chapters.length,
      positionSeconds: position,
      finished: finished,
      fraction: fraction,
      remainingSeconds: remaining,
      chapterDurationSeconds: chapterDur > 0 ? chapterDur : null,
    );
  }
}

/// "1 h 01 m left" style remaining time: hours with a zero-padded minute,
/// "45 m" under an hour, "<1 m" under a minute.
String formatTimeLeft(int seconds) {
  final d = Duration(seconds: seconds < 0 ? 0 : seconds);
  if (d.inHours > 0) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours} h $m m';
  }
  if (d.inMinutes > 0) return '${d.inMinutes} m';
  return '<1 m';
}

/// The primary button label: "Play" with no progress (or a finished book,
/// which starts over), else "Resume · Ch N, mm:ss".
String primaryActionLabel(BookProgress? p) {
  if (p == null || p.finished) return 'Play';
  return 'Resume · Ch ${p.chapterNumber}, '
      '${formatTimecode(Duration(seconds: p.positionSeconds))}';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/audio_playback_service.dart';

/// A player that refuses to start, the way a browser refuses `play()` until
/// it has seen a user gesture. The media is loaded; only the start is denied.
class _RefusingPlayer extends AudioPlayer {
  @override
  Future<void> play() async {
    throw Exception(
        "NotAllowedError: play() failed because the user didn't interact "
        'with the document first');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a refused start is not a playback failure', () {
    late AudioPlaybackService service;

    // Built in setUp, outside any FakeAsync zone — the constructor creates a
    // stream subscription and a periodic timer, and building it inside a
    // test body has deadlocked this suite before.
    setUp(() {
      service = AudioPlaybackService(player: _RefusingPlayer());
    });

    test('play() leaves the book paused rather than surfacing an error',
        () async {
      expect(service.stateNotifier.value, PlaybackState.idle);

      await service.play();

      // The visible consequence: "Playback failed" is bound to
      // PlaybackState.error, and a browser autoplay block must not trigger
      // it — the audio loaded fine and just needs a tap.
      expect(service.stateNotifier.value, isNot(PlaybackState.error));
      expect(service.stateNotifier.value, PlaybackState.paused);
    });

    test('play() does not rethrow a refused start to the caller', () {
      expect(service.play(), completes);
    });
  });

  group('AudioPlaybackService Sleep Timer TDD Unit Tests', () {
    test('setSleepTimer updates sleepTimerNotifier and timer count', () {
      final service = AudioPlaybackService();

      expect(service.sleepTimerNotifier.value, isNull);

      service.setSleepTimer(const Duration(minutes: 15));
      expect(service.sleepTimerNotifier.value,
          equals(const Duration(minutes: 15)));

      service.cancelSleepTimer();
      expect(service.sleepTimerNotifier.value, isNull);
    });

    test('cancelSleepTimer clears remaining duration', () {
      final service = AudioPlaybackService();

      service.setSleepTimer(const Duration(minutes: 30));
      expect(service.sleepTimerNotifier.value,
          equals(const Duration(minutes: 30)));

      service.cancelSleepTimer();
      expect(service.sleepTimerNotifier.value, isNull);
    });
  });

  group('end-of-chapter sleep timer', () {
    UnifiedAudiobook book(List<AudiobookChapter> chapters) => UnifiedAudiobook(
        id: 'b', title: 'B', author: 'A', description: '', chapters: chapters);

    // Neither shape loads in a test (no file, no platform audio), but the
    // chapter index is set before the load is attempted — which is all the
    // completion handling looks at.
    final separateFiles = book([
      AudiobookChapter(
          id: '1',
          title: 'One',
          audioPathOrUrl: '/x/1.mp3',
          durationSeconds: 60),
      AudiobookChapter(
          id: '2',
          title: 'Two',
          audioPathOrUrl: '/x/2.mp3',
          durationSeconds: 60),
    ]);
    final m4bClips = book([
      AudiobookChapter(
          id: '1',
          title: 'One',
          audioPathOrUrl: '/x/all.m4b',
          durationSeconds: 60,
          startMs: 0,
          endMs: 60000),
      AudiobookChapter(
          id: '2',
          title: 'Two',
          audioPathOrUrl: '/x/all.m4b',
          durationSeconds: 60,
          startMs: 60000,
          endMs: 120000),
    ]);

    for (final entry in {
      'separate files': separateFiles,
      'M4B clips of one file': m4bClips,
    }.entries) {
      test('stops at the end of the chapter: ${entry.key}', () async {
        final service = AudioPlaybackService();
        await service.loadBook(entry.value, autoPlay: false);
        service.setSleepTimerEndOfChapter();
        expect(service.sleepAtChapterEndNotifier.value, isTrue);

        service.debugCompleteChapter();
        await Future<void>.delayed(Duration.zero);

        expect(service.sleepTimerFired.value, 1);
        expect(service.sleepAtChapterEndNotifier.value, isFalse);
        // Next chapter is cued, not playing.
        expect(service.chapterIndexNotifier.value, 1);
        expect(service.stateNotifier.value, isNot(PlaybackState.playing));
      });
    }

    test('without the timer a finished chapter still advances', () async {
      final service = AudioPlaybackService();
      await service.loadBook(separateFiles, autoPlay: false);
      service.debugCompleteChapter();
      await Future<void>.delayed(Duration.zero);
      expect(service.chapterIndexNotifier.value, 1);
      expect(service.sleepTimerFired.value, 0);
    });

    test('cancelling disarms it, and a duration timer replaces it', () async {
      final service = AudioPlaybackService();
      service.setSleepTimerEndOfChapter();
      service.cancelSleepTimer();
      expect(service.sleepAtChapterEndNotifier.value, isFalse);

      service.setSleepTimerEndOfChapter();
      service.setSleepTimer(const Duration(minutes: 5));
      expect(service.sleepAtChapterEndNotifier.value, isFalse);
      service.cancelSleepTimer();
    });
  });
}

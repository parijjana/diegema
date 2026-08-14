import 'package:diegema/core/playback_constants.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/audio_playback_service.dart';

/// A playback service that touches no audio and no network.
///
/// [AudioPlaybackService] is a concrete class the screens depend on
/// directly, so the stub subclasses it and overrides every method that
/// would reach `just_audio`. The inherited [ValueNotifier]s are the real
/// ones, so widgets under test observe exactly the same surface they do in
/// production — only the source of truth behind them is fake.
///
/// The call counters exist so a test can assert that navigation *did not*
/// touch playback, which is the actual requirement in the redesign spec
/// ("a defined way back to the list without stopping playback"). Asserting
/// only that `currentBookNotifier` is still set would pass even if the
/// screen had paused the audio.
class FakePlaybackService extends AudioPlaybackService {
  FakePlaybackService();

  int loadCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;

  /// Fixed so golden frames never depend on wall-clock timing.
  static const Duration fixedPosition = Duration(minutes: 12, seconds: 34);
  static const Duration fixedDuration = Duration(minutes: 58, seconds: 20);

  @override
  Future<void> loadBook(
    UnifiedAudiobook book, {
    int? initialChapterIndex,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    loadCalls++;
    currentBookNotifier.value = book;
    chapterIndexNotifier.value = initialChapterIndex ?? 0;
    positionNotifier.value = initialPosition ?? fixedPosition;
    durationNotifier.value = fixedDuration;
    stateNotifier.value =
        autoPlay ? PlaybackState.playing : PlaybackState.paused;
  }

  @override
  Future<void> play() async {
    playCalls++;
    stateNotifier.value = PlaybackState.playing;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    stateNotifier.value = PlaybackState.paused;
  }

  @override
  Future<void> togglePlayPause() async {
    if (stateNotifier.value == PlaybackState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls++;
    positionNotifier.value = position;
  }

  @override
  Future<void> skipForward({int seconds = kSkipSeconds}) async =>
      seek(positionNotifier.value + Duration(seconds: seconds));

  @override
  Future<void> skipBackward({int seconds = kSkipSeconds}) async =>
      seek(positionNotifier.value - Duration(seconds: seconds));

  @override
  Future<void> nextChapter() async =>
      chapterIndexNotifier.value = chapterIndexNotifier.value + 1;

  @override
  Future<void> previousChapter() async =>
      chapterIndexNotifier.value = chapterIndexNotifier.value - 1;

  @override
  Future<void> setSpeed(double speed) async => speedNotifier.value = speed;

  /// `super.dispose()` cancels the inherited progress-save timer (which the
  /// test binding would otherwise flag as pending) and then disposes the
  /// real `AudioPlayer`; that last step can throw under the test binding,
  /// which is why callers swallow it.
  @override
  Future<void> dispose() => super.dispose();
}

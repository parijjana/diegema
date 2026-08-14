import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
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

    test('play() leaves the book paused rather than surfacing an error', () async {
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
}

import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/sync/sync_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int syncs;
  late ValueNotifier<PlaybackState> playback;
  late SyncScheduler scheduler;

  // Built inside fakeAsync so its timers run on fake time (see
  // lessons_learnt flutter-fakeasync-construction-zone-hang.md).
  void run(void Function(FakeAsync clock) body) => fakeAsync((clock) {
        syncs = 0;
        playback = ValueNotifier(PlaybackState.idle);
        scheduler = SyncScheduler(sync: () async => syncs++, playback: playback)
          ..start();
        body(clock);
        scheduler.dispose();
      });

  test('every 15 minutes while the app runs', () {
    run((clock) {
      clock.elapse(const Duration(minutes: 14, seconds: 59));
      expect(syncs, 0);
      clock.elapse(const Duration(seconds: 1));
      expect(syncs, 1);
      clock.elapse(const Duration(minutes: 30));
      expect(syncs, 3);
    });
  });

  test('5 s after playback pauses, stops or finishes', () {
    for (final end in [
      PlaybackState.paused,
      PlaybackState.completed,
      PlaybackState.idle,
    ]) {
      run((clock) {
        playback.value = PlaybackState.playing;
        playback.value = end;
        clock.elapse(const Duration(seconds: 4));
        expect(syncs, 0, reason: '$end');
        clock.elapse(const Duration(seconds: 1));
        expect(syncs, 1, reason: '$end');
      });
    }
  });

  test('a chapter ending and the next one loading slowly does not sync', () {
    run((clock) {
      playback.value = PlaybackState.playing;
      playback.value = PlaybackState.completed;
      clock.elapse(const Duration(seconds: 1));
      playback.value = PlaybackState.loading;
      clock.elapse(const Duration(seconds: 20));
      playback.value = PlaybackState.playing;
      clock.elapse(const Duration(seconds: 10));
      expect(syncs, 0);
    });
  });

  test('a quick pause and resume does not sync', () {
    run((clock) {
      playback.value = PlaybackState.playing;
      playback.value = PlaybackState.paused;
      clock.elapse(const Duration(seconds: 2));
      playback.value = PlaybackState.playing;
      clock.elapse(const Duration(seconds: 10));
      expect(syncs, 0);
    });
  });

  test('buffering, loading and errors do not sync', () {
    run((clock) {
      playback.value = PlaybackState.loading;
      playback.value = PlaybackState.playing;
      playback.value = PlaybackState.loading;
      playback.value = PlaybackState.playing;
      playback.value = PlaybackState.error;
      playback.value = PlaybackState.paused; // was error, not playing
      clock.elapse(const Duration(seconds: 10));
      expect(syncs, 0);
    });
  });

  test('stops when disposed', () {
    run((clock) {
      scheduler.dispose();
      playback.value = PlaybackState.playing;
      playback.value = PlaybackState.paused;
      clock.elapse(const Duration(hours: 1));
      expect(syncs, 0);
    });
  });
}

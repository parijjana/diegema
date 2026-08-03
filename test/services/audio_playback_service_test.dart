import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/services/audio_playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlaybackService Sleep Timer TDD Unit Tests', () {
    test('setSleepTimer updates sleepTimerNotifier and timer count', () {
      final service = AudioPlaybackService();

      expect(service.sleepTimerNotifier.value, isNull);

      service.setSleepTimer(const Duration(minutes: 15));
      expect(service.sleepTimerNotifier.value, equals(const Duration(minutes: 15)));

      service.cancelSleepTimer();
      expect(service.sleepTimerNotifier.value, isNull);
    });

    test('cancelSleepTimer clears remaining duration', () {
      final service = AudioPlaybackService();

      service.setSleepTimer(const Duration(minutes: 30));
      expect(service.sleepTimerNotifier.value, equals(const Duration(minutes: 30)));

      service.cancelSleepTimer();
      expect(service.sleepTimerNotifier.value, isNull);
    });
  });
}

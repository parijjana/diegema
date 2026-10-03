import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';

UnifiedAudiobook _book(String id) => UnifiedAudiobook(
      id: id,
      title: id,
      author: 'A',
      description: '',
      chapters: [
        AudiobookChapter(
            id: '1',
            title: 'One',
            audioPathOrUrl: '/x/1.mp3',
            durationSeconds: 1),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speed preferences', () {
    test('default is 1.0 and a stored value round-trips', () async {
      final store = <String, Object>{};
      final prefs = UiPreferences(overrides: store);
      expect(await prefs.getDefaultSpeed(), 1.0);
      await prefs.setDefaultSpeed(1.5);
      expect(await prefs.getDefaultSpeed(), 1.5);
    });

    test('a speed the app does not offer falls back', () async {
      const prefs = UiPreferences(overrides: {
        'playback.default_speed': 3.7,
        'playback.book_speed.b': 'fast',
      });
      expect(await prefs.getDefaultSpeed(), 1.0);
      expect(await prefs.getBookSpeed('b'), isNull);
    });

    test('AppSettings loads and persists the default speed', () async {
      final store = <String, Object>{'playback.default_speed': 1.25};
      final settings =
          AppSettings(preferences: UiPreferences(overrides: store));
      await settings.load();
      expect(settings.defaultSpeed, 1.25);

      await settings.setDefaultSpeed(2.0);
      expect(store['playback.default_speed'], 2.0);
      await settings.setDefaultSpeed(9.0);
      expect(settings.defaultSpeed, 2.0, reason: 'not an offered option');
    });
  });

  group('AudioPlaybackService speed', () {
    test('a book opens at its own speed, else the global default', () async {
      final store = <String, Object>{
        'playback.default_speed': 1.5,
        'playback.book_speed.own': 0.75,
      };
      final service =
          AudioPlaybackService(preferences: UiPreferences(overrides: store));

      await service.loadBook(_book('plain'), autoPlay: false);
      expect(service.speedNotifier.value, 1.5);

      await service.loadBook(_book('own'), autoPlay: false);
      expect(service.speedNotifier.value, 0.75);

      await service.loadBook(_book('plain'), autoPlay: false);
      expect(service.speedNotifier.value, 1.5,
          reason: "one book's override must not leak into the next");
    });

    test('changing speed while a book plays remembers it for that book',
        () async {
      final store = <String, Object>{};
      final service =
          AudioPlaybackService(preferences: UiPreferences(overrides: store));
      await service.loadBook(_book('b'), autoPlay: false);

      // The platform player is absent under test; the preference is written
      // before it is reached.
      try {
        await service.setSpeed(1.75);
      } catch (_) {}

      expect(store['playback.book_speed.b'], 1.75);
      expect(store.containsKey('playback.default_speed'), isFalse);
    });
  });
}

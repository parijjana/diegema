import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart' show MediaAction;
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/diegema_audio_handler.dart';

import '../support/fake_playback_service.dart';

UnifiedAudiobook _book({int chapters = 2}) => UnifiedAudiobook(
      id: 'book-1',
      title: 'Test Book',
      author: 'Test Author',
      description: '',
      coverArtUrlOrPath: 'https://example.com/cover.jpg',
      chapters: [
        for (var i = 0; i < chapters; i++)
          AudiobookChapter(
            id: 'chapter-$i',
            title: 'Chapter $i',
            audioPathOrUrl: 'https://example.com/$i.mp3',
            durationSeconds: 100,
          ),
      ],
    );

/// [FakePlaybackService] still runs its inherited [AudioPlaybackService]
/// constructor, which wires a real (platform-channel-less) `just_audio`
/// player's own state/position streams straight onto `stateNotifier`/
/// `positionNotifier` — harmless in the widget tests that drive the fake
/// through its own overridden methods only, but a source of flaky
/// interleaving here, where the assertion needs the exact position
/// [DiegemaAudioHandler.fastForward]/[DiegemaAudioHandler.rewind] computed
/// to have been passed to [AudioPlaybackService.seek], read back across an
/// `await`. Recording it directly, before `super.seek` touches
/// `positionNotifier`, sidesteps that race instead of asserting on a value
/// a background stream event could still overwrite.
class _RecordingPlaybackService extends FakePlaybackService {
  Duration? lastSeek;

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    await super.seek(position);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlaybackService fake;
  late DiegemaAudioHandler handler;

  setUp(() {
    fake = FakePlaybackService();
    handler = DiegemaAudioHandler(fake, skipSeconds: () => 30);
  });

  tearDown(() {
    handler.disposeHandler();
  });

  group('transport controls forward to the wrapped service', () {
    test('play/pause/seek', () async {
      await handler.play();
      expect(fake.playCalls, 1);

      await handler.pause();
      expect(fake.pauseCalls, 1);

      await handler.seek(const Duration(minutes: 3));
      expect(fake.seekCalls, 1);
    });

    test('fastForward and rewind use the injected skip interval', () async {
      final recording = _RecordingPlaybackService();
      final recordingHandler =
          DiegemaAudioHandler(recording, skipSeconds: () => 30);
      addTearDown(recordingHandler.disposeHandler);

      recording.positionNotifier.value = const Duration(minutes: 5);
      await recordingHandler.fastForward();
      expect(recording.lastSeek, const Duration(minutes: 5, seconds: 30));

      recording.positionNotifier.value = const Duration(minutes: 5);
      await recordingHandler.rewind();
      expect(recording.lastSeek, const Duration(minutes: 4, seconds: 30));
    });

    test('skipToNext/skipToPrevious call chapter navigation, not seeking',
        () async {
      fake.chapterIndexNotifier.value = 0;

      await handler.skipToNext();
      expect(fake.chapterIndexNotifier.value, 1);

      await handler.skipToPrevious();
      expect(fake.chapterIndexNotifier.value, 0);
      // Chapter navigation, not a seek — the fake's `previousChapter`
      // override touches the chapter index directly.
      expect(fake.seekCalls, 0);
    });
  });

  group('mediaItem reflects the current book/chapter', () {
    test('is null when nothing is loaded', () {
      expect(handler.mediaItem.value, isNull);
    });

    test('updates when a book loads and again when the chapter changes',
        () async {
      final book = _book();
      await fake.loadBook(book, autoPlay: false);

      final first = handler.mediaItem.value;
      expect(first, isNotNull);
      expect(first!.id, 'chapter-0');
      expect(first.title, 'Chapter 0');
      expect(first.album, 'Test Book');
      expect(first.artist, 'Test Author');
      expect(first.artUri, Uri.parse('https://example.com/cover.jpg'));

      fake.chapterIndexNotifier.value = 1;

      final second = handler.mediaItem.value;
      expect(second!.id, 'chapter-1');
      expect(second.title, 'Chapter 1');
    });
  });

  group('playbackState reflects the wrapped service', () {
    test('playing flag and controls follow stateNotifier', () {
      fake.stateNotifier.value = PlaybackState.playing;
      expect(handler.playbackState.value.playing, isTrue);
      expect(
        handler.playbackState.value.controls
            .any((c) => c.action == MediaAction.play),
        isFalse,
      );

      fake.stateNotifier.value = PlaybackState.paused;
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.controls
            .any((c) => c.action == MediaAction.play),
        isTrue,
      );
    });
  });
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../core/playback_constants.dart';
import '../domain/models/audiobook.dart';
// Prefixed: `PlaybackState` here (the app's play/pause/loading/... enum)
// would otherwise collide with `audio_service`'s own `PlaybackState` class
// (the notification/lock-screen state snapshot broadcast below).
import 'audio_playback_service.dart' as playback;

/// Bridges [AudioPlaybackService] to `audio_service`, so the same player
/// the app's own UI drives also feeds the lock screen, the Android
/// notification and headset/Bluetooth media buttons.
///
/// This wraps the existing service rather than replacing it: `audio_service`
/// only ever sees `play`/`pause`/`seek`/chapter-skip calls forwarded onto
/// [AudioPlaybackService], and every notifier on that service (position,
/// duration, chapter index, current book...) stays the single source of
/// truth the in-app UI already reads from. `SeekHandler` supplies the
/// default fast-forward/rewind-via-seek behaviour for platforms that ask
/// for it; [fastForward]/[rewind] below override it with the app's own
/// skip-interval semantics regardless.
class DiegemaAudioHandler extends BaseAudioHandler with SeekHandler {
  final playback.AudioPlaybackService _playbackService;

  /// How far [fastForward]/[rewind] jump, in seconds. A closure rather than
  /// a fixed value so it can track the user's skip-interval setting
  /// (`AppSettings.skipSeconds`) live, the same way [MiniPlayerBar] and
  /// `NowPlayingScreen` already do — see `core/playback_constants.dart`.
  final int Function() _skipSeconds;

  /// Detach closures for every listener registered on the wrapped service's
  /// notifiers, run by [disposeHandler]. A plain list of `VoidCallback`s
  /// rather than `StreamSubscription`s: [ValueNotifier] is listener-based
  /// already, so wrapping it in a `Stream` just to get a cancellable handle
  /// would be machinery for its own sake.
  final List<VoidCallback> _detachListeners = [];

  DiegemaAudioHandler(
    this._playbackService, {
    int Function() skipSeconds = _defaultSkipSeconds,
  }) : _skipSeconds = skipSeconds {
    _broadcastMediaItem();
    _broadcastPlaybackState();

    _listen(_playbackService.stateNotifier, _broadcastPlaybackState);
    _listen(_playbackService.positionNotifier, _broadcastPlaybackState);
    _listen(_playbackService.durationNotifier, _broadcastMediaItem);
    _listen(_playbackService.speedNotifier, _broadcastPlaybackState);
    _listen(_playbackService.currentBookNotifier, _broadcastMediaItem);
    _listen(_playbackService.chapterIndexNotifier, _broadcastMediaItem);
  }

  void _listen<T>(ValueNotifier<T> notifier, VoidCallback onChange) {
    notifier.addListener(onChange);
    _detachListeners.add(() => notifier.removeListener(onChange));
  }

  static int _defaultSkipSeconds() => kSkipSeconds;

  UnifiedAudiobook? get _book => _playbackService.currentBookNotifier.value;
  int get _chapterIndex => _playbackService.chapterIndexNotifier.value;

  AudiobookChapter? get _chapter {
    final book = _book;
    if (book == null ||
        _chapterIndex < 0 ||
        _chapterIndex >= book.chapters.length) {
      return null;
    }
    return book.chapters[_chapterIndex];
  }

  void _broadcastMediaItem() {
    final book = _book;
    final chapter = _chapter;
    if (book == null || chapter == null) {
      mediaItem.add(null);
      return;
    }

    final coverPath = book.coverArtUrlOrPath;
    Uri? artUri;
    if (coverPath != null && coverPath.isNotEmpty) {
      if (coverPath.startsWith('http://') || coverPath.startsWith('https://')) {
        artUri = Uri.tryParse(coverPath);
      } else {
        artUri = Uri.file(coverPath);
      }
    }

    final duration = _playbackService.durationNotifier.value;

    mediaItem.add(MediaItem(
      id: chapter.id,
      album: book.title,
      title: chapter.title,
      artist: book.author,
      duration: duration > Duration.zero ? duration : null,
      artUri: artUri,
    ));
  }

  void _broadcastPlaybackState() {
    final state = _playbackService.stateNotifier.value;
    final playing = state == playback.PlaybackState.playing;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
        MediaControl.skipToPrevious,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (state) {
        playback.PlaybackState.idle => AudioProcessingState.idle,
        playback.PlaybackState.loading => AudioProcessingState.loading,
        playback.PlaybackState.playing => AudioProcessingState.ready,
        playback.PlaybackState.paused => AudioProcessingState.ready,
        playback.PlaybackState.completed => AudioProcessingState.completed,
        playback.PlaybackState.error => AudioProcessingState.error,
      },
      playing: playing,
      updatePosition: _playbackService.positionNotifier.value,
      bufferedPosition: _playbackService.positionNotifier.value,
      speed: _playbackService.speedNotifier.value,
    ));
  }

  @override
  Future<void> play() => _playbackService.play();

  @override
  Future<void> pause() => _playbackService.pause();

  @override
  Future<void> stop() => _playbackService.pause();

  @override
  Future<void> seek(Duration position) => _playbackService.seek(position);

  @override
  Future<void> fastForward() =>
      _playbackService.skipForward(seconds: _skipSeconds());

  @override
  Future<void> rewind() =>
      _playbackService.skipBackward(seconds: _skipSeconds());

  @override
  Future<void> skipToNext() => _playbackService.nextChapter();

  @override
  Future<void> skipToPrevious() => _playbackService.previousChapter();

  /// Detaches every listener registered onto [_playbackService]. Does
  /// **not** dispose the service itself — this handler wraps a service
  /// owned elsewhere (`main.dart`), the same way it never created it.
  void disposeHandler() {
    for (final detach in _detachListeners) {
      detach();
    }
    _detachListeners.clear();
  }
}

/// Registers [DiegemaAudioHandler] with `audio_service` so background
/// playback, the lock screen and the Android notification come alive.
///
/// Must run before `runApp` (the plugin's own requirement — it needs to
/// install its platform channel handlers ahead of the widget tree). Callers
/// on web/desktop platforms `audio_service` does not support, or under
/// `flutter_test` (where the plugin's platform channel does not exist),
/// should not call this at all — see `main.dart`, which guards the call
/// rather than this function swallowing the failure, so a genuine setup
/// mistake on a supported platform still surfaces instead of going quiet.
Future<DiegemaAudioHandler> initDiegemaAudioService(
  playback.AudioPlaybackService playbackService, {
  int Function() skipSeconds = DiegemaAudioHandler._defaultSkipSeconds,
}) {
  return AudioService.init(
    builder: () =>
        DiegemaAudioHandler(playbackService, skipSeconds: skipSeconds),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'com.overengineeredhobbies.diegema.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: false,
    ),
  );
}

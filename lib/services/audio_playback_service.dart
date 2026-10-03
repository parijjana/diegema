import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../core/playback_constants.dart';
import '../core/ui_preferences.dart';
import '../domain/models/audiobook.dart';
import '../database/app_database.dart';
import 'local_file_playback.dart';

enum PlaybackState {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

class AudioPlaybackService {
  final AudioPlayer _player;
  final AppDatabase? _db;

  /// The library database, for screens that change a book in place.
  AppDatabase? get database => _db;
  final UiPreferences? _preferences;
  bool _isInitialized = false;

  UnifiedAudiobook? _currentBook;
  int _currentChapterIndex = 0;
  double _playbackSpeed = 1.0;

  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  Timer? _sleepTimerTicker;
  Timer? _progressSaveTimer;

  /// True from the moment a chapter starts loading until the seek to its
  /// restore position has landed. The player reports "ready, not playing"
  /// (our paused state) part-way through that, while its position is still
  /// 0 — or still the previous book's — so progress must not be saved then,
  /// or a cold start overwrites the saved place with 0.
  bool _loading = false;

  /// The book whose saved progress was just marked finished or reset. While
  /// it is the loaded (but not playing) book, pause/seek must not write its
  /// position back; cleared when it plays again or another book loads.
  String? _progressFrozenBookId;

  final ValueNotifier<PlaybackState> stateNotifier =
      ValueNotifier(PlaybackState.idle);
  final ValueNotifier<UnifiedAudiobook?> currentBookNotifier =
      ValueNotifier(null);
  final ValueNotifier<int> chapterIndexNotifier = ValueNotifier(0);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> speedNotifier = ValueNotifier(1.0);
  final ValueNotifier<Duration?> sleepTimerNotifier = ValueNotifier(null);

  /// True while the "end of chapter" sleep timer is armed. Separate from
  /// [sleepTimerNotifier] because there is no countdown to show.
  final ValueNotifier<bool> sleepAtChapterEndNotifier = ValueNotifier(false);

  /// Bumped each time the sleep timer runs out (not when it is cancelled),
  /// so the ambience channel can stop with the book.
  final ValueNotifier<int> sleepTimerFired = ValueNotifier(0);

  /// [preferences] remembers each book's speed and supplies the global
  /// default; without it speed is not persisted (tests, demo).
  AudioPlaybackService(
      {AudioPlayer? player, AppDatabase? db, UiPreferences? preferences})
      : _player = player ?? AudioPlayer(),
        _db = db,
        _preferences = preferences {
    _listenToPlayerStreams();
    _startProgressAutoSave();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioPlaybackService: AudioSession init failed: $e');
    }
  }

  void _listenToPlayerStreams() {
    _player.playerStateStream.listen((playerState) {
      final processingState = playerState.processingState;
      final playing = playerState.playing;

      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        stateNotifier.value = PlaybackState.loading;
      } else if (processingState == ProcessingState.completed) {
        stateNotifier.value = PlaybackState.completed;
        _onChapterCompleted();
      } else if (playing) {
        _progressFrozenBookId = null;
        stateNotifier.value = PlaybackState.playing;
      } else if (!playing && processingState == ProcessingState.ready) {
        stateNotifier.value = PlaybackState.paused;
        _persistCurrentProgress();
      } else if (processingState == ProcessingState.idle) {
        stateNotifier.value = PlaybackState.idle;
      }
    });

    // Errors after a chapter has loaded (a stream dropping, a file deleted
    // mid-play) arrive only here, never through playerStateStream.
    _player.playbackEventStream.listen((_) {}, onError: (Object e, _) {
      if (_loading) return; // the load's own catch reports it
      debugPrint('AudioPlaybackService: playback error: $e');
      stateNotifier.value = PlaybackState.error;
    });

    _player.positionStream.listen((pos) {
      positionNotifier.value = pos;
    });

    _player.durationStream.listen((dur) {
      durationNotifier.value = dur ?? Duration.zero;
    });
  }

  void _startProgressAutoSave() {
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (stateNotifier.value == PlaybackState.playing) {
        _persistCurrentProgress();
      }
    });
  }

  Future<void> _persistCurrentProgress() async {
    if (_loading) return;
    if (_db != null &&
        _currentBook != null &&
        _currentBook!.id != _progressFrozenBookId) {
      try {
        await _db!.saveProgress(
          audiobookId: _currentBook!.id,
          chapterIndex: _currentChapterIndex,
          // The player's own position, not positionNotifier: the notifier
          // only catches up on the next position tick.
          positionSeconds: _player.position.inSeconds,
        );
      } catch (e) {
        debugPrint('AudioPlaybackService: Error saving progress: $e');
      }
    }
  }

  /// Loads [book], restoring saved progress unless [initialChapterIndex] /
  /// [initialPosition] are supplied explicitly.
  ///
  /// [autoPlay] defaults to `true` (every existing call site's behaviour is
  /// unchanged). Passing `false` loads the chapter, seeks to the target
  /// position, and leaves playback paused — used by [NowPlayingScreen] to
  /// restore the last-played book on the idle screen without starting
  /// audio the user did not ask for.
  Future<void> loadBook(
    UnifiedAudiobook book, {
    int? initialChapterIndex,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    await init();
    _progressFrozenBookId = null;
    _currentBook = book;
    currentBookNotifier.value = book;

    if (_db != null) {
      try {
        await _db!.saveAudiobook(book);
      } catch (e) {
        debugPrint('AudioPlaybackService: Error storing book in DB: $e');
      }
    }

    // A book's own speed wins; otherwise the global default.
    final prefs = _preferences;
    if (prefs != null) {
      try {
        _playbackSpeed =
            await prefs.getBookSpeed(book.id) ?? await prefs.getDefaultSpeed();
        speedNotifier.value = _playbackSpeed;
      } catch (_) {}
    }

    // Attempt to restore progress from database if not explicitly supplied
    int targetChapter = initialChapterIndex ?? 0;
    Duration targetPosition = initialPosition ?? Duration.zero;

    if (initialChapterIndex == null && _db != null) {
      try {
        final savedProgress = await _db!.getProgress(book.id);
        // A finished book starts over from the top.
        if (savedProgress != null &&
            savedProgress.positionSeconds !=
                AppDatabase.finishedPositionSeconds) {
          targetChapter = savedProgress.chapterIndex;
          targetPosition = Duration(seconds: savedProgress.positionSeconds);
        }
      } catch (_) {}
    }

    _currentChapterIndex = targetChapter;
    chapterIndexNotifier.value = _currentChapterIndex;

    if (book.chapters.isEmpty) return;

    await _playCurrentChapter(
        seekToPosition: targetPosition, autoPlay: autoPlay);
  }

  Future<void> _playCurrentChapter(
      {Duration? seekToPosition, bool autoPlay = true}) async {
    if (_currentBook == null ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _currentBook!.chapters.length) {
      return;
    }

    final chapter = _currentBook!.chapters[_currentChapterIndex];
    stateNotifier.value = PlaybackState.loading;
    _loading = true;

    try {
      if (chapter.isStream ||
          chapter.audioPathOrUrl.startsWith('http://') ||
          chapter.audioPathOrUrl.startsWith('https://')) {
        await _player.setUrl(chapter.audioPathOrUrl);
      } else {
        final loaded = await playLocalFile(
          _player,
          chapter.audioPathOrUrl,
          start: chapter.startMs != null
              ? Duration(milliseconds: chapter.startMs!)
              : null,
          end: chapter.endMs != null
              ? Duration(milliseconds: chapter.endMs!)
              : null,
        );
        if (!loaded) {
          _loading = false;
          stateNotifier.value = PlaybackState.error;
          return;
        }
      }

      await _player.setSpeed(_playbackSpeed);

      if (seekToPosition != null && seekToPosition > Duration.zero) {
        await _player.seek(seekToPosition);
      }
      // Cleared here, not in a `finally`: `play()` below only completes
      // when playback stops.
      _loading = false;

      if (autoPlay) {
        // Only the *start* is allowed to fail benignly. Everything above
        // this point (loading the source, seeking) failing means the book
        // genuinely cannot be played, and falls through to the outer catch.
        //
        // A browser refuses `play()` until it has seen a user gesture, so on
        // web an autoplay block lands here with the media already loaded and
        // ready. That is not a failure — it is a book waiting for a tap, and
        // reporting "Playback failed" for it makes a working app look broken
        // to a first-time visitor. `playerStateStream` has already set
        // `paused` (ready && !playing) by this point; we must not stamp
        // `error` over it.
        try {
          await _player.play();
        } catch (e) {
          debugPrint('AudioPlaybackService: start refused, leaving paused: $e');
          stateNotifier.value = PlaybackState.paused;
        }
      } else {
        stateNotifier.value = PlaybackState.paused;
      }
    } catch (e) {
      _loading = false;
      debugPrint('AudioPlaybackService: Failed to play chapter: $e');
      stateNotifier.value = PlaybackState.error;
    }
  }

  void _onChapterCompleted() {
    if (sleepAtChapterEndNotifier.value) {
      _finishChapterEndSleep();
      return;
    }
    if (_currentBook != null &&
        _currentChapterIndex < _currentBook!.chapters.length - 1) {
      nextChapter();
    } else {
      stateNotifier.value = PlaybackState.completed;
    }
  }

  /// The end-of-chapter sleep timer fired. Cueing the next chapter paused
  /// (rather than leaving the finished one selected) means the next Play
  /// continues where the listener would expect, and the saved progress
  /// points there too. The last chapter just stays completed.
  ///
  /// Driven by the player's `completed` state, which a chapter that is a
  /// clip of a shared M4B (`ClippingAudioSource`) reaches at the clip end
  /// exactly like a separate file reaches its end.
  Future<void> _finishChapterEndSleep() async {
    cancelSleepTimer();
    sleepTimerFired.value++;
    final book = _currentBook;
    if (book != null && _currentChapterIndex < book.chapters.length - 1) {
      _currentChapterIndex++;
      chapterIndexNotifier.value = _currentChapterIndex;
      await _playCurrentChapter(autoPlay: false);
      await _persistCurrentProgress();
    }
  }

  @visibleForTesting
  void debugCompleteChapter() => _onChapterCompleted();

  /// Resumes playback. A refused start leaves the book paused rather than
  /// raising — same reasoning as `_playCurrentChapter`: the media is loaded,
  /// only the start was declined.
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlaybackService: start refused, leaving paused: $e');
      stateNotifier.value = PlaybackState.paused;
    }
  }

  /// Stops playback and clears the loaded book when [bookId] is the one
  /// currently loaded (a no-op otherwise). Clears the book *before* stopping
  /// so no progress is written back for a book that is being removed.
  Future<void> stopIfCurrent(String bookId) async {
    if (_currentBook?.id != bookId) return;
    _currentBook = null;
    _currentChapterIndex = 0;
    currentBookNotifier.value = null;
    chapterIndexNotifier.value = 0;
    await _player.stop();
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration.zero;
    stateNotifier.value = PlaybackState.idle;
  }

  Future<void> pause() async {
    await _player.pause();
    await _persistCurrentProgress();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    await _persistCurrentProgress();
  }

  Future<void> skipForward({int seconds = kSkipSeconds}) async {
    final newPos = positionNotifier.value + Duration(seconds: seconds);
    final maxDur = durationNotifier.value;
    // Zero means not known yet (a stream still loading): don't clamp to it,
    // or skipping forward jumps back to the start.
    await seek(maxDur > Duration.zero && newPos > maxDur ? maxDur : newPos);
  }

  Future<void> skipBackward({int seconds = kSkipSeconds}) async {
    final newPos = positionNotifier.value - Duration(seconds: seconds);
    await seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  /// Loads the current chapter again from where it stopped, after a
  /// playback error.
  Future<void> retryCurrentChapter() async {
    if (_currentBook == null) return;
    await _playCurrentChapter(seekToPosition: positionNotifier.value);
  }

  Future<void> nextChapter() async {
    if (_currentBook != null &&
        _currentChapterIndex < _currentBook!.chapters.length - 1) {
      _currentChapterIndex++;
      chapterIndexNotifier.value = _currentChapterIndex;
      await _playCurrentChapter();
    }
  }

  Future<void> previousChapter() async {
    if (positionNotifier.value.inSeconds > 5) {
      await seek(Duration.zero);
      return;
    }

    if (_currentBook != null && _currentChapterIndex > 0) {
      _currentChapterIndex--;
      chapterIndexNotifier.value = _currentChapterIndex;
      await _playCurrentChapter();
    }
  }

  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    speedNotifier.value = speed;
    final book = _currentBook;
    if (book != null) await _preferences?.setBookSpeed(book.id, speed);
    await _player.setSpeed(speed);
  }

  /// Marks [book] finished: it leaves "In progress" and stays out until it
  /// is played again. If it is the loaded book, playback stops first and the
  /// stopped player is not allowed to write its position back.
  Future<void> markFinished(UnifiedAudiobook book) async {
    await _stopIfCurrent(book);
    await _db?.markFinished(book.id,
        lastChapterIndex: book.chapters.isEmpty ? 0 : book.chapters.length - 1);
  }

  /// Clears the saved position of [book]. If it is the loaded book it is
  /// cued back at the start of its first chapter, paused.
  Future<void> resetProgress(UnifiedAudiobook book) async {
    await _stopIfCurrent(book);
    await _db?.resetProgress(book.id);
    if (_currentBook?.id == book.id && book.chapters.isNotEmpty) {
      _currentChapterIndex = 0;
      chapterIndexNotifier.value = 0;
      await _playCurrentChapter(autoPlay: false);
    }
  }

  Future<void> _stopIfCurrent(UnifiedAudiobook book) async {
    if (_currentBook?.id != book.id) return;
    _progressFrozenBookId = book.id;
    await _player.pause();
  }

  /// Save a bookmark at the current playback timestamp
  Future<void> addBookmark(String note) async {
    if (_db != null && _currentBook != null) {
      await _db!.addBookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        audiobookId: _currentBook!.id,
        chapterIndex: _currentChapterIndex,
        positionSeconds: positionNotifier.value.inSeconds,
        note: note,
      );
    }
  }

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerRemaining = duration;
    sleepTimerNotifier.value = _sleepTimerRemaining;

    _sleepTimer = Timer(duration, () async {
      await pause();
      cancelSleepTimer();
      sleepTimerFired.value++;
    });

    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemaining != null && _sleepTimerRemaining!.inSeconds > 0) {
        _sleepTimerRemaining =
            _sleepTimerRemaining! - const Duration(seconds: 1);
        sleepTimerNotifier.value = _sleepTimerRemaining;
      } else {
        cancelSleepTimer();
      }
    });
  }

  /// Stops playback when the current chapter ends instead of after a
  /// duration. Replaces any running timer.
  void setSleepTimerEndOfChapter() {
    cancelSleepTimer();
    sleepAtChapterEndNotifier.value = true;
  }

  void cancelSleepTimer() {
    sleepAtChapterEndNotifier.value = false;
    _sleepTimer?.cancel();
    _sleepTimerTicker?.cancel();
    _sleepTimer = null;
    _sleepTimerTicker = null;
    _sleepTimerRemaining = null;
    sleepTimerNotifier.value = null;
  }

  Future<void> dispose() async {
    _progressSaveTimer?.cancel();
    await _persistCurrentProgress();
    cancelSleepTimer();
    await _player.dispose();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../domain/models/audiobook.dart';
import '../database/app_database.dart';

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
  bool _isInitialized = false;

  UnifiedAudiobook? _currentBook;
  int _currentChapterIndex = 0;
  double _playbackSpeed = 1.0;

  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  Timer? _sleepTimerTicker;
  Timer? _progressSaveTimer;

  final ValueNotifier<PlaybackState> stateNotifier = ValueNotifier(PlaybackState.idle);
  final ValueNotifier<UnifiedAudiobook?> currentBookNotifier = ValueNotifier(null);
  final ValueNotifier<int> chapterIndexNotifier = ValueNotifier(0);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> speedNotifier = ValueNotifier(1.0);
  final ValueNotifier<Duration?> sleepTimerNotifier = ValueNotifier(null);

  AudioPlaybackService({AudioPlayer? player, AppDatabase? db})
      : _player = player ?? AudioPlayer(),
        _db = db {
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

      if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
        stateNotifier.value = PlaybackState.loading;
      } else if (processingState == ProcessingState.completed) {
        stateNotifier.value = PlaybackState.completed;
        _onChapterCompleted();
      } else if (playing) {
        stateNotifier.value = PlaybackState.playing;
      } else if (!playing && processingState == ProcessingState.ready) {
        stateNotifier.value = PlaybackState.paused;
        _persistCurrentProgress();
      } else if (processingState == ProcessingState.idle) {
        stateNotifier.value = PlaybackState.idle;
      }
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
    if (_db != null && _currentBook != null) {
      try {
        await _db!.saveProgress(
          audiobookId: _currentBook!.id,
          chapterIndex: _currentChapterIndex,
          positionSeconds: positionNotifier.value.inSeconds,
        );
      } catch (e) {
        debugPrint('AudioPlaybackService: Error saving progress: $e');
      }
    }
  }

  Future<void> loadBook(UnifiedAudiobook book, {int? initialChapterIndex, Duration? initialPosition}) async {
    await init();
    _currentBook = book;
    currentBookNotifier.value = book;

    if (_db != null) {
      try {
        await _db!.saveAudiobook(book);
      } catch (e) {
        debugPrint('AudioPlaybackService: Error storing book in DB: $e');
      }
    }

    // Attempt to restore progress from database if not explicitly supplied
    int targetChapter = initialChapterIndex ?? 0;
    Duration targetPosition = initialPosition ?? Duration.zero;

    if (initialChapterIndex == null && _db != null) {
      try {
        final savedProgress = await _db!.getProgress(book.id);
        if (savedProgress != null) {
          targetChapter = savedProgress.chapterIndex;
          targetPosition = Duration(seconds: savedProgress.positionSeconds);
        }
      } catch (_) {}
    }

    _currentChapterIndex = targetChapter;
    chapterIndexNotifier.value = _currentChapterIndex;

    if (book.chapters.isEmpty) return;

    await _playCurrentChapter(seekToPosition: targetPosition);
  }

  Future<void> _playCurrentChapter({Duration? seekToPosition}) async {
    if (_currentBook == null || _currentChapterIndex < 0 || _currentChapterIndex >= _currentBook!.chapters.length) {
      return;
    }

    final chapter = _currentBook!.chapters[_currentChapterIndex];
    stateNotifier.value = PlaybackState.loading;

    try {
      if (chapter.isStream || chapter.audioPathOrUrl.startsWith('http://') || chapter.audioPathOrUrl.startsWith('https://')) {
        await _player.setUrl(chapter.audioPathOrUrl);
      } else {
        final file = File(chapter.audioPathOrUrl);
        if (!await file.exists()) {
          stateNotifier.value = PlaybackState.error;
          return;
        }
        await _player.setFilePath(file.path);
      }

      await _player.setSpeed(_playbackSpeed);

      if (seekToPosition != null && seekToPosition > Duration.zero) {
        await _player.seek(seekToPosition);
      }

      await _player.play();
    } catch (e) {
      debugPrint('AudioPlaybackService: Failed to play chapter: $e');
      stateNotifier.value = PlaybackState.error;
    }
  }

  void _onChapterCompleted() {
    if (_currentBook != null && _currentChapterIndex < _currentBook!.chapters.length - 1) {
      nextChapter();
    } else {
      stateNotifier.value = PlaybackState.completed;
    }
  }

  Future<void> play() async => await _player.play();
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

  Future<void> skipForward({int seconds = 15}) async {
    final newPos = positionNotifier.value + Duration(seconds: seconds);
    final maxDur = durationNotifier.value;
    await seek(newPos > maxDur ? maxDur : newPos);
  }

  Future<void> skipBackward({int seconds = 15}) async {
    final newPos = positionNotifier.value - Duration(seconds: seconds);
    await seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> nextChapter() async {
    if (_currentBook != null && _currentChapterIndex < _currentBook!.chapters.length - 1) {
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
    await _player.setSpeed(speed);
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
    });

    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemaining != null && _sleepTimerRemaining!.inSeconds > 0) {
        _sleepTimerRemaining = _sleepTimerRemaining! - const Duration(seconds: 1);
        sleepTimerNotifier.value = _sleepTimerRemaining;
      } else {
        cancelSleepTimer();
      }
    });
  }

  void cancelSleepTimer() {
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

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/audio_playback_service.dart';

/// Behaves like just_audio during a load: `setUrl` reports "ready, not
/// playing" while the position is still 0, and only `seek` moves it.
class _ScriptedPlayer extends AudioPlayer {
  final _states = StreamController<PlayerState>.broadcast();
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  Stream<PlayerState> get playerStateStream => _states.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Duration get position => _position;
  @override
  bool get playing => _playing;

  @override
  Future<Duration?> setUrl(String url,
      {Map<String, String>? headers,
      Duration? initialPosition,
      bool preload = true,
      dynamic tag}) async {
    _position = Duration.zero;
    _states.add(PlayerState(false, ProcessingState.ready));
    await Future<void>.delayed(Duration.zero);
    return const Duration(hours: 1);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    _position = position ?? Duration.zero;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> pause() async {
    _playing = false;
    _states.add(PlayerState(false, ProcessingState.ready));
    await Future<void>.delayed(Duration.zero);
  }
}

UnifiedAudiobook _book(String id) => UnifiedAudiobook(
      id: id,
      title: id,
      author: 'A',
      description: '',
      source: 'LibriVox',
      origin: 'librivox',
      isDownloaded: false,
      chapters: [
        AudiobookChapter(
            id: '${id}_ch_0',
            title: 'One',
            audioPathOrUrl: 'https://example.org/$id.mp3',
            durationSeconds: 3600,
            isStream: true),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _ScriptedPlayer player;
  late AudioPlaybackService service;

  // Built in setUp, outside any FakeAsync zone (see
  // audio_playback_service_test.dart).
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    player = _ScriptedPlayer();
    service = AudioPlaybackService(player: player, db: db);
  });

  tearDown(() => db.close());

  test('restoring a book paused does not overwrite its saved place with 0',
      () async {
    final book = _book('emma');
    await db.saveAudiobook(book);
    await db.saveProgress(
        audiobookId: book.id, chapterIndex: 0, positionSeconds: 600);

    await service.loadBook(book, autoPlay: false);
    await Future<void>.delayed(Duration.zero);

    expect((await db.getProgress(book.id))!.positionSeconds, 600);
  });

  test('switching books does not save one book\'s position under the other',
      () async {
    final first = _book('emma');
    final second = _book('persuasion');
    await db.saveAudiobook(second);
    await db.saveProgress(
        audiobookId: second.id, chapterIndex: 0, positionSeconds: 50);

    await service.loadBook(first, autoPlay: false);
    await service.seek(const Duration(seconds: 900));
    await service.loadBook(second, autoPlay: false);
    await Future<void>.delayed(Duration.zero);

    expect((await db.getProgress(second.id))!.positionSeconds, 50);
  });

  test('a pause after the restore saves the real position', () async {
    final book = _book('emma');
    await db.saveAudiobook(book);
    await db.saveProgress(
        audiobookId: book.id, chapterIndex: 0, positionSeconds: 600);

    await service.loadBook(book, autoPlay: false);
    await service.seek(const Duration(seconds: 642));
    await service.pause();

    expect((await db.getProgress(book.id))!.positionSeconds, 642);
  });
}

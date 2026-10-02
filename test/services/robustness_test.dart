import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/librivox_downloader.dart';

class _SeekRecorder extends AudioPlayer {
  Duration? lastSeek;
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;
  @override
  bool get playing => false;
  @override
  Future<void> seek(Duration? position, {int? index}) async =>
      lastSeek = position;
}

UnifiedAudiobook _book(List<AudiobookChapter> chapters) => UnifiedAudiobook(
      id: 'odyssey',
      title: 'Odyssey',
      author: 'Homer',
      description: '',
      origin: BookIdentity.originLibrivox,
      chapters: chapters,
    );

AudiobookChapter _ch(String id) => AudiobookChapter(
    id: id, title: id, audioPathOrUrl: '/x/$id.mp3', durationSeconds: 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saveAudiobook', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('streaming then downloading leaves only the downloaded chapters',
        () async {
      await db.saveAudiobook(
          _book([_ch('odyssey_stream_0'), _ch('odyssey_stream_1')]));
      await db.saveAudiobook(
          _book([_ch('odyssey_local_0'), _ch('odyssey_local_1')]));

      final saved = await db.getAudiobook('odyssey');
      expect(saved!.chapters.map((c) => c.id),
          ['odyssey_local_0', 'odyssey_local_1']);
    });

    test('a save with no chapters keeps the ones already there', () async {
      await db.saveAudiobook(_book([_ch('odyssey_stream_0')]));
      await db.saveAudiobook(_book(const []));
      expect((await db.getAudiobook('odyssey'))!.chapters, hasLength(1));
    });
  });

  test('skipForward with the duration still unknown moves forward, not to 0',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final player = _SeekRecorder();
    final service = AudioPlaybackService(player: player, db: db);
    service.positionNotifier.value = const Duration(seconds: 100);
    service.durationNotifier.value = Duration.zero;

    await service.skipForward(seconds: 30);
    expect(player.lastSeek, const Duration(seconds: 130));

    service.durationNotifier.value = const Duration(seconds: 120);
    await service.skipForward(seconds: 30);
    expect(player.lastSeek, const Duration(seconds: 120));
    await db.close();
  });

  group('parseStreamableBook', () {
    final book = LibriVoxBook(
        id: '1',
        title: 'Odyssey',
        description: '',
        totalTimeSecs: 0,
        authors: const [],
        urlRss: 'https://librivox.org/rss/1',
        urlZipFile: '',
        urlIarchive: 'https://archive.org/details/odyssey',
        language: 'English',
        narrators: const []);

    test('an error response is ChaptersUnavailable, not an empty book',
        () async {
      final d = LibriVoxStreamAndDownloader(
          client: MockClient((_) async => http.Response('', 503)));
      await expectLater(
          d.parseStreamableBook(book), throwsA(isA<ChaptersUnavailable>()));
    });

    test('a network failure is ChaptersUnavailable', () async {
      final d = LibriVoxStreamAndDownloader(
          client:
              MockClient((_) async => throw http.ClientException('offline')));
      await expectLater(
          d.parseStreamableBook(book), throwsA(isA<ChaptersUnavailable>()));
    });

    test('a feed that loads with no items is still an empty book', () async {
      final d = LibriVoxStreamAndDownloader(
          client: MockClient((_) async => http.Response(
              '<?xml version="1.0"?><rss version="2.0"><channel>'
              '<title>t</title></channel></rss>',
              200)));
      expect((await d.parseStreamableBook(book)).chapters, isEmpty);
    });
  });
}

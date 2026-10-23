// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/core/utils/book_progress.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';

import '../support/test_harness.dart';

class _FakePlayer extends AudioPlayer {
  Duration at = const Duration(seconds: 100);
  final seeks = <Duration>[];
  bool started = false;

  @override
  Duration get position => at;
  @override
  bool get playing => false;
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add(position!);
    at = position;
  }

  @override
  Future<void> play() async => started = true;
  @override
  Future<Duration?> setUrl(String url,
          {Map<String, String>? headers,
          String? userAgent,
          bool preload = true,
          dynamic initialPosition,
          dynamic tag}) async =>
      null;
  @override
  Future<void> setSpeed(double speed) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resumePosition', () {
    Duration r(int pos, int pausedS, int back) => resumePosition(
        position: Duration(seconds: pos),
        pausedFor: Duration(seconds: pausedS),
        rewindSeconds: back);

    test('rewinds after a real pause, not a blip, and not when off', () {
      expect(r(100, 60, 10), const Duration(seconds: 90));
      expect(r(100, 3, 10), const Duration(seconds: 100));
      expect(r(100, 60, 0), const Duration(seconds: 100));
    });

    test('never goes before the chapter start', () {
      expect(r(4, 60, 30), Duration.zero);
    });
  });

  group('skip back on resume in the service', () {
    late _FakePlayer player;
    late Map<String, Object> prefs;
    late DateTime now;
    late AudioPlaybackService service;

    setUp(() {
      player = _FakePlayer();
      prefs = {};
      now = DateTime(2026, 1, 1, 12);
      service = AudioPlaybackService(
          player: player,
          preferences: UiPreferences(overrides: prefs),
          now: () => now);
    });

    tearDown(() => service.dispose().catchError((_) {}));

    test('default is 5 seconds after a long pause', () async {
      service.debugPausedAt(now.subtract(const Duration(minutes: 2)));
      await service.play();
      expect(player.seeks, [const Duration(seconds: 95)]);
      expect(player.started, isTrue);
    });

    test('uses the chosen amount and floors at zero', () async {
      prefs['playback.skip_back_on_resume'] = 'm30'; // unknown: default 5
      service.debugPausedAt(now.subtract(const Duration(minutes: 2)));
      await service.play();
      expect(player.seeks.single, const Duration(seconds: 95));

      prefs['playback.skip_back_on_resume'] = 's30';
      player.at = const Duration(seconds: 10);
      service.debugPausedAt(now.subtract(const Duration(minutes: 2)));
      await service.play();
      expect(player.seeks.last, Duration.zero);
    });

    test('off, a short pause, or no recorded pause leave the position',
        () async {
      prefs['playback.skip_back_on_resume'] = 'off';
      service.debugPausedAt(now.subtract(const Duration(minutes: 2)));
      await service.play();
      prefs['playback.skip_back_on_resume'] = 's10';
      service.debugPausedAt(now.subtract(const Duration(seconds: 2)));
      await service.play();
      await service.play();
      expect(player.seeks, isEmpty);
    });
  });

  group('auto-advance', () {
    late AppDatabase db;
    late Map<String, Object> prefs;
    late HiddenBooksStore hidden;
    late AudioPlaybackService service;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      prefs = {};
      hidden = HiddenBooksStore(overrides: <String, List<String>>{});
      service = AudioPlaybackService(
          player: _FakePlayer(),
          db: db,
          preferences: UiPreferences(overrides: prefs),
          hiddenStore: hidden);
      for (final id in ['a', 'b', 'c', 'd']) {
        await seedBook(db, id: id);
      }
    });

    tearDown(() async {
      await service.dispose().catchError((_) {});
      await db.close();
    });

    Future<String?> afterCompleting() async {
      await service.loadBook((await db.getAllAudiobooks()).first);
      service.debugCompleteChapter();
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (service.currentBookNotifier.value?.id != 'a') break;
      }
      return service.currentBookNotifier.value?.id;
    }

    test('stop is the default: the book just ends', () async {
      expect(await afterCompleting(), 'a');
    });

    test('next book skips finished and hidden books', () async {
      prefs['playback.auto_advance'] = 'nextBook';
      await db.markFinished('b', lastChapterIndex: 0);
      await hidden.hide('c');
      expect(await afterCompleting(), 'd');
      expect((await db.getProgress('a'))?.positionSeconds,
          AppDatabase.finishedPositionSeconds);
    });

    test('with nothing left it stops on the finished book', () async {
      prefs['playback.auto_advance'] = 'nextBook';
      await db.markFinished('b', lastChapterIndex: 0);
      await db.markFinished('c', lastChapterIndex: 0);
      await db.markFinished('d', lastChapterIndex: 0);
      expect(await afterCompleting(), 'a');
    });
  });

  group('skip back when a started book is loaded', () {
    late AppDatabase db;
    late _FakePlayer player;
    late AudioPlaybackService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      player = _FakePlayer();
      service = AudioPlaybackService(
          player: player,
          db: db,
          preferences: UiPreferences(overrides: <String, Object>{}),
          hiddenStore: HiddenBooksStore(overrides: <String, List<String>>{}));
    });

    tearDown(() async {
      await service.dispose().catchError((_) {});
      await db.close();
    });

    test('resume by Play rewinds the saved position', () async {
      final book = await seedBook(db, id: 'r', positionSeconds: 100);
      await service.loadBook(book);
      expect(player.seeks, [const Duration(seconds: 95)]);
    });

    test('the first play after a relaunch rewinds', () async {
      final book = await seedBook(db, id: 'r', positionSeconds: 100);
      await service.loadBook(book, autoPlay: false);
      expect(player.seeks, [const Duration(seconds: 100)]);
      await service.play();
      expect(player.seeks.last, const Duration(seconds: 95));
    });

    test('a fresh start does not rewind', () async {
      final book = await seedBook(db, id: 'f');
      await service.loadBook(book);
      expect(player.seeks, isEmpty);
      await service.loadBook(book, autoPlay: false);
      await service.play();
      expect(player.seeks, isEmpty);
    });

    test('a jump (bookmark or chapter) does not rewind', () async {
      final book = await seedBook(db, id: 'j', positionSeconds: 100);
      await service.loadBook(book,
          initialChapterIndex: 0, initialPosition: const Duration(seconds: 50));
      expect(player.seeks, [const Duration(seconds: 50)]);
      await service.loadBook(book, initialChapterIndex: 0);
      expect(player.seeks, hasLength(1));
    });

    test('never rewinds before the chapter start', () async {
      final book = await seedBook(db, id: 'c', positionSeconds: 3);
      await service.loadBook(book);
      expect(player.seeks, isEmpty); // resumed at 0, the chapter start
    });
  });

  test('settings persist by name; unknown values fall back', () async {
    final store = <String, Object>{};
    final s = AppSettings(preferences: UiPreferences(overrides: store));
    await s.setSkipBackOnResume(SkipBackOnResume.s30);
    await s.setAutoAdvance(AutoAdvance.nextBook);
    expect(store['playback.skip_back_on_resume'], 's30');
    expect(store['playback.auto_advance'], 'nextBook');

    final bad = AppSettings(
        preferences: UiPreferences(overrides: {
      'playback.skip_back_on_resume': '3',
      'playback.auto_advance': 'shuffle',
    }));
    await bad.load();
    expect(bad.skipBackOnResume, SkipBackOnResume.s5);
    expect(bad.autoAdvance, AutoAdvance.stop);
  });
}

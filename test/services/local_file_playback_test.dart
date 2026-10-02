import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/services/local_file_playback_io.dart';

/// Captures the [AudioSource] passed to [setAudioSource] instead of
/// touching a real platform channel — same technique as
/// `audio_playback_service_test.dart`'s `_RefusingPlayer`.
class _CapturingPlayer extends AudioPlayer {
  AudioSource? lastSource;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    lastSource = source;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String filePath;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('local_file_playback_test_');
    filePath = p.join(tempDir.path, 'chapter.m4b');
    await File(filePath).writeAsBytes([0, 1, 2, 3], flush: true);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a whole-file chapter (no start/end) loads a plain file source',
      () async {
    final player = _CapturingPlayer();

    final loaded = await playLocalFile(player, filePath);

    expect(loaded, isTrue);
    expect(player.lastSource, isA<UriAudioSource>());
    expect(player.lastSource, isNot(isA<ClippingAudioSource>()));
  });

  test(
      'a chapter with start/end reaches the player as a ClippingAudioSource '
      'with exactly that range', () async {
    final player = _CapturingPlayer();

    final loaded = await playLocalFile(
      player,
      filePath,
      start: const Duration(milliseconds: 12345),
      end: const Duration(milliseconds: 67890),
    );

    expect(loaded, isTrue);
    final source = player.lastSource;
    expect(source, isA<ClippingAudioSource>());
    final clip = source as ClippingAudioSource;
    expect(clip.start, equals(const Duration(milliseconds: 12345)));
    expect(clip.end, equals(const Duration(milliseconds: 67890)));
    expect(clip.child, isA<UriAudioSource>());
    expect((clip.child).uri, equals(Uri.file(filePath)));
  });

  test('an open-ended end (last chapter of a file) is passed through as null',
      () async {
    final player = _CapturingPlayer();

    await playLocalFile(
      player,
      filePath,
      start: const Duration(milliseconds: 5000),
      end: null,
    );

    final clip = player.lastSource as ClippingAudioSource;
    expect(clip.start, equals(const Duration(milliseconds: 5000)));
    expect(clip.end, isNull);
  });

  test('a missing file returns false without touching the player', () async {
    final player = _CapturingPlayer();
    final missingPath = p.join(tempDir.path, 'does_not_exist.m4b');

    final loaded = await playLocalFile(player, missingPath);

    expect(loaded, isFalse);
    expect(player.lastSource, isNull);
  });
}

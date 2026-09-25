import 'dart:io';
import 'package:just_audio/just_audio.dart';

/// Loads a local file into [player]. Returns false (without touching
/// [player]) if the file does not exist, so the caller can surface a
/// playback error instead of throwing.
///
/// [start]/[end] bound the chapter within [path] rather than the whole
/// file — used for a chapter that is a marker inside a shared M4B rather
/// than its own file (see `core/utils/mp4_chapters.dart` and
/// `AudiobookChapter.startMs`/`endMs`). When both are `null` (the common
/// case) the whole file is loaded exactly as before; passing either wraps
/// the source in a [ClippingAudioSource], after which positions/durations
/// reported by [player] are relative to the clip, not the underlying file.
Future<bool> playLocalFile(
  AudioPlayer player,
  String path, {
  Duration? start,
  Duration? end,
}) async {
  final file = File(path);
  if (!await file.exists()) return false;

  final fileSource = AudioSource.file(file.path);
  if (start == null && end == null) {
    await player.setAudioSource(fileSource);
  } else {
    await player.setAudioSource(
      ClippingAudioSource(child: fileSource, start: start, end: end),
    );
  }
  return true;
}

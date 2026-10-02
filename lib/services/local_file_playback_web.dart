import 'package:just_audio/just_audio.dart';

/// The web build has no local filesystem, and the canned web demo is
/// streaming-only (see rework_plan.md), so local-file chapter playback is
/// never expected here. Always reports failure rather than touching
/// dart:io, which does not compile on web. [start]/[end] are accepted for
/// signature parity with `local_file_playback_io.dart` and simply ignored.
Future<bool> playLocalFile(
  AudioPlayer player,
  String path, {
  Duration? start,
  Duration? end,
}) async {
  return false;
}

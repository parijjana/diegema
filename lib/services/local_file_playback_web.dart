import 'package:just_audio/just_audio.dart';

/// The web build has no local filesystem, and the canned web demo is
/// streaming-only (see rework_plan.md), so local-file chapter playback is
/// never expected here. Always reports failure rather than touching
/// dart:io, which does not compile on web.
Future<bool> playLocalFile(AudioPlayer player, String path) async {
  return false;
}

import 'dart:io';
import 'package:just_audio/just_audio.dart';

/// Loads a local file into [player]. Returns false (without touching
/// [player]) if the file does not exist, so the caller can surface a
/// playback error instead of throwing.
Future<bool> playLocalFile(AudioPlayer player, String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  await player.setFilePath(file.path);
  return true;
}

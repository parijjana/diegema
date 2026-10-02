import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Asks for read access to audio in shared storage, which a library folder
/// outside the app's own storage needs: `READ_MEDIA_AUDIO` on Android 13+,
/// `READ_EXTERNAL_STORAGE` below that. Read-only — Diegema never asks to
/// write there. Other platforms grant access through the folder picker
/// itself, so this is a no-op there.
Future<bool> ensureAudioReadAccess() async {
  if (!Platform.isAndroid) return true;
  final statuses = await [Permission.audio, Permission.storage].request();
  return statuses.values.any((s) => s.isGranted || s.isLimited);
}

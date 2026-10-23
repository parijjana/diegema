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

/// Whether shared-storage audio is readable right now, without asking.
/// After a reinstall Android restores the library (database and settings)
/// but not the permission, and files in shared storage that the old install
/// wrote are no longer "owned": they read as missing until it is granted
/// again. Always true off Android.
Future<bool> hasAudioReadAccess() async {
  if (!Platform.isAndroid) return true;
  for (final permission in [Permission.audio, Permission.storage]) {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;
  }
  return false;
}

/// Asks again, or — once Android has stopped showing the dialog (denied
/// twice) — opens the app's system settings page so it can be granted there.
/// Returns whether access is granted afterwards.
Future<bool> requestAudioReadAccessOrOpenSettings() async {
  if (await ensureAudioReadAccess()) return true;
  if (await Permission.audio.isPermanentlyDenied ||
      await Permission.storage.isPermanentlyDenied) {
    await openAppSettings();
  }
  return false;
}

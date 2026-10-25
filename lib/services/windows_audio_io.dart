import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// Gives just_audio a Windows backend (media_kit, libmpv). Call once in
/// `main()`, before any `AudioPlayer` is made. A no-op elsewhere: Android,
/// iOS and macOS keep just_audio's own implementations.
void initWindowsAudio() {
  if (!Platform.isWindows) return;
  JustAudioMediaKit.ensureInitialized(linux: false, windows: true);
}

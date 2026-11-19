import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path/path.dart' as p;

/// libmpv does not verify HTTPS certificates by default, and with verification
/// on it needs a root list; windows/CMakeLists.txt installs one beside the
/// exe's data files. If that file is missing, streaming fails rather than
/// running unverified.
@visibleForTesting
Map<String, String> windowsMpvProperties(String executablePath) => {
  'tls-verify': 'yes',
  'tls-ca-file': p.join(p.dirname(executablePath), 'data', 'cacert.pem'),
};

/// Protocols libmpv/FFmpeg may open. `http` is deliberately absent: the first
/// URL is already https-only (url_policy.dart), but FFmpeg follows redirects
/// itself and checks each hop against this list, so a redirect to `http://`
/// is refused instead of played in cleartext (audit S-11). `udp`, `rtp` and
/// `crypto` are not needed for LibriVox/archive.org or local files either.
@visibleForTesting
const List<String> windowsProtocolWhitelist = [
  'tcp',
  'tls',
  'https',
  'file',
  'data',
];

/// Gives just_audio a Windows backend (media_kit, libmpv). Call once in
/// `main()`, before any `AudioPlayer` is made. A no-op elsewhere: Android,
/// iOS and macOS keep just_audio's own implementations.
void initWindowsAudio() {
  if (!Platform.isWindows) return;
  JustAudioMediaKit.protocolWhitelist = windowsProtocolWhitelist;
  JustAudioMediaKit.mpvProperties = windowsMpvProperties(
    Platform.resolvedExecutable,
  );
  JustAudioMediaKit.ensureInitialized(linux: false, windows: true);
}

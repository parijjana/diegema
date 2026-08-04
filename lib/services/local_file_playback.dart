/// Platform seam for playing a chapter whose `audioPathOrUrl` is a local
/// filesystem path rather than a stream URL. Isolated into its own
/// conditional-export file because it is the only part of
/// `AudioPlaybackService` that touches `dart:io`, which does not compile
/// for web.
library;

export 'local_file_playback_io.dart'
    if (dart.library.html) 'local_file_playback_web.dart';

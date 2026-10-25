/// Platform seam for audio on Windows, where just_audio has no
/// implementation of its own. See `windows_audio_io.dart`.
library;

export 'windows_audio_io.dart' if (dart.library.html) 'windows_audio_web.dart';

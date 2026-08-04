/// Platform seam for importing local audio files/folders into the library.
/// The io implementation reads real filesystem paths with `dart:io`. The
/// web build has no comparable concept (file_picker on web hands back
/// bytes, not paths, and there is nowhere durable to store them for this
/// demo), so the web implementation just informs the user this feature is
/// desktop-only.
library;

export 'local_audiobook_import_io.dart'
    if (dart.library.html) 'local_audiobook_import_web.dart';

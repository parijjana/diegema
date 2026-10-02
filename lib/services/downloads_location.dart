/// Platform seam for where Discover downloads are saved — a user-visible
/// folder on Android 11+, macOS and Windows, app-private elsewhere. See
/// `downloads_location_io.dart`.
library;

export 'downloads_location_io.dart'
    if (dart.library.html) 'downloads_location_web.dart';

/// Platform seam for library locations (folders read in place). The io
/// implementation walks the folders; the web build has no local folders.
library;

export 'library_locations_scanner_io.dart'
    if (dart.library.html) 'library_locations_scanner_web.dart';

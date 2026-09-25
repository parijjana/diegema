/// Platform seam for rendering a cover image from a local filesystem path
/// (as opposed to a network URL) — see `book_cover_image.dart`. Local
/// import only exists on IO platforms (`local_audiobook_import.dart`), so
/// the web build never has a real local path to render; its implementation
/// just defers to the caller's error builder.
library;

export 'local_file_image_io.dart'
    if (dart.library.html) 'local_file_image_web.dart';

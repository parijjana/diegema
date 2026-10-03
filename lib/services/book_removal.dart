/// Platform seam for removing a book from the library, including the files
/// the app owns. The web build has no on-disk files, so it only drops rows.
library;

export 'book_removal_io.dart' if (dart.library.html) 'book_removal_web.dart';

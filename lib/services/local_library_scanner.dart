/// Platform seam for scanning the on-disk "downloads" folder that
/// `BookDetailPane`'s ZIP download writes into, and registering any books
/// found there in [AppDatabase]. `LibraryView` calls `scanDownloadedLibrary`
/// on every load; the io implementation does the real `dart:io` directory
/// walk, the web implementation is a no-op (the web demo never downloads
/// anything to a local "downloads" folder — see rework_plan.md).
library;

export 'local_library_scanner_io.dart'
    if (dart.library.html) 'local_library_scanner_web.dart';

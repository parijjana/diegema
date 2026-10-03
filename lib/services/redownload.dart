/// Platform seam for fetching a downloaded book again when its files can't
/// be read. See `redownload_io.dart`.
library;

export 'redownload_io.dart' if (dart.library.html) 'redownload_web.dart';

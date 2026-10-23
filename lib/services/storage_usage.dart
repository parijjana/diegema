/// Platform seam for Settings > Storage: measuring what Diegema keeps on the
/// device and clearing its caches. The web demo has no files.
library;

export 'storage_usage_io.dart' if (dart.library.html) 'storage_usage_web.dart';

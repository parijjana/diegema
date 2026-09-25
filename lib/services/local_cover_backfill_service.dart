/// Platform seam for [LocalCoverBackfillService] — step 4 of the
/// local-import cover pipeline. The io implementation re-derives each
/// candidate book's file paths and re-runs the embedded-metadata/
/// folder-image/online-lookup pipeline; the web build has no local books
/// to backfill at all (see `local_audiobook_import_web.dart`), so its
/// implementation is a no-op.
library;

export 'local_cover_backfill_service_io.dart'
    if (dart.library.html) 'local_cover_backfill_service_web.dart';

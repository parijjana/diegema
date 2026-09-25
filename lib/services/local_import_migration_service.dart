/// Platform seam for [LocalImportMigrationService] — the once-per-launch
/// migration (run before the cover backfill; see `app.dart`'s
/// `runImportMigration` gate) that copies already-imported local books'
/// chapter files into `diegema/library/<bookId>/` when they still point
/// somewhere else (most commonly file_picker's Android cache dir — see
/// `local_audiobook_storage_io.dart`). The web build has no local books to
/// migrate at all (see `local_audiobook_import_web.dart`), so its
/// implementation is a no-op.
library;

export 'local_import_migration_service_io.dart'
    if (dart.library.html) 'local_import_migration_service_web.dart';

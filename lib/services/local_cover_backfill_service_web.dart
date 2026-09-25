import '../database/app_database.dart';
import 'backfill_attempt_store.dart';

/// Local import doesn't exist on the web build (see
/// `services/local_audiobook_import_web.dart`), so there are never any
/// `origin: local` books to backfill a cover for — this is a no-op kept
/// only so `app.dart` can call it unconditionally on every platform.
class LocalCoverBackfillService {
  LocalCoverBackfillService({
    required AppDatabase db,
    BackfillAttemptStore? store,
    Object? lookupService,
    DateTime Function()? now,
  });

  Future<void> run() async {}
}

import '../database/app_database.dart';

/// Local import doesn't exist on the web build (see
/// `services/local_audiobook_import_web.dart`), so there are never any
/// on-disk chapter paths to migrate — this is a no-op kept only so
/// `app.dart` can call it unconditionally on every platform.
class LocalImportMigrationService {
  const LocalImportMigrationService({required AppDatabase db});

  Future<void> run() async {}
}

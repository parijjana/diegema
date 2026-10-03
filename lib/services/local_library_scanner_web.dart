import '../database/app_database.dart';
import 'library_locations_store.dart';
import 'downloads_location_web.dart';

/// Kept signature-compatible with the io implementation so callers — and
/// the conditional export in `local_library_scanner.dart` — never have to
/// care which one they got.
typedef DocumentsRootResolver = Future<String?> Function();

/// The web demo never writes a local "downloads" folder (there is no
/// filesystem to write to, and the demo is streaming-only), so there is
/// nothing to scan.
Future<void> scanDownloadedLibrary(
  AppDatabase db, {
  DocumentsRootResolver? documentsRoot,
  DownloadsLocation? downloads,
  LibraryLocationsStore locations = const LibraryLocationsStore(),
}) async {}

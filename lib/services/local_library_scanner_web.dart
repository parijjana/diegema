import '../database/app_database.dart';

/// The web demo never writes a local "downloads" folder (there is no
/// filesystem to write to, and the demo is streaming-only), so there is
/// nothing to scan.
Future<void> scanDownloadedLibrary(AppDatabase db) async {}

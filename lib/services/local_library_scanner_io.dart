import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'downloads_location_io.dart';
import 'library_locations_scanner_io.dart';
import 'library_locations_store.dart';

/// Resolves the directory the app keeps its data in. Returning `null` means
/// "there is no documents directory here", and the scan is skipped rather
/// than throwing.
///
/// Injectable so the scan itself can be exercised against a temp directory
/// in tests. The default implementation goes through `path_provider`, whose
/// platform channel does not exist under `flutter_test` — calling it there
/// used to throw `MissingPluginException` on every run and print a
/// "scan failed" line from `LibraryScreen`.
typedef DocumentsRootResolver = Future<String?> Function();

/// Scans every downloads root (`DownloadsLocation.all`: the user-visible
/// folder and the app-private one `BookDetailPane`'s ZIP downloader used to
/// write into), then every library
/// location the user added (read in place — see
/// `library_locations_scanner_io.dart`), and registers any not-yet-known
/// books in [db].
Future<void> scanDownloadedLibrary(
  AppDatabase db, {
  DocumentsRootResolver? documentsRoot,
  DownloadsLocation? downloads,
  LibraryLocationsStore locations = const LibraryLocationsStore(),
}) async {
  final location = downloads ?? DownloadsLocation(documentsRoot: documentsRoot);
  for (final root in await location.all()) {
    await _scanDownloads(db, root);
  }
  await scanLibraryLocations(db, store: locations);
}

Future<void> _scanDownloads(AppDatabase db, String root) async {
  final downloadsDir = Directory(root);

  if (!await downloadsDir.exists()) return;

  final List<FileSystemEntity> entities = await downloadsDir.list().toList();

  // A Discover download lands in this same directory but is saved under
  // its archive.org id, not the path hash below. Without this map the scan
  // re-registered every such download as a second "Downloaded Audiobook".
  final owners = <String, String>{};
  for (final book in await db.getAllAudiobooks()) {
    if (book.id.startsWith(BookIdentity.localIdPrefix)) continue;
    for (final ch in book.chapters) {
      if (ch.isStream) continue;
      owners.putIfAbsent(
          p.normalize(p.dirname(ch.audioPathOrUrl)), () => book.id);
    }
  }
  for (final entity in entities) {
    if (entity is! Directory) continue;
    try {
      await _registerDownloadFolder(db, entity, owners);
    } catch (e) {
      // One unreadable folder must not cost the rest of the scan.
      debugPrint('Downloads scan: skipped ${entity.path}: $e');
    }
  }
}

Future<void> _registerDownloadFolder(
  AppDatabase db,
  Directory entity,
  Map<String, String> owners,
) async {
  final folderName = p.basename(entity.path);
  final mp3Files = entity
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.mp3'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (mp3Files.isEmpty) return;

  // Deterministic sha256-of-path id — NOT hashCode (see
  // core/utils/book_identity.dart).
  final bookId = BookIdentity.localIdForPath(entity.path);
  final existing = await db.getAudiobook(bookId);

  // Another book already owns this folder: drop a duplicate an earlier
  // scan made, unless the user has since listened to or bookmarked it.
  if (owners.containsKey(p.normalize(entity.path))) {
    if (existing != null &&
        await db.getProgress(bookId) == null &&
        (await db.getBookmarks(bookId)).isEmpty) {
      await db.deleteAudiobook(bookId);
    }
    return;
  }
  if (existing != null) return;

  final chapters = mp3Files.asMap().entries.map((e) {
    final idx = e.key;
    final file = e.value;
    final name = p.basename(file.path).replaceAll('.mp3', '');
    return AudiobookChapter(
      id: '${bookId}_ch_$idx',
      title: name,
      audioPathOrUrl: file.path,
      durationSeconds: 0,
      isStream: false,
    );
  }).toList();

  final book = UnifiedAudiobook(
    id: bookId,
    title: folderName.replaceAll('_', ' '),
    author: 'Downloaded Audiobook',
    description: 'Downloaded to local storage.',
    source: 'Local Storage',
    origin: BookIdentity.originLocal,
    chapters: chapters,
    isDownloaded: true,
  );
  await db.saveAudiobook(book);
}

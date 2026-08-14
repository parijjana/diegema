import 'dart:io';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';

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

Future<String?> _platformDocumentsRoot() async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } on MissingPluginException {
    return null;
  }
}

/// Scans `<documents root>/diegema/downloads` (the directory
/// `BookDetailPane`'s ZIP downloader writes into) and registers any
/// not-yet-known book folders in [db].
Future<void> scanDownloadedLibrary(
  AppDatabase db, {
  DocumentsRootResolver? documentsRoot,
}) async {
  final rootPath = await (documentsRoot ?? _platformDocumentsRoot)();
  if (rootPath == null) return;

  final downloadsDir =
      Directory(p.join(rootPath, 'diegema', 'downloads'));

  if (!await downloadsDir.exists()) return;

  final List<FileSystemEntity> entities = await downloadsDir.list().toList();
  for (final entity in entities) {
    if (entity is! Directory) continue;

    final folderName = p.basename(entity.path);
    final mp3Files = entity
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mp3'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (mp3Files.isEmpty) continue;

    // Deterministic sha256-of-path id — NOT hashCode (see
    // core/utils/book_identity.dart).
    final bookId = BookIdentity.localIdForPath(entity.path);
    final existing = await db.getAudiobook(bookId);
    if (existing != null) continue;

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
}

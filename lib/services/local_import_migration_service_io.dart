import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'local_audiobook_storage_io.dart';

/// Once per app launch, before the cover backfill (see `app.dart`'s
/// `runImportMigration` gate), migrates already-imported local books whose
/// chapter files still live outside `diegema/library/<bookId>/` — imports
/// made before `local_audiobook_storage_io.dart` existed stored file_picker's
/// raw picked path, which on Android is inside the app's cache dir and can
/// be cleared by the OS at any time — into that durable directory, and
/// rewrites the affected chapter rows to point at the copies.
///
/// Chapter ids, `startMs`/`endMs` offsets, playback progress and bookmarks
/// are all keyed independently of the path and are left untouched. A
/// chapter whose file no longer exists is logged and left exactly as it
/// was — its row is never modified or deleted. Never throws: a failure
/// migrating one book (or one file) is logged and the run moves on to the
/// next, rather than aborting.
class LocalImportMigrationService {
  final AppDatabase db;

  const LocalImportMigrationService({required this.db});

  Future<void> run() async {
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final libraryRoot = p.join(appDocs.path, 'diegema', 'library');

      final books = await db.getAllAudiobooks();
      for (final book in books) {
        if (book.origin != BookIdentity.originLocal) continue;
        await _migrateBook(book.id, libraryRoot, book.chapters);
      }
    } catch (e) {
      developer.log('run failed: $e', name: 'LocalImportMigrationService');
    }
  }

  Future<void> _migrateBook(
    String bookId,
    String libraryRoot,
    List<AudiobookChapter> chapters,
  ) async {
    final bookLibraryDir = Directory(p.join(libraryRoot, bookId));

    // Every filename already placed into this book's library dir by a
    // prior run (or by copy-on-import), so a same-book collision during
    // migration still gets a numeric suffix rather than an overwrite.
    final usedNames = <String>{};
    if (await bookLibraryDir.exists()) {
      await for (final entity in bookLibraryDir.list()) {
        if (entity is File) usedNames.add(p.basename(entity.path).toLowerCase());
      }
    }

    // One copy per distinct source path, even if several chapters (M4B
    // chapter markers) share the same file.
    final pathMap = <String, String>{};

    for (final chapter in chapters) {
      final path = chapter.audioPathOrUrl;
      if (path.startsWith('http://') || path.startsWith('https://')) continue;
      if (isUnderDirectory(path, bookLibraryDir.path)) continue;

      String? newPath = pathMap[path];
      if (newPath == null) {
        if (!await File(path).exists()) {
          developer.log(
              'skipping missing file for book $bookId, chapter '
              '${chapter.id}: $path',
              name: 'LocalImportMigrationService');
          continue;
        }
        try {
          await bookLibraryDir.create(recursive: true);
          newPath = await copyFileIntoDirectory(path, bookLibraryDir, usedNames);
          pathMap[path] = newPath;
        } catch (e) {
          developer.log(
              'failed to migrate file for book $bookId, chapter '
              '${chapter.id}: $path ($e)',
              name: 'LocalImportMigrationService');
          continue;
        }
      }

      await db.updateChapterAudioPath(chapter.id, newPath);
    }
  }
}

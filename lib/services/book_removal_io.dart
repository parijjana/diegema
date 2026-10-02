import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'downloads_location_io.dart';
import 'library_locations_scanner_io.dart' show kLibraryLocationSource;
import 'removed_books_store.dart';

/// What removing a book would do to files, computed without modifying
/// anything (used both by the confirm dialog and by [removeBook]).
class BookRemovalPlan {
  /// Absolute app-owned paths (files or directories) that will be deleted.
  final List<String> deletePaths;

  /// Total size of [deletePaths] in bytes.
  final int bytes;

  /// True for a book read from a library folder: its audio files are never
  /// touched and the book is hidden from future scans instead.
  final bool filesUntouched;

  const BookRemovalPlan(
      {this.deletePaths = const [],
      this.bytes = 0,
      this.filesUntouched = false});
}

/// Works out which files [book] owns. Every candidate must lie strictly
/// inside a downloads root (`DownloadsLocation.all`) or
/// `<documents>/diegema/{library,covers}` after normalisation
/// (`p.isWithin`), otherwise it is ignored - whatever the DB says.
/// [documentsPath] overrides the platform documents directory and
/// [downloads] the downloads roots (tests).
Future<BookRemovalPlan> planBookRemoval(UnifiedAudiobook book,
    {String? documentsPath, DownloadsLocation? downloads}) async {
  final docs = documentsPath ?? (await getApplicationDocumentsDirectory()).path;
  final root = p.normalize(p.join(docs, 'diegema'));
  final downloadRoots =
      await _location(downloads, documentsPath: documentsPath).all();
  final library = p.join(root, 'library');
  final covers = p.join(root, 'covers');
  final fromFolder = book.source == kLibraryLocationSource;

  final targets = <String>{};

  void addIfOwned(String candidate, String zone) {
    final c = p.normalize(candidate);
    if (p.isAbsolute(c) && p.isWithin(zone, c)) targets.add(c);
  }

  if (!fromFolder) {
    for (final ch in book.chapters) {
      if (ch.isStream) continue;
      final path = p.normalize(ch.audioPathOrUrl);
      if (!p.isAbsolute(path)) continue;
      // The book's own directory: the first level below the zone root.
      for (final zone in [...downloadRoots, library]) {
        if (p.isWithin(zone, path)) {
          final first = p.split(p.relative(path, from: zone)).first;
          addIfOwned(p.join(zone, first), zone);
        }
      }
    }
    final id = book.id;
    if (id.isNotEmpty && p.basename(id) == id && id != '.' && id != '..') {
      addIfOwned(p.join(library, id), library);
    }
  }

  final cover = book.coverArtUrlOrPath;
  if (cover != null && cover.isNotEmpty && !cover.contains('://')) {
    addIfOwned(cover, covers);
  }

  // Drop nested duplicates (a path inside a directory already listed).
  final paths = targets
      .where((t) => !targets.any((o) => o != t && p.isWithin(o, t)))
      .toList()
    ..sort();

  var bytes = 0;
  final existing = <String>[];
  for (final path in paths) {
    final size = await _sizeOf(path);
    if (size == null) continue;
    existing.add(path);
    bytes += size;
  }
  return BookRemovalPlan(
      deletePaths: existing, bytes: bytes, filesUntouched: fromFolder);
}

DownloadsLocation _location(DownloadsLocation? given,
        {String? documentsPath}) =>
    given ??
    DownloadsLocation(
        documentsRoot: documentsPath == null ? null : () async => documentsPath);

Future<int?> _sizeOf(String path) async {
  try {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type == FileSystemEntityType.directory) {
      var total = 0;
      await for (final e
          in Directory(path).list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
      return total;
    }
    if (type == FileSystemEntityType.file) return await File(path).length();
    return 0; // a link: removing it frees nothing
  } catch (_) {
    return null;
  }
}

/// Removes [book] from the library: DB rows, progress and bookmarks, plus
/// the app-owned files from [planBookRemoval]. A library-folder book keeps
/// its files and is recorded in [removedStore] so rescans skip it. Returns
/// the bytes freed.
Future<int> removeBook(AppDatabase db, UnifiedAudiobook book,
    {String? documentsPath,
    DownloadsLocation? downloads,
    RemovedBooksStore removedStore = const RemovedBooksStore()}) async {
  final location = _location(downloads, documentsPath: documentsPath);
  final plan = await planBookRemoval(book,
      documentsPath: documentsPath, downloads: location);
  var freed = 0;
  final refused = <String>[];
  for (final path in plan.deletePaths) {
    final size = await _sizeOf(path) ?? 0;
    if (await _delete(path)) {
      freed += size;
    } else {
      refused.add(path);
    }
  }
  // Android: files an earlier install wrote to the shared Audiobooks folder
  // are no longer Diegema's, and only a system dialog can delete them.
  final visible = await location.userVisibleRoot();
  final shared = visible == null
      ? const <String>[]
      : refused.where((r) => p.isWithin(visible, r)).toList();
  if (shared.isNotEmpty) {
    final files = <String>[];
    for (final path in shared) {
      files.addAll(await _filesUnder(path));
    }
    if (await location.requestMediaDelete(files)) {
      for (final path in shared) {
        final size = await _sizeOf(path) ?? 0;
        // The files are gone now; only an emptied directory may remain.
        await _delete(path);
        freed += size;
      }
    }
  }
  if (plan.filesUntouched) await removedStore.add(book.id);
  await db.deleteAudiobookAndUserData(book.id);
  return freed;
}

/// Deletes [path] (a file or a whole directory); false if anything stayed.
Future<bool> _delete(String path) async {
  try {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
    return true;
  } catch (_) {
    // Best-effort: a locked file must not stop the book being removed.
    return false;
  }
}

Future<List<String>> _filesUnder(String path) async {
  try {
    if (await FileSystemEntity.isFile(path)) return [path];
    return await Directory(path)
        .list(recursive: true, followLinks: false)
        .where((e) => e is File)
        .map((f) => f.path)
        .toList();
  } catch (_) {
    return const [];
  }
}

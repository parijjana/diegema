import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'downloads_location_io.dart';
import 'library_locations_store.dart';
import 'removed_books_store.dart';
import 'local_audiobook_import_io.dart' show chaptersForFiles;
import 'local_book_metadata_io.dart';

/// Shown as the book's source, and how [booksInLocation] recognises a book
/// that came from a library location rather than a copied import.
const String kLibraryLocationSource = 'Library folder';

const _audioExtensions = {
  '.mp3', '.m4a', '.m4b', '.aac', '.flac', '.wav', '.ogg', //
};

/// How deep below a location to look for book folders. Enough for
/// `Audiobooks/Author/Title/`, shallow enough that pointing at the root of
/// shared storage doesn't walk the whole device.
const int _maxDepth = 4;

/// Reads every library location and registers any book not yet known.
/// Returns the number of new books.
///
/// **Read-only by design:** files stay where they are and nothing is written
/// inside a location. Chapters point at the original paths; an embedded
/// cover is saved under the app's own `diegema/covers/`, and a folder cover
/// image is referenced in place.
///
/// A book is either a folder holding audio files (all of them, in name
/// order, one book), or — when a folder holds nothing but two or more
/// `.m4b` files — one book per `.m4b`. Unreadable folders are skipped, and
/// so are Diegema's own downloads roots: a location such as the shared
/// Audiobooks folder contains `Audiobooks/Diegema/`, whose books the
/// downloads scan already owns.
Future<int> scanLibraryLocations(
  AppDatabase db, {
  LibraryLocationsStore store = const LibraryLocationsStore(),
  String? only,
  RemovedBooksStore removedStore = const RemovedBooksStore(),
  DownloadsLocation downloads = const DownloadsLocation(),
}) async {
  final removed = await removedStore.read();
  final locations = only != null ? [only] : await store.read();
  final skip = await downloads.all();
  await _forgetDownloadsReadAsFolders(db, skip);
  var added = 0;
  for (final location in locations) {
    // Unreachable (unplugged drive, access not granted this run): leave its
    // books alone, they come back with the folder.
    if (!await Directory(location).exists()) continue;
    await _forgetVanishedBooks(db, location);
    for (final candidate in await _findBooks(Directory(location), skip)) {
      if (removed.contains(candidate.id)) continue;
      try {
        if (await db.getAudiobook(candidate.id) != null) continue;
        await db.saveAudiobook(await _buildBook(candidate));
        added++;
      } catch (e) {
        // One unreadable book must not cost the rest of the scan.
        debugPrint('Library folder: skipped ${candidate.keyPath}: $e');
      }
    }
  }
  return added;
}

/// Forgets books from [location] with a file that no longer exists (moved,
/// renamed or deleted outside Diegema), keeping their progress the way
/// removing a folder does. If the folder still holds the book, the scan
/// that follows adds it back as it is now, under the same id.
Future<void> _forgetVanishedBooks(AppDatabase db, String location) async {
  for (final id in await booksInLocation(db, location)) {
    final book = await db.getAudiobook(id);
    if (book == null) continue;
    final files = {for (final ch in book.chapters) ch.audioPathOrUrl};
    for (final file in files) {
      if (!await File(file).exists()) {
        await db.deleteAudiobook(id);
        break;
      }
    }
  }
}

/// Drops library-folder rows an earlier scan made from inside a downloads
/// root (duplicates of the downloaded books). Progress rows stay.
Future<void> _forgetDownloadsReadAsFolders(
    AppDatabase db, List<String> roots) async {
  if (roots.isEmpty) return;
  for (final book in await db.getAllAudiobooks()) {
    if (book.source != kLibraryLocationSource || book.chapters.isEmpty) {
      continue;
    }
    final path = book.chapters.first.audioPathOrUrl;
    if (roots.any((r) => p.isWithin(r, path))) {
      await db.deleteAudiobook(book.id);
    }
  }
}

/// Ids of the books that were read from [location], for forgetting them
/// when the location is removed.
Future<List<String>> booksInLocation(AppDatabase db, String location) async {
  final root = p.normalize(location);
  return [
    for (final book in await db.getAllAudiobooks())
      if (book.source == kLibraryLocationSource &&
          book.chapters.isNotEmpty &&
          book.chapters.every((c) => p.isWithin(root, c.audioPathOrUrl)))
        book.id,
  ];
}

class _Candidate {
  final String id;
  final String keyPath;
  final String folder;
  final List<String> files;
  const _Candidate(this.id, this.keyPath, this.folder, this.files);
}

Future<List<_Candidate>> _findBooks(Directory root, List<String> skip) async {
  final found = <_Candidate>[];

  Future<void> visit(Directory dir, int depth) async {
    final here = p.normalize(dir.path);
    if (skip.any((s) => p.equals(s, here) || p.isWithin(s, here))) return;
    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }
    final audio = entries
        .whereType<File>()
        .map((f) => f.path)
        .where((path) =>
            _audioExtensions.contains(p.extension(path).toLowerCase()) &&
            !p.basename(path).startsWith('.'))
        .toList()
      ..sort();

    if (audio.isNotEmpty) {
      final allM4b =
          audio.every((path) => p.extension(path).toLowerCase() == '.m4b');
      // Several .m4b files are separate books (Emma.m4b, Persuasion.m4b)
      // unless their names share a start, as one book split into parts
      // does ("Title - 01 - Opening Credits.m4b", "Title - 02 - …").
      if (allM4b && audio.length > 1 && _sharedStem(audio).length < 4) {
        for (final path in audio) {
          found.add(_Candidate(
              BookIdentity.localIdForPath(path), path, dir.path, [path]));
        }
      } else {
        found.add(_Candidate(
            BookIdentity.localIdForPath(dir.path), dir.path, dir.path, audio));
      }
    }

    if (depth >= _maxDepth) return;
    final subdirs = entries
        .whereType<Directory>()
        .where((d) => !p.basename(d.path).startsWith('.'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final sub in subdirs) {
      await visit(sub, depth + 1);
    }
  }

  await visit(root, 0);
  return found;
}

/// The start every file name in [paths] shares, extension excluded.
String _sharedStem(List<String> paths) {
  final names = paths.map(p.basenameWithoutExtension).toList();
  var stem = names.first;
  for (final name in names.skip(1)) {
    var i = 0;
    while (i < stem.length && i < name.length && stem[i] == name[i]) {
      i++;
    }
    stem = stem.substring(0, i);
  }
  return stem;
}

Future<UnifiedAudiobook> _buildBook(_Candidate c) async {
  var chapters = await chaptersForFiles(c.id, c.files);
  // A whole-file chapter is titled with its file name; drop the start the
  // files share ("Title [id] - 04 - Chapter 1" reads "04 - Chapter 1").
  if (c.files.length > 1) {
    final stem = _sharedStem(c.files);
    // Cut back to a separator so a shared "Chapter 1" stays whole.
    final cut = stem.lastIndexOf(RegExp(r'[\s_\-.]'));
    if (cut > 0) {
      final prefix = stem.substring(0, cut + 1);
      chapters = [
        for (final ch in chapters)
          ch.title == p.basenameWithoutExtension(ch.audioPathOrUrl) &&
                  ch.title.length > prefix.length
              ? AudiobookChapter(
                  id: ch.id,
                  title: ch.title
                      .substring(prefix.length)
                      .replaceFirst(RegExp(r'^[\s_\-.]+'), ''),
                  audioPathOrUrl: ch.audioPathOrUrl,
                  durationSeconds: ch.durationSeconds,
                  isStream: ch.isStream,
                  startMs: ch.startMs,
                  endMs: ch.endMs,
                )
              : ch,
      ];
    }
  }
  final metadata = await readEmbeddedMetadataForFiles(c.files);
  String? coverPath;
  if (metadata?.hasCover == true) {
    coverPath =
        await saveCoverBytes(metadata!.coverBytes!, metadata.coverMime, c.id);
  }
  coverPath ??= await findFolderCoverImage(c.folder);

  final fallbackTitle = c.files.length == 1 && c.keyPath == c.files.first
      ? p.basenameWithoutExtension(c.keyPath)
      : p.basename(c.folder);
  return UnifiedAudiobook(
    id: c.id,
    title: _nonEmpty(metadata?.title) ?? fallbackTitle.replaceAll('_', ' '),
    author: _nonEmpty(metadata?.author) ?? 'Local Audiobook',
    description: _nonEmpty(metadata?.description) ?? 'Read from ${c.keyPath}',
    coverArtUrlOrPath: coverPath,
    source: kLibraryLocationSource,
    origin: BookIdentity.originLocal,
    chapters: chapters,
    isDownloaded: true,
  );
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

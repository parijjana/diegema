import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../core/utils/book_identity.dart';
import '../core/utils/mp4_chapters.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'cover_lookup_service.dart';
import 'library_locations_scanner_io.dart';
import 'library_locations_store.dart';
import 'local_audiobook_storage_io.dart';
import 'local_book_metadata_io.dart';
import 'storage_access_io.dart';

/// Builds this book's chapter list from its constituent files, expanding
/// any `.m4b`/`.m4a` that carries 2+ embedded chapter markers (see
/// `core/utils/mp4_chapters.dart`) into one [AudiobookChapter] per marker —
/// same [audioPathOrUrl], with [AudiobookChapter.startMs]/`endMs` bounding
/// each marker (the next marker's start, or the file's total duration for
/// the last one). A file with fewer than 2 markers (including none, or a
/// non-M4B/M4A file) becomes a single whole-file chapter, exactly as before
/// M4B chapter support existed.
///
/// Chapter ids are `${bookId}_ch_$n`, numbered continuously across every
/// file in [paths] rather than restarting per file, so ids stay unique
/// regardless of how many chapters a given file expands into.
Future<List<AudiobookChapter>> chaptersForFiles(
    String bookId, List<String> paths) async {
  final chapters = <AudiobookChapter>[];
  int idx = 0;

  for (final path in paths) {
    final ext = p.extension(path).toLowerCase();
    Mp4Chapters? mp4Chapters;
    if (ext == '.m4b' || ext == '.m4a') {
      mp4Chapters = await readMp4Chapters(path);
    }

    if (mp4Chapters != null && mp4Chapters.chapters.length >= 2) {
      final markers = mp4Chapters.chapters;
      for (int i = 0; i < markers.length; i++) {
        final marker = markers[i];
        final endMs = i + 1 < markers.length
            ? markers[i + 1].startMs
            : mp4Chapters.durationMs;
        final title =
            marker.title.trim().isNotEmpty ? marker.title : 'Chapter ${i + 1}';
        chapters.add(AudiobookChapter(
          id: '${bookId}_ch_$idx',
          title: title,
          audioPathOrUrl: path,
          durationSeconds: ((endMs - marker.startMs) / 1000).round(),
          isStream: false,
          startMs: marker.startMs,
          endMs: endMs,
        ));
        idx++;
      }
    } else {
      chapters.add(AudiobookChapter(
        id: '${bookId}_ch_$idx',
        title: p.basenameWithoutExtension(path),
        audioPathOrUrl: path,
        durationSeconds: 0,
        isStream: false,
      ));
      idx++;
    }
  }

  return chapters;
}

/// Adds a picked folder as a **library location**: Diegema reads the books
/// in it where they are — no copying, moving, or writing to that folder —
/// and rescans it whenever the Library loads (see
/// `library_locations_scanner_io.dart`). The folder may be one book or a
/// shelf of book folders.
Future<void> importFolder(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
  void say(String message, {SnackBarAction? action}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), action: action));
  }

  try {
    if (!await ensureAudioReadAccess()) {
      say('Diegema needs permission to read audio files to use a folder.',
          action: SnackBarAction(
              label: 'Settings', onPressed: () => openAppSettings()));
      return;
    }

    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select a folder of audiobooks',
    );
    if (selectedDirectory == null) return;

    const store = LibraryLocationsStore();
    final isNew = await store.add(selectedDirectory);
    final added =
        await scanLibraryLocations(db, store: store, only: selectedDirectory);
    final name = p.basename(selectedDirectory);

    if (added > 0) {
      onSuccess();
      say('Added $added ${added == 1 ? 'book' : 'books'} from "$name". '
          'They stay in that folder; Diegema only reads them.');
    } else if (!isNew) {
      say('"$name" is already a library folder, with no new books.');
    } else {
      // Nothing readable: don't keep a location that yields no books.
      await store.remove(selectedDirectory);
      say('No audio files (.mp3, .m4a, .m4b, etc.) found in "$name".');
    }
  } catch (e) {
    say('Adding the folder failed: $e');
  }
}

Future<void> importFiles(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
  try {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'm4b', 'aac', 'flac', 'wav', 'ogg'],
      dialogTitle: 'Select Audio Files for Audiobook',
    );

    if (result == null || result.files.isEmpty) return;

    final List<String> paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList()
      ..sort();

    if (paths.isEmpty) return;

    // A single picked file uses its own name (minus extension) as the book
    // title; several files fall back to their shared parent folder's name.
    final String defaultTitle;
    if (paths.length == 1) {
      defaultTitle = p.basenameWithoutExtension(paths.first);
    } else {
      final parentFolder = p.basename(p.dirname(paths.first));
      defaultTitle = parentFolder.isNotEmpty && parentFolder != '.'
          ? parentFolder
          : 'Imported Audiobook';
    }

    // Deterministic sha256-of-paths id — NOT hashCode. Computed from the
    // ORIGINAL picked paths (before the durable copy below) so ids stay
    // stable across imports.
    final bookId = BookIdentity.localIdForPaths(paths);
    final chapters = await chaptersForFiles(bookId, paths);

    final metadata = await readEmbeddedMetadataForFiles(paths);
    String? embeddedCoverPath;
    if (metadata?.hasCover == true) {
      embeddedCoverPath = await saveCoverBytes(
          metadata!.coverBytes!, metadata.coverMime, bookId);
    }
    // Step 2: no embedded art — check each picked file's own folder. As in
    // importFolder, this is a loose file outside the app's own storage, so
    // it gets copied below alongside the audio.
    final folderCoverPath = embeddedCoverPath == null
        ? await findFolderCoverImageForFiles(paths)
        : null;

    // Copy the picked files (and the folder cover, if any) into
    // `diegema/library/<bookId>/` — see local_audiobook_storage_io.dart.
    final copyResult = await copyIntoLibrary(
      bookId: bookId,
      audioPaths: paths,
      coverPath: folderCoverPath,
    );
    final durableChapters =
        _rewriteChapterPaths(chapters, copyResult.audioPaths);
    final coverPath = embeddedCoverPath ?? copyResult.coverPath;

    final book = UnifiedAudiobook(
      id: bookId,
      title: _nonEmpty(metadata?.title) ?? defaultTitle.replaceAll('_', ' '),
      author: _nonEmpty(metadata?.author) ?? 'Local Files',
      description: _nonEmpty(metadata?.description) ??
          'Imported ${paths.length} local audio files.',
      coverArtUrlOrPath: coverPath,
      source: 'Local Files',
      origin: BookIdentity.originLocal,
      chapters: durableChapters,
      isDownloaded: true,
    );

    await db.saveAudiobook(book);
    onSuccess();

    if (coverPath == null) {
      unawaited(_enrichCoverOnline(db, bookId, book.title, book.author));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Imported "${book.title}" (${paths.length} files)!')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Files import failed: $e')),
      );
    }
  }
}

/// Rewrites each chapter's [AudiobookChapter.audioPathOrUrl] from its
/// original (pre-copy) path to the durable path [pathMap] copied it to,
/// leaving every other field — including [AudiobookChapter.startMs]/`endMs`
/// M4B marker offsets, which describe a position *within* the file and are
/// unaffected by where the file itself lives — untouched. A chapter whose
/// path has no entry in [pathMap] (should not happen; every chapter's path
/// comes from the same file list that was copied) keeps its original path
/// rather than silently losing it.
List<AudiobookChapter> _rewriteChapterPaths(
    List<AudiobookChapter> chapters, Map<String, String> pathMap) {
  return chapters
      .map((c) => AudiobookChapter(
            id: c.id,
            title: c.title,
            audioPathOrUrl: pathMap[c.audioPathOrUrl] ?? c.audioPathOrUrl,
            durationSeconds: c.durationSeconds,
            isStream: c.isStream,
            startMs: c.startMs,
            endMs: c.endMs,
          ))
      .toList();
}

/// `null`/empty-safe trim, used when deciding whether an embedded tag
/// value should override the filename/foldername fallback.
String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// The default authors assigned when no embedded tag supplied one — never
/// meaningful as a search term, so [_enrichCoverOnline] treats them as "no
/// author known" rather than passing them to the lookup.
const _placeholderAuthors = {'Local Audiobook', 'Local Files'};

/// Step 3 of the local-import cover pipeline: an online lookup, run after
/// the book is already saved so it never blocks the import. Best-effort —
/// any failure (including the lookup finding nothing) is silently
/// swallowed; the book just keeps its placeholder cover.
Future<void> _enrichCoverOnline(
    AppDatabase db, String bookId, String title, String author) async {
  try {
    final knownAuthor = _placeholderAuthors.contains(author) ? null : author;
    final url = await CoverLookupService()
        .lookupCoverUrl(title: title, author: knownAuthor);
    if (url != null) {
      await db.setCoverUrl(bookId, url);
    }
  } catch (_) {
    // Background enrichment only — never surfaces to the user.
  }
}

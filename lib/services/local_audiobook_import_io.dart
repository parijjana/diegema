import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../core/utils/book_identity.dart';
import '../core/utils/mp4_chapters.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'cover_lookup_service.dart';
import 'local_book_metadata_io.dart';

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

Future<void> importFolder(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
  try {
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Audiobook Directory',
    );

    if (selectedDirectory == null) return;

    final folderDir = Directory(selectedDirectory);
    final folderName = p.basename(selectedDirectory);

    final files = await folderDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((f) {
      final ext = p.extension(f.path).toLowerCase();
      return ['.mp3', '.m4a', '.m4b', '.aac', '.flac', '.wav', '.ogg']
          .contains(ext);
    }).toList();

    files.sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No audio files (.mp3, .m4a, .m4b, etc.) found in selected folder.')),
        );
      }
      return;
    }

    // Deterministic sha256-of-path id — NOT hashCode. See
    // core/utils/book_identity.dart for why hashCode must never be a
    // persisted database key.
    final bookId = BookIdentity.localIdForPath(selectedDirectory);
    final filePaths = files.map((f) => f.path).toList();
    final chapters = await chaptersForFiles(bookId, filePaths);

    // Embedded tags (title/author/description/cover), read straight off
    // whichever file in the folder carries them. Filename/foldername stay
    // the fallback when a file has no tags at all.
    final metadata = await readEmbeddedMetadataForFiles(filePaths);
    String? coverPath;
    if (metadata?.hasCover == true) {
      coverPath =
          await saveCoverBytes(metadata!.coverBytes!, metadata.coverMime, bookId);
    }
    // Step 2: no embedded art — look for a cover/folder/front/albumart
    // image file (or a lone image) sitting in the folder itself.
    coverPath ??= await findFolderCoverImage(selectedDirectory);

    final book = UnifiedAudiobook(
      id: bookId,
      title: _nonEmpty(metadata?.title) ?? folderName.replaceAll('_', ' '),
      author: _nonEmpty(metadata?.author) ?? 'Local Audiobook',
      description:
          _nonEmpty(metadata?.description) ?? 'Imported from folder: $selectedDirectory',
      coverArtUrlOrPath: coverPath,
      source: 'Local Folder',
      origin: BookIdentity.originLocal,
      chapters: chapters,
      isDownloaded: true,
    );

    await db.saveAudiobook(book);
    onSuccess();

    // Step 3: still no cover after embedded metadata + folder image —
    // try an online lookup, after the save, without blocking the import.
    if (coverPath == null) {
      unawaited(_enrichCoverOnline(db, bookId, book.title, book.author));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Imported "${book.title}" (${chapters.length} chapters)!')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder import failed: $e')),
      );
    }
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

    // Deterministic sha256-of-paths id — NOT hashCode.
    final bookId = BookIdentity.localIdForPaths(paths);
    final chapters = await chaptersForFiles(bookId, paths);

    final metadata = await readEmbeddedMetadataForFiles(paths);
    String? coverPath;
    if (metadata?.hasCover == true) {
      coverPath =
          await saveCoverBytes(metadata!.coverBytes!, metadata.coverMime, bookId);
    }
    // Step 2: no embedded art — check each picked file's own folder.
    coverPath ??= await findFolderCoverImageForFiles(paths);

    final book = UnifiedAudiobook(
      id: bookId,
      title: _nonEmpty(metadata?.title) ?? defaultTitle.replaceAll('_', ' '),
      author: _nonEmpty(metadata?.author) ?? 'Local Files',
      description: _nonEmpty(metadata?.description) ??
          'Imported ${paths.length} local audio files.',
      coverArtUrlOrPath: coverPath,
      source: 'Local Files',
      origin: BookIdentity.originLocal,
      chapters: chapters,
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
            content:
                Text('Imported "${book.title}" (${paths.length} files)!')),
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

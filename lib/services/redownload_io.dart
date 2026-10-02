import 'dart:io';

import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../domain/models/librivox_book.dart';
import 'downloads_location_io.dart';
import 'librivox_downloader_io.dart';

/// Whether [book]'s chapter [index] can be opened, for a downloaded copy.
/// Streams and non-downloaded books always count as readable. A file can
/// exist and still be unreadable (a folder the app lost access to), so
/// this opens it rather than checking that it exists.
Future<bool> downloadedChapterReadable(UnifiedAudiobook book, int index) async {
  if (!book.isDownloaded || index < 0 || index >= book.chapters.length) {
    return true;
  }
  final chapter = book.chapters[index];
  if (chapter.isStream) return true;
  try {
    final file = await File(chapter.audioPathOrUrl).open();
    await file.close();
    return true;
  } catch (_) {
    return false;
  }
}

/// Only Discover (LibriVox) downloads can be fetched again; an imported or
/// library-folder book has nowhere to come from.
bool canRedownload(UnifiedAudiobook book) =>
    book.isDownloaded &&
    book.origin == BookIdentity.originLibrivox &&
    !book.id.startsWith(BookIdentity.localIdPrefix);

/// Downloads [book] again (owner: never fall back to streaming) and saves
/// it under the same id, so progress and bookmarks carry over. Chapter
/// titles and durations are kept when the new files line up one to one.
/// Uses archive.org's pre-built 64kb ZIP, not the on-the-fly `compress`
/// endpoint, to spare their servers.
Future<UnifiedAudiobook> redownloadBook(
  AppDatabase db,
  UnifiedAudiobook book, {
  LibriVoxStreamAndDownloader? downloader,
  DownloadsLocation location = const DownloadsLocation(),
  void Function(double progress)? onProgress,
}) async {
  if (location.needsFolderChoice) await location.chooseFolder();
  final root = await location.current();
  if (root == null) throw StateError('No folder to download into');

  final id = book.id;
  final client = downloader ?? LibriVoxStreamAndDownloader();
  Future<List<String>> fetch(String zipUrl) => client.downloadAndExtractZip(
        LibriVoxBook(
          id: id,
          title: book.title,
          description: book.description,
          totalTimeSecs: 0,
          authors: const [],
          urlRss: '',
          urlZipFile: zipUrl,
          urlIarchive: 'https://archive.org/details/$id',
          language: '',
          narrators: book.narrators,
        ),
        saveDirectoryPath: root,
        onProgress: onProgress,
      );
  List<String> files;
  try {
    files = await fetch('https://archive.org/download/$id/${id}_64kb_mp3.zip');
  } on HttpException catch (e) {
    // An item without the pre-built ZIP: the form LibriVox itself links.
    if (!e.message.contains('404')) rethrow;
    files = await fetch('https://archive.org/compress/$id/'
        'formats=64KBPS%20MP3&file=/$id.zip');
  }

  final old = book.chapters;
  final same = old.length == files.length;
  final fresh = UnifiedAudiobook(
    id: id,
    title: book.title,
    author: book.author,
    description: book.description,
    coverArtUrlOrPath: book.coverArtUrlOrPath,
    source: book.source,
    origin: book.origin,
    narrators: book.narrators,
    isDownloaded: true,
    chapters: [
      for (var i = 0; i < files.length; i++)
        AudiobookChapter(
          id: same ? old[i].id : '${id}_local_$i',
          title: same ? old[i].title : 'Part ${i + 1}',
          audioPathOrUrl: files[i],
          durationSeconds: same ? old[i].durationSeconds : 0,
          isStream: false,
        ),
    ],
  );
  await db.saveAudiobook(fresh);
  return fresh;
}

import 'dart:io';

import '../core/utils/book_identity.dart';
import '../domain/models/audiobook.dart';

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

// Re-downloading itself goes through the queue: see
// `DownloadManager.redownload` and `DownloadJob.redownload`.

import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'local_book_metadata_io.dart';

/// The default authors assigned to a local import with no embedded tags —
/// never a meaningful search term. Mirrors
/// `local_audiobook_import_io.dart`'s `_placeholderAuthors`.
const _placeholderAuthors = {'Local Audiobook', 'Local Files'};

/// Once per app launch, gives already-imported local books another shot at a
/// cover from the files themselves: embedded tags and art, then a folder
/// image.
///
/// OFFLINE ONLY. A local book's title and author come from the user's own
/// files, so they are never sent to archive.org or Open Library
/// automatically (store-compliance audit S-05). The online lookup exists only
/// as the per-book "Find cover" action (`find_cover_service.dart`).
///
/// Never throws.
class LocalCoverBackfillService {
  final AppDatabase db;
  LocalCoverBackfillService({required this.db});

  Future<void> run() async {
    try {
      final books = await db.getAllAudiobooks();

      final candidates = books.where((book) {
        if (book.origin != BookIdentity.originLocal) return false;
        final cover = book.coverArtUrlOrPath;
        final hasCover = cover != null && cover.isNotEmpty;
        return !hasCover || _placeholderAuthors.contains(book.author);
      });

      for (var book in candidates) {
        // Books imported before tags were read carry the filename as the
        // title and a placeholder author; fix those first so the online
        // lookup below searches with the real title.
        book = await _applyEmbeddedTags(book);
        final cover = book.coverArtUrlOrPath;
        if (cover != null && cover.isNotEmpty) continue;
        final found = await _findCover(book);
        if (found != null) {
          await db.setCoverUrl(book.id, found);
        }
      }
    } catch (_) {
      // Best-effort background maintenance; never surfaces to the user.
    }
  }

  Future<UnifiedAudiobook> _applyEmbeddedTags(UnifiedAudiobook book) async {
    if (!_placeholderAuthors.contains(book.author)) return book;
    final metadata = await readEmbeddedMetadataForFiles(_localPaths(book));
    final title = metadata?.title?.trim() ?? '';
    final author = metadata?.author?.trim() ?? '';
    if (title.isEmpty && author.isEmpty) return book;
    final updated = UnifiedAudiobook(
      id: book.id,
      title: title.isNotEmpty ? title : book.title,
      author: author.isNotEmpty ? author : book.author,
      description: (metadata?.description?.trim().isNotEmpty ?? false)
          ? metadata!.description!.trim()
          : book.description,
      coverArtUrlOrPath: book.coverArtUrlOrPath,
      source: book.source,
      origin: book.origin,
      narrators: book.narrators,
      chapters: book.chapters,
      isDownloaded: book.isDownloaded,
    );
    await db.saveAudiobook(updated);
    return updated;
  }

  List<String> _localPaths(UnifiedAudiobook book) => book.chapters
      .map((c) => c.audioPathOrUrl)
      .where(
          (path) => !path.startsWith('http://') && !path.startsWith('https://'))
      .toSet()
      .toList();

  Future<String?> _findCover(UnifiedAudiobook book) async {
    final localPaths = _localPaths(book);

    if (localPaths.isNotEmpty) {
      final metadata = await readEmbeddedMetadataForFiles(localPaths);
      if (metadata?.hasCover == true) {
        final saved = await saveCoverBytes(
            metadata!.coverBytes!, metadata.coverMime, book.id);
        if (saved != null) return saved;
      }

      final folderCover = await findFolderCoverImageForFiles(localPaths);
      if (folderCover != null) return folderCover;
    }

    return null;
  }
}

import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'backfill_attempt_store.dart';
import 'cover_lookup_service.dart';
import 'local_book_metadata_io.dart';

/// The default authors assigned to a local import with no embedded tags —
/// never a meaningful search term. Mirrors
/// `local_audiobook_import_io.dart`'s `_placeholderAuthors`.
const _placeholderAuthors = {'Local Audiobook', 'Local Files'};

/// Once per app launch (step 4 of the local-import cover pipeline), gives
/// already-imported local books — ones that predate this feature, or whose
/// steps 1-3 all missed at import time — another shot at a cover: the same
/// embedded-metadata (step 1), folder-image (step 2), and online-lookup
/// (step 3) pipeline `local_audiobook_import_io.dart` runs at import time.
///
/// Never throws. The offline steps (embedded tags and art, folder image)
/// run every launch; the online lookup runs at most once per [retryAfter]
/// per book (tracked via [BackfillAttemptStore]). The loop runs strictly
/// sequentially, so at most one online lookup is ever in flight.
class LocalCoverBackfillService {
  final AppDatabase db;
  final BackfillAttemptStore _store;
  final CoverLookupService _lookupService;
  final DateTime Function() _now;

  static const Duration retryAfter = Duration(days: 30);

  LocalCoverBackfillService({
    required this.db,
    BackfillAttemptStore? store,
    CoverLookupService? lookupService,
    DateTime Function()? now,
  })  : _store = store ?? const BackfillAttemptStore(),
        _lookupService = lookupService ?? CoverLookupService(),
        _now = now ?? DateTime.now;

  Future<void> run() async {
    try {
      final books = await db.getAllAudiobooks();
      final attempts = await _store.read();
      final nowValue = _now();

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
        // The offline steps are cheap and run every launch; only the
        // online lookup is rationed to once per [retryAfter].
        final lastAttempt = attempts[book.id];
        final mayGoOnline = lastAttempt == null ||
            nowValue.difference(lastAttempt) >= retryAfter;
        if (mayGoOnline) attempts[book.id] = nowValue;
        final found = await _findCover(book, online: mayGoOnline);
        if (found != null) {
          await db.setCoverUrl(book.id, found);
        }
      }

      await _store.write(attempts);
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

  Future<String?> _findCover(UnifiedAudiobook book,
      {required bool online}) async {
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

    if (!online) return null;
    final knownAuthor =
        _placeholderAuthors.contains(book.author) ? null : book.author;
    return _lookupService.lookupCoverUrl(
        title: book.title, author: knownAuthor);
  }
}

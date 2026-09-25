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
/// Never throws. Books already attempted within [retryAfter] are skipped
/// (tracked via [BackfillAttemptStore]); the loop runs strictly
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
        if (cover != null && cover.isNotEmpty) return false;
        final lastAttempt = attempts[book.id];
        if (lastAttempt != null &&
            nowValue.difference(lastAttempt) < retryAfter) {
          return false;
        }
        return true;
      });

      for (final book in candidates) {
        attempts[book.id] = nowValue;
        final found = await _findCover(book);
        if (found != null) {
          await db.setCoverUrl(book.id, found);
        }
      }

      await _store.write(attempts);
    } catch (_) {
      // Best-effort background maintenance; never surfaces to the user.
    }
  }

  Future<String?> _findCover(UnifiedAudiobook book) async {
    final localPaths = book.chapters
        .map((c) => c.audioPathOrUrl)
        .where((path) =>
            !path.startsWith('http://') && !path.startsWith('https://'))
        .toSet()
        .toList();

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

    final knownAuthor =
        _placeholderAuthors.contains(book.author) ? null : book.author;
    return _lookupService.lookupCoverUrl(
        title: book.title, author: knownAuthor);
  }
}

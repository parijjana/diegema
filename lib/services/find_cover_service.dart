import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'cover_lookup_service.dart';

/// Authors assigned to a local import with no embedded author tag. Never a
/// meaningful search term.
const _placeholderAuthors = {'Local Audiobook', 'Local Files'};

/// The explicit, per-book "Find cover" action for local imports and
/// library-folder books.
///
/// This is the ONLY place a local book's title or author leaves the device.
/// It runs when the user asks, never at import and never at launch
/// (store-compliance audit S-05). It asks archive.org, then Open Library,
/// through [CoverLookupService]. LibriVox books are public catalogue items
/// and do not use this path.
///
/// Returns the cover URL that was saved, or null when nothing matched or the
/// network failed. Never throws.
Future<String?> findCoverOnRequest(
  AppDatabase db,
  UnifiedAudiobook book, {
  CoverLookupService? lookupService,
}) async {
  if (book.origin != BookIdentity.originLocal) return null;
  try {
    final author = _placeholderAuthors.contains(book.author)
        ? null
        : book.author;
    final url = await (lookupService ?? CoverLookupService()).lookupCoverUrl(
      title: book.title,
      author: author,
    );
    if (url != null) await db.setCoverUrl(book.id, url);
    return url;
  } catch (_) {
    return null;
  }
}

import '../domain/models/librivox_book.dart';
import 'demo_catalog.dart';
import 'librivox_service.dart';

/// Stub [LibriVoxService] for the canned web demo. Serves the bundled
/// curated catalog (`assets/demo/catalog.json`) instead of ever calling
/// librivox.org or archive.org's search endpoints — matching
/// rework_plan.md's "no network calls for browsing at all" decision for
/// the demo.
///
/// `HomeScreen` drives this exactly like the real service: an empty query
/// is the "Featured" shelf (here: the whole small curated catalog), and
/// each category tab passes its query string, which is matched against
/// each entry's `category` tag in catalog.json.
class DemoLibriVoxService extends LibriVoxService {
  Future<List<DemoBookEntry>> _catalog() => DemoCatalog.load();

  @override
  Future<List<LibriVoxBook>> searchBooks(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final entries = await _catalog();
    final term = query.trim().toLowerCase();

    Iterable<DemoBookEntry> matches;
    if (term.isEmpty) {
      matches = entries;
    } else {
      matches = entries.where((e) =>
          e.category.toLowerCase() == term ||
          e.title.toLowerCase().contains(term) ||
          e.author.toLowerCase().contains(term));
    }

    return matches.skip(offset).take(limit).map((e) => e.toLibriVoxBook()).toList();
  }

  @override
  Future<LibriVoxBook?> getBookById(String id) async {
    final entries = await _catalog();
    for (final e in entries) {
      if (e.id == id) return e.toLibriVoxBook();
    }
    return null;
  }
}

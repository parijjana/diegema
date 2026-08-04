import '../domain/models/librivox_book.dart';
import 'artwork_enrichment_service.dart';

/// Stub [ArtworkEnrichmentService] for the canned web demo. The real
/// implementation does an extra `http.get` to verify archive.org actually
/// has an image before trusting the URL — a plain `fetch`, which (unlike
/// an `<img>` tag) is subject to CORS, and archive.org's img service is
/// not confirmed CORS-enabled (only `advancedsearch.php` and
/// `/metadata/<id>` are, per rework_plan.md's CORS findings). Every cover
/// URL in the curated catalog was already verified to resolve (see the
/// demo's build report), so this just trusts it directly and skips the
/// network round trip entirely.
class DemoArtworkService extends ArtworkEnrichmentService {
  @override
  Future<String?> resolveCoverArtUrl(LibriVoxBook book) async {
    final url = book.coverArtUrl;
    return url.isEmpty ? null : url;
  }
}

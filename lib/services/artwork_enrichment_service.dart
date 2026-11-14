import 'package:http/http.dart' as http;
import '../core/network/policy_client.dart';
import '../core/network/url_policy.dart';
import '../domain/models/librivox_book.dart';

/// Resolves cover art exclusively from archive.org.
///
/// LibriVox mirrors its audio (and cover images) on archive.org, so
/// [LibriVoxBook.coverArtUrl] already points at
/// `https://archive.org/services/img/<identifier>`. This service simply
/// verifies that archive.org actually has an image at that URL; when it
/// does not, it returns null so the UI falls back to its placeholder.
class ArtworkEnrichmentService {
  final http.Client _client;

  ArtworkEnrichmentService({http.Client? client})
      : _client = policyClient(client);

  Future<String?> resolveCoverArtUrl(LibriVoxBook book) async {
    final raw = book.coverArtUrl;
    if (raw.isEmpty) return null;
    final url = permittedFetchUrl(raw);
    if (url == null) return null;

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && contentType.startsWith('image/')) {
        return url;
      }
    } catch (_) {}

    return null;
  }
}

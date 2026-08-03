import 'dart:convert';
import 'package:http/http.dart' as http;
import 'wikipedia_service.dart';
import 'audnexus_service.dart';

class ArtworkEnrichmentService {
  final WikipediaService _wikipediaService;
  final AudnexusService _audnexusService;
  final http.Client _client;

  ArtworkEnrichmentService({
    WikipediaService? wikipediaService,
    AudnexusService? audnexusService,
    http.Client? client,
  })  : _wikipediaService = wikipediaService ?? WikipediaService(),
        _audnexusService = audnexusService ?? AudnexusService(),
        _client = client ?? http.Client();

  Future<String?> resolveCoverArtUrl({
    required String title,
    required String author,
  }) async {
    final query = '$title $author'.trim();

    try {
      final wiki = await _wikipediaService.fetchSummary(title);
      if (wiki != null && wiki.thumbnailUrl != null && wiki.thumbnailUrl!.isNotEmpty) {
        return wiki.thumbnailUrl;
      }
    } catch (_) {}

    try {
      final audnexusData = await _audnexusService.searchBook(query);
      if (audnexusData != null) {
        final image = audnexusData['image'] as String?;
        if (image != null && image.isNotEmpty) {
          return image;
        }
      }
    } catch (_) {}

    try {
      final olUrl = Uri.parse(
        'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=1',
      );
      final olResp = await _client.get(olUrl).timeout(const Duration(seconds: 10));
      if (olResp.statusCode == 200) {
        final olJson = json.decode(olResp.body) as Map<String, dynamic>;
        final docs = olJson['docs'] as List?;
        if (docs != null && docs.isNotEmpty) {
          final first = docs.first as Map<String, dynamic>;
          final coveri = first['cover_i'];
          if (coveri != null) {
            return 'https://covers.openlibrary.org/b/id/$coveri-L.jpg';
          }
        }
      }
    } catch (_) {}

    try {
      final itunesUrl = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=audiobook&limit=1',
      );
      final itunesResp = await _client.get(itunesUrl).timeout(const Duration(seconds: 10));
      if (itunesResp.statusCode == 200) {
        final itunesJson = json.decode(itunesResp.body) as Map<String, dynamic>;
        final results = itunesJson['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final artworkUrl = first['artworkUrl100'] as String?;
          if (artworkUrl != null && artworkUrl.isNotEmpty) {
            return artworkUrl.replaceAll('100x100bb', '600x600bb');
          }
        }
      }
    } catch (_) {}

    return null;
  }
}

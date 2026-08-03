import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../core/network/rate_limit_dispatcher.dart';
import '../database/app_database.dart';

class WikipediaSummary {
  final String title;
  final String extract;
  final String? thumbnailUrl;
  final String? pageUrl;

  WikipediaSummary({
    required this.title,
    required this.extract,
    this.thumbnailUrl,
    this.pageUrl,
  });
}

class WikipediaService {
  final http.Client _client;
  final RateLimitDispatcher _rateLimiter;
  final AppDatabase? _db;
  final Map<String, WikipediaSummary> _memoryCache = {};

  WikipediaService({
    http.Client? client,
    RateLimitDispatcher? rateLimiter,
    AppDatabase? db,
  })  : _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? RateLimitDispatcher(),
        _db = db;

  Future<WikipediaSummary?> fetchSummary(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return null;

    final bytes = utf8.encode(cleanQuery);
    final cacheKey = sha256.convert(bytes).toString().substring(0, 16);

    // 1. Memory cache
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 2. Database cache
    final db = _db;
    if (db != null) {
      try {
        final cached = await db.getCachedWikipediaSummary(cacheKey);
        if (cached != null) {
          _memoryCache[cacheKey] = cached;
          return cached;
        }
      } catch (_) {}
    }

    // 3. Network fetch
    return _rateLimiter.dispatch<WikipediaSummary?>(
      apiId: 'wikipedia',
      call: () async {
        try {
          final searchUrl = Uri.parse(
            'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&format=json&origin=*',
          );
          final searchResponse = await _client.get(searchUrl).timeout(const Duration(seconds: 15));
          if (searchResponse.statusCode != 200) return null;

          final searchData = json.decode(searchResponse.body) as Map<String, dynamic>;
          final queryObj = searchData['query'] as Map<String, dynamic>?;
          final searchResults = queryObj?['search'] as List<dynamic>?;

          if (searchResults == null || searchResults.isEmpty) return null;

          final firstMatchTitle = searchResults.first['title'] as String;

          final summaryUrl = Uri.parse(
            'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(firstMatchTitle)}',
          );
          final summaryResponse = await _client.get(summaryUrl).timeout(const Duration(seconds: 15));

          if (summaryResponse.statusCode == 200) {
            final summaryData = json.decode(summaryResponse.body) as Map<String, dynamic>;
            final extract = summaryData['extract'] as String?;
            final thumbnailObj = summaryData['thumbnail'] as Map<String, dynamic>?;
            final thumbnailUrl = thumbnailObj?['source'] as String?;
            final contentUrlsObj = summaryData['content_urls'] as Map<String, dynamic>?;
            final desktopObj = contentUrlsObj?['desktop'] as Map<String, dynamic>?;
            final pageUrl = desktopObj?['page'] as String?;

            if (extract != null && extract.isNotEmpty) {
              final summary = WikipediaSummary(
                title: firstMatchTitle,
                extract: extract,
                thumbnailUrl: thumbnailUrl,
                pageUrl: pageUrl,
              );

              _memoryCache[cacheKey] = summary;

              if (db != null) {
                try {
                  await db.cacheWikipediaSummary(
                    cacheKey: cacheKey,
                    query: query,
                    summary: summary,
                  );
                } catch (_) {}
              }

              return summary;
            }
          }
        } catch (_) {}
        return null;
      },
    );
  }
}

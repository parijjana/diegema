import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/network/rate_limit_dispatcher.dart';
import '../core/network/user_agent.dart';
import '../domain/models/librivox_book.dart';

class LibriVoxService {
  final http.Client _client;
  final RateLimitDispatcher _rateLimiter;

  static const String _baseUrl = 'https://librivox.org/api/feed/audiobooks';
  static const String _archiveUrl = 'https://archive.org/advancedsearch.php';

  static const Map<String, String> _headers = {
    'User-Agent': kHttpUserAgent,
    'Accept': 'application/json, text/plain, */*',
  };

  LibriVoxService({
    http.Client? client,
    RateLimitDispatcher? rateLimiter,
  })  : _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? RateLimitDispatcher();

  /// Search LibriVox audiobooks. If term is empty, fetch LibriVox's featured feed.
  /// If searching, query Internet Archive's LibriVox collection for 100% reliable keyword matching.
  Future<List<LibriVoxBook>> searchBooks(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final term = query.trim();

    return _rateLimiter.dispatch<List<LibriVoxBook>>(
      apiId: 'librivox',
      call: () async {
        if (term.isNotEmpty) {
          // Use Internet Archive LibriVox collection search for keyword queries
          final searchResults = await _searchInternetArchiveLibriVox(term, limit: limit);
          if (searchResults.isNotEmpty) return searchResults;
        }

        // Fetch direct LibriVox API feed
        final url = '$_baseUrl/?format=json&extended=1&limit=$limit&offset=$offset';
        try {
          final response = await _client
              .get(Uri.parse(url), headers: _headers)
              .timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = await compute(json.decode, response.body) as JsonMap;
            final booksData = data['books'];
            final List<LibriVoxBook> books = [];

            if (booksData is JsonMap) {
              for (var entry in booksData.values) {
                if (entry is JsonMap) {
                  books.add(LibriVoxBook.fromJson(entry));
                }
              }
            } else if (booksData is List) {
              for (var item in booksData) {
                if (item is JsonMap) {
                  books.add(LibriVoxBook.fromJson(item));
                }
              }
            }
            return books;
          }
        } catch (e) {
          debugPrint('LibriVox feed error: $e');
        }

        return [];
      },
    );
  }

  Future<List<LibriVoxBook>> _searchInternetArchiveLibriVox(String term, {int limit = 20}) async {
    try {
      final archiveQuery = '$_archiveUrl?q=collection:(librivoxaudio) AND mediatype:(audio) AND (title:(${Uri.encodeComponent(term)}) OR creator:(${Uri.encodeComponent(term)}))&fl[]=identifier,title,creator,description,publicdate&sort[]=downloads+desc&rows=$limit&output=json';

      final response = await _client
          .get(Uri.parse(archiveQuery), headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as JsonMap;
        final responseObj = data['response'] as JsonMap?;
        final docs = responseObj?['docs'] as List?;
        final List<LibriVoxBook> books = [];

        if (docs != null) {
          for (final doc in docs) {
            if (doc is JsonMap) {
              final id = doc['identifier']?.toString() ?? '';
              final title = doc['title']?.toString() ?? 'Unknown Title';
              final creator = doc['creator']?.toString() ?? 'LibriVox Reader';
              final description = doc['description']?.toString() ?? '';

              books.add(LibriVoxBook(
                id: id,
                title: title,
                description: description,
                totalTimeSecs: 0,
                authors: [
                  LibriVoxAuthor(id: id, firstName: '', lastName: creator)
                ],
                urlRss: 'https://archive.org/advancedsearch.php?q=identifier:$id',
                urlZipFile: 'https://archive.org/compress/$id/formats=64KBPS%20MP3&file=/$id.zip',
                language: 'English',
                narrators: [creator],
              ));
            }
          }
        }
        return books;
      }
    } catch (e) {
      debugPrint('Internet Archive search error: $e');
    }
    return [];
  }

  Future<LibriVoxBook?> getBookById(String id) async {
    if (id.isEmpty) return null;
    final url = '$_baseUrl/?id=$id&format=json&extended=1';

    return _rateLimiter.dispatch<LibriVoxBook?>(
      apiId: 'librivox',
      call: () async {
        try {
          final response = await _client.get(Uri.parse(url), headers: _headers);
          if (response.statusCode == 200) {
            final data = await compute(json.decode, response.body) as JsonMap;
            final booksData = data['books'];

            if (booksData is JsonMap && booksData.isNotEmpty) {
              final firstBook = booksData.values.first;
              if (firstBook is JsonMap) {
                return LibriVoxBook.fromJson(firstBook);
              }
            } else if (booksData is List && booksData.isNotEmpty) {
              final firstBook = booksData.first;
              if (firstBook is JsonMap) {
                return LibriVoxBook.fromJson(firstBook);
              }
            }
          }
        } catch (_) {}
        return null;
      },
    );
  }
}

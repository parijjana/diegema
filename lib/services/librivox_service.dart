import '../core/utils/title_variants.dart';
import '../core/utils/book_identity.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/network/rate_limit_dispatcher.dart';
import '../core/network/user_agent.dart';
import '../domain/models/librivox_book.dart';
import 'search_cache_store.dart';

class LibriVoxService {
  final http.Client _client;
  final RateLimitDispatcher _rateLimiter;

  static const String _baseUrl = 'https://librivox.org/api/feed/audiobooks';
  static const String _archiveUrl = 'https://archive.org/advancedsearch.php';

  static const Map<String, String> _headers = {
    'User-Agent': kHttpUserAgent,
    'Accept': 'application/json, text/plain, */*',
  };

  /// How long a search result is reused. The shell rebuilds Discover on
  /// every visit, and LibriVox's feed takes 10-20s, so without this each
  /// visit re-downloaded every shelf. The catalog changes slowly, so a day
  /// is fine, and it lets the disk copy outlive an overnight restart.
  final Duration cacheTtl;
  final DateTime Function() _now;
  final SearchCacheStore _store;
  final Map<String, ({DateTime at, List<LibriVoxBook> books})> _cache = {};
  final Map<String, Future<List<LibriVoxBook>>> _inFlight = {};
  late final Future<void> _diskLoaded = _loadFromDisk();

  LibriVoxService({
    http.Client? client,
    RateLimitDispatcher? rateLimiter,
    this.cacheTtl = const Duration(hours: 24),
    DateTime Function()? now,
    SearchCacheStore? cacheStore,
  })  : _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? RateLimitDispatcher(),
        _now = now ?? DateTime.now,
        _store = cacheStore ?? const SearchCacheStore();

  /// Search LibriVox audiobooks. If term is empty, fetch LibriVox's featured feed.
  /// If searching, query Internet Archive's LibriVox collection for 100% reliable keyword matching.
  Future<List<LibriVoxBook>> searchBooks(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    await _diskLoaded;
    final key = '${query.trim().toLowerCase()}|$limit|$offset';
    final hit = _cache[key];
    if (hit != null && _now().difference(hit.at) < cacheTtl) {
      return hit.books;
    }
    // A second caller for the same shelf joins the request already out.
    return _inFlight[key] ??=
        _fetchBooks(query, limit: limit, offset: offset).then((books) {
      // Empty usually means a timeout or outage; retry it next visit.
      if (books.isNotEmpty) {
        _cache[key] = (at: _now(), books: books);
        _saveToDisk();
      }
      return books;
    }).whenComplete(() {
      // Block body on purpose: an arrow would return the removed future,
      // and whenComplete would then wait on the very future it completes.
      _inFlight.remove(key);
    });
  }

  Future<void> _loadFromDisk() async {
    try {
      final raw = await _store.read();
      if (raw == null) return;
      final data = json.decode(raw) as JsonMap;
      for (final entry in data.entries) {
        final value = entry.value as JsonMap;
        final at = DateTime.fromMillisecondsSinceEpoch(value['at'] as int);
        if (_now().difference(at) >= cacheTtl) continue;
        final books = (value['books'] as List)
            .whereType<JsonMap>()
            .map(LibriVoxBook.fromJson)
            .toList();
        _cache.putIfAbsent(entry.key, () => (at: at, books: books));
      }
    } catch (e) {
      // A corrupt or old-format cache is just a cold start.
      debugPrint('Discover cache unreadable, ignoring: $e');
    }
  }

  void _saveToDisk() {
    final now = _now();
    final data = {
      for (final e in _cache.entries)
        if (now.difference(e.value.at) < cacheTtl)
          e.key: {
            'at': e.value.at.millisecondsSinceEpoch,
            'books': e.value.books.map((b) => b.toJson()).toList(),
          },
    };
    _store.write(json.encode(data));
  }

  Future<List<LibriVoxBook>> _fetchBooks(
    String query, {
    required int limit,
    required int offset,
  }) async {
    final term = query.trim();

    // The featured feed (librivox.org) is a different server from the
    // keyword search (archive.org) and far slower, so it gets its own queue
    // rather than stalling every archive.org search queued behind it.
    return _rateLimiter.dispatch<List<LibriVoxBook>>(
      apiId: term.isEmpty ? 'librivox-feed' : 'librivox',
      call: () async {
        if (term.isNotEmpty) {
          // Use Internet Archive LibriVox collection search for keyword queries
          final searchResults = await _searchInternetArchiveLibriVox(term,
              limit: limit, offset: offset);
          if (searchResults.isNotEmpty) return searchResults;
          // Past the first page an empty answer means "no more results", not
          // "try the unrelated featured feed", which would pad the list.
          if (offset > 0) return const <LibriVoxBook>[];
        }

        // Fetch direct LibriVox API feed
        final url =
            '$_baseUrl/?format=json&extended=1&limit=$limit&offset=$offset';
        try {
          final response = await _client
              .get(Uri.parse(url), headers: _headers)
              // The feed routinely takes 10-20s to respond; 12s cut it off.
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = await compute(json.decode, response.body) as JsonMap;
            final booksData = data['books'];
            final List<LibriVoxBook> books = [];

            if (booksData is JsonMap) {
              for (final entry in booksData.values) {
                if (entry is JsonMap) {
                  books.add(LibriVoxBook.fromJson(entry));
                }
              }
            } else if (booksData is List) {
              for (final item in booksData) {
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

  Future<List<LibriVoxBook>> _searchInternetArchiveLibriVox(String term,
      {int limit = 20, int offset = 0}) async {
    try {
      // archive.org pages by whole pages of [limit] rows, so [offset] is
      // expected to be a multiple of it (Discover pages by its page size).
      final page = limit > 0 ? offset ~/ limit + 1 : 1;
      final archiveQuery =
          '$_archiveUrl?q=collection:(librivoxaudio) AND mediatype:(audio) AND (title:(${Uri.encodeComponent(term)}) OR creator:(${Uri.encodeComponent(term)}))&fl[]=identifier,title,creator,description,publicdate&sort[]=downloads+desc&rows=$limit&page=$page&output=json';

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

              books.add(
                LibriVoxBook(
                  id: id,
                  title: title,
                  description: description,
                  totalTimeSecs: 0,
                  authors: [
                    LibriVoxAuthor(id: id, firstName: '', lastName: creator),
                  ],
                  urlRss:
                      'https://archive.org/advancedsearch.php?q=identifier:$id',
                  urlZipFile:
                      'https://archive.org/compress/$id/formats=64KBPS%20MP3&file=/$id.zip',
                  language: 'English',
                  narrators: [creator],
                ),
              );
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

  /// The `title=^...` queries to try for a stored [title], most specific
  /// first. LibriVox drops a leading article and writes "(version N)", so
  /// the query is the lower-cased base title; a "Vol. 032" title is first
  /// tried with its bare number ("... collection 032"), which is how
  /// LibriVox names those.
  static List<String> narratorSearchTerms(String title) {
    final split = splitTitleVariant(title);
    final base = split.base
        .toLowerCase()
        .replaceFirst(RegExp(r'^(the|an|a)\s+'), '')
        .trim();
    final terms = <String>[];
    final number = RegExp(r'^(?:vol\.?|volume)\s*(\d+)$', caseSensitive: false)
        .firstMatch(split.label ?? '');
    if (number != null) terms.add('$base ${number.group(1)}');
    terms.add(base);
    return terms;
  }

  /// The readers of the book archived as [archiveId] (the id the Library
  /// stores), for the one-off narrator backfill. The LibriVox feed has no
  /// lookup by archive identifier, so this searches by [title] (see
  /// [narratorSearchTerms]) and picks the result whose `url_iarchive` is
  /// [archiveId]. Rate limited, at most [maxPages] requests per term.
  ///
  /// `names` is null when nothing matched; `sawBooks` says whether any
  /// search returned books (false means the queries found nothing at all,
  /// which may be a bad query rather than a missing book). Throws when a
  /// request itself failed.
  Future<({List<String>? names, bool sawBooks})> narratorsForArchiveId(
      String archiveId, String title,
      {int maxPages = 2}) async {
    const pageSize = 50;
    var sawBooks = false;
    for (final term in narratorSearchTerms(title)) {
      for (var page = 0; page < maxPages; page++) {
        final url = '$_baseUrl/?format=json&extended=1&limit=$pageSize'
            '&offset=${page * pageSize}'
            '&title=${Uri.encodeQueryComponent('^$term')}';
        final books = await _rateLimiter.dispatch<List<LibriVoxBook>>(
          apiId: 'librivox',
          call: () async {
            final response = await _client
                .get(Uri.parse(url), headers: _headers)
                .timeout(const Duration(seconds: 30));
            // LibriVox answers 404 "could not be found" for no results.
            if (response.statusCode == 404) return const <LibriVoxBook>[];
            if (response.statusCode != 200) {
              throw http.ClientException(
                  'LibriVox answered ${response.statusCode}');
            }
            final data = await compute(json.decode, response.body) as JsonMap;
            final raw = data['books'];
            final items = raw is JsonMap
                ? raw.values
                : raw is List
                    ? raw
                    : const [];
            return [
              for (final item in items)
                if (item is JsonMap) LibriVoxBook.fromJson(item)
            ];
          },
        );
        if (books.isNotEmpty) sawBooks = true;
        for (final book in books) {
          final id = BookIdentity.archiveIdentifierFor(
              librivoxApiId: book.id, urlIarchive: book.urlIarchive);
          if (id == archiveId) return (names: book.narrators, sawBooks: true);
        }
        if (books.length < pageSize) break;
      }
    }
    return (names: null, sawBooks: sawBooks);
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

  /// Cache for [zipSizeBytes], keyed by archive.org identifier. A book's
  /// ZIP size never changes once published, so this never needs
  /// invalidating — only re-populating per identifier the first time it is
  /// asked for.
  final Map<String, int?> _zipSizeCache = {};

  /// The size, in bytes, of the "64Kbps MP3" ZIP archive.org would serve
  /// for [identifier] at
  /// `https://archive.org/compress/<identifier>/formats=64KBPS%20MP3&file=/<identifier>.zip`
  /// — the same URL [LibriVoxBook.urlZipFile] points at.
  ///
  /// archive.org's `/compress` endpoint builds that ZIP on the fly and
  /// does not expose a `Content-Length` up front, so this instead sums the
  /// `size` field of every file in the item's `/metadata/<id>/files`
  /// listing whose `format` is `"64Kbps MP3"` — the same files the ZIP
  /// would contain — which is an accurate proxy (verified against
  /// `odyssey_1709_librivox`: 115.8 MB via this sum against the ZIP
  /// archive.org actually serves).
  ///
  /// Never throws: a network failure, a timeout, or metadata with no
  /// matching files all resolve to `null` so the caller can show the
  /// download button without a size line rather than break the sheet.
  Future<int?> zipSizeBytes(String identifier) async {
    if (identifier.isEmpty) return null;
    if (_zipSizeCache.containsKey(identifier)) {
      return _zipSizeCache[identifier];
    }

    int? total;
    try {
      final response = await _client
          .get(
            Uri.parse('https://archive.org/metadata/$identifier/files'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final files = data is JsonMap ? data['result'] : data;
        if (files is List) {
          var sum = 0;
          var matched = false;
          for (final entry in files) {
            if (entry is JsonMap && entry['format'] == '64Kbps MP3') {
              final size = entry['size'];
              final bytes = size is String ? int.tryParse(size) : size as int?;
              if (bytes != null) {
                sum += bytes;
                matched = true;
              }
            }
          }
          if (matched) total = sum;
        }
      }
    } catch (e) {
      debugPrint('LibriVox zip size error: $e');
    }

    _zipSizeCache[identifier] = total;
    return total;
  }
}

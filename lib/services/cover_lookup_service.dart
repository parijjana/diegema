import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/network/user_agent.dart';

/// Online, last-resort cover lookup for a locally imported book that had no
/// embedded art (`local_book_metadata_io.dart`, step 1) and no folder image
/// (step 2). Only ever called after both of those found nothing, and only
/// with a title (an author strengthens the match but is optional).
///
/// Two sources, tried in order:
/// 1. **LibriVox via the Internet Archive** — preferred, since LibriVox
///    recordings are public domain under LibriVox's own policy. Archive.org
///    hosts the actual audio/cover for every LibriVox release.
/// 2. **Open Library** — last resort, for anything not on LibriVox. Its
///    *search* endpoint is rate-limited, so this is called at most once per
///    book; its cover-by-id endpoint is not.
///
/// No DRM, no AAX, no commercial-store scraping (Audible, Amazon, Google
/// Books, Goodreads, etc.) — only these two sources. Never throws; a 10s
/// timeout and any network/parse error just fall through to `null`.
class CoverLookupService {
  final http.Client _client;

  static const Map<String, String> _headers = {
    'User-Agent': kHttpUserAgent,
    'Accept': 'application/json',
  };
  static const Duration _timeout = Duration(seconds: 10);

  CoverLookupService({http.Client? client}) : _client = client ?? http.Client();

  /// Looks up a cover URL for a book titled [title] by [author] (optional).
  /// Returns `null` when neither source has a strong match, or on any
  /// failure.
  Future<String?> lookupCoverUrl(
      {required String title, String? author}) async {
    if (title.trim().isEmpty) return null;

    final ia = await _lookupInternetArchive(title, author);
    if (ia != null) {
      // Source used — logged, never shown in the UI (see class doc).
      debugPrint(
          'CoverLookupService: cover for "$title" found via LibriVox/archive.org');
      return ia;
    }

    final ol = await _lookupOpenLibrary(title, author);
    if (ol != null) {
      debugPrint(
          'CoverLookupService: cover for "$title" found via Open Library');
      return ol;
    }

    return null;
  }

  Future<String?> _lookupInternetArchive(String title, String? author) async {
    try {
      final uri = Uri.https('archive.org', '/advancedsearch.php', {
        'q': 'collection:(librivoxaudio) AND title:($title)',
        'fl[]': 'identifier,title,creator',
        'rows': '5',
        'output': 'json',
      });
      final response =
          await _client.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final docs = (decoded['response'] as Map?)?['docs'];
      if (docs is! List) return null;

      for (final doc in docs) {
        if (doc is! Map) continue;
        final docTitle = doc['title']?.toString() ?? '';
        if (!_isStrongTitleMatch(title, docTitle)) continue;

        final creators = _asStringList(doc['creator']);
        if (!_authorMatchesOrUnknown(author, creators)) continue;

        final identifier = doc['identifier']?.toString();
        if (identifier == null || identifier.isEmpty) continue;
        return 'https://archive.org/services/img/$identifier';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _lookupOpenLibrary(String title, String? author) async {
    try {
      final uri = Uri.https('openlibrary.org', '/search.json', {
        'title': title,
        if (author != null && author.trim().isNotEmpty) 'author': author,
        'limit': '3',
        'fields': 'title,author_name,cover_i',
      });
      final response =
          await _client.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final docs = decoded['docs'];
      if (docs is! List) return null;

      for (final doc in docs) {
        if (doc is! Map) continue;
        final docTitle = doc['title']?.toString() ?? '';
        if (!_isStrongTitleMatch(title, docTitle)) continue;

        final authorNames = _asStringList(doc['author_name']);
        if (!_authorMatchesOrUnknown(author, authorNames)) continue;

        final coverId = doc['cover_i'];
        if (coverId == null) continue;
        return 'https://covers.openlibrary.org/b/id/$coverId-L.jpg?default=false';
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// A match is accepted on title alone when either side's author is
/// unknown; when both are known, they must agree too.
bool _authorMatchesOrUnknown(String? author, List<String> candidates) {
  if (author == null || author.trim().isEmpty) return true;
  if (candidates.isEmpty) return true;
  final normalized = _normalizeAuthor(author);
  return candidates.any((c) => _normalizeAuthor(c) == normalized);
}

List<String> _asStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return [value.toString()];
}

bool _isStrongTitleMatch(String a, String b) {
  final normA = _normalizeTitle(a);
  final normB = _normalizeTitle(b);
  return normA.isNotEmpty && normA == normB;
}

/// Lowercases, strips a trailing `(version N)` and all punctuation, and
/// drops a leading "the"/"a"/"an" — so "The Odyssey for Boys and Girls
/// (version 2)" and "Odyssey for Boys and Girls" compare equal.
String _normalizeTitle(String title) {
  var s = title.toLowerCase();
  s = s.replaceAll(RegExp(r'\(\s*version\s*\d+\s*\)'), ' ');
  s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceFirst(RegExp(r'^(the|a|an)\s+'), '');
  return s.trim();
}

String _normalizeAuthor(String author) {
  var s = author.toLowerCase();
  s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

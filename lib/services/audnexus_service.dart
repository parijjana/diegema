import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/network/rate_limit_dispatcher.dart';

typedef JsonMap = Map<String, dynamic>;

class AudnexusService {
  final http.Client _client;
  final RateLimitDispatcher _rateLimiter;
  static const String _baseUrl = 'https://api.audnexus.com';

  AudnexusService({
    http.Client? client,
    RateLimitDispatcher? rateLimiter,
  })  : _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? RateLimitDispatcher();

  Future<JsonMap?> searchBook(String query) async {
    return _rateLimiter.dispatch<JsonMap?>(
      apiId: 'audnexus',
      call: () async {
        try {
          final response = await _client.get(
            Uri.parse('$_baseUrl/search/books?q=${Uri.encodeComponent(query)}'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = json.decode(response.body) as List;
            if (data.isNotEmpty) {
              return data.first as JsonMap;
            }
          }
        } catch (_) {}
        return null;
      },
    );
  }

  Future<JsonMap?> getBookMetadata(String asin) async {
    return _rateLimiter.dispatch<JsonMap?>(
      apiId: 'audnexus',
      call: () async {
        try {
          final response = await _client.get(
            Uri.parse('$_baseUrl/books/$asin'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            return json.decode(response.body) as JsonMap;
          }
        } catch (_) {}
        return null;
      },
    );
  }

  Future<List<dynamic>> getChapters(String asin) async {
    return _rateLimiter.dispatch<List<dynamic>>(
      apiId: 'audnexus',
      call: () async {
        try {
          final response = await _client.get(
            Uri.parse('$_baseUrl/books/$asin/chapters'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = json.decode(response.body) as JsonMap;
            return data['chapters'] as List? ?? [];
          }
        } catch (_) {}
        return [];
      },
    );
  }

  Future<JsonMap?> getAuthorMetadata(String name) async {
    return _rateLimiter.dispatch<JsonMap?>(
      apiId: 'audnexus',
      call: () async {
        try {
          final response = await _client.get(
            Uri.parse('$_baseUrl/search/authors?q=${Uri.encodeComponent(name)}'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = json.decode(response.body) as List;
            if (data.isNotEmpty) {
              final first = data.first as JsonMap;
              final id = first['id'];
              if (id != null) {
                final detailResp = await _client.get(
                  Uri.parse('$_baseUrl/authors/$id'),
                ).timeout(const Duration(seconds: 15));

                if (detailResp.statusCode == 200) {
                  return json.decode(detailResp.body) as JsonMap;
                }
              }
            }
          }
        } catch (_) {}
        return null;
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'url_policy.dart';

/// A request, or a redirect it received, that the URL policy refuses.
class UrlPolicyException implements Exception {
  final String url;
  final String reason;
  const UrlPolicyException(this.url, this.reason);

  @override
  String toString() => 'UrlPolicyException($reason): $url';
}

/// An HTTP client that enforces the URL policy on the first request and on
/// every redirect hop (audit S-11).
///
/// It asks the inner client not to follow redirects and follows them itself,
/// so a redirect to plain `http://` or to a host off the allowlist is
/// refused instead of silently followed. Only GET and HEAD are supported
/// (the app never sends anything else). Not for web: browsers follow
/// redirects themselves and hide them from the page.
class PolicyHttpClient extends http.BaseClient {
  final http.Client _inner;
  final int maxRedirects;

  PolicyHttpClient(this._inner, {this.maxRedirects = 5});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      throw UrlPolicyException(request.url.toString(), 'method not allowed');
    }
    var url = request.url;
    for (var hop = 0;; hop++) {
      final permitted = permittedFetchUrl(url.toString());
      // Redirects (and requests) must already be https: an http hop is
      // refused, not upgraded, so a downgrade is visible.
      if (permitted == null || url.scheme.toLowerCase() != 'https') {
        throw UrlPolicyException(url.toString(),
            hop == 0 ? 'url not allowed' : 'redirect not allowed');
      }
      final next = http.Request(request.method, Uri.parse(permitted))
        ..followRedirects = false
        ..headers.addAll(request.headers);
      final response = await _inner.send(next);
      final isRedirect =
          const {301, 302, 303, 307, 308}.contains(response.statusCode);
      final location = response.headers['location'];
      if (!isRedirect || location == null) return response;
      // Discard the redirect body.
      await response.stream.drain<void>();
      if (hop >= maxRedirects) {
        throw UrlPolicyException(url.toString(), 'too many redirects');
      }
      url = url.resolve(location);
    }
  }

  @override
  void close() => _inner.close();
}

/// The client every service uses: [inner] (or a fresh one) behind the URL
/// policy. On web the browser owns redirects, so [inner] is returned as is
/// and callers rely on the up-front URL check alone.
http.Client policyClient([http.Client? inner]) {
  final client = inner ?? http.Client();
  return kIsWeb ? client : PolicyHttpClient(client);
}

/// Which remote URLs the app will fetch or stream (audit S-11).
///
/// Everything remote comes from LibriVox or archive.org. A catalogue entry
/// that points anywhere else, uses another scheme (`file:`, `ftp:`), or asks
/// for cleartext to a host we know speaks HTTPS is not trusted: Windows plays
/// through libmpv, which would otherwise happily fetch `http://` and
/// `file://` from an enclosure.
///
/// Policy: https only, on `librivox.org`, `archive.org` and their
/// subdomains. A plain `http://` URL on one of those hosts is upgraded to
/// https; anything else is refused (null).
const List<String> allowedRemoteHosts = ['librivox.org', 'archive.org'];

bool _hostAllowed(String host) {
  final h = host.toLowerCase();
  for (final base in allowedRemoteHosts) {
    if (h == base || h.endsWith('.$base')) return true;
  }
  return false;
}

/// [raw] as the https URL to use, or null if the policy refuses it.
String? permittedRemoteUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;
  if (!_hostAllowed(uri.host)) return null;
  // Any explicit port other than 443 is not what these hosts serve.
  if (uri.hasPort && uri.port != 443 && uri.port != 80) return null;
  return uri.replace(scheme: 'https', port: null).toString();
}

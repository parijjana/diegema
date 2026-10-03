import 'dart:convert';

/// What a "Link a device" QR carries (SYNC_DESIGN §4): the group key
/// itself, so it never crosses the network, plus where to reach the device
/// showing it. A Mac doesn't listen, so its code has no port; the device
/// that scans it listens instead and the Mac dials it.
class LinkCode {
  static const prefix = 'DIEGEMALINK1.';

  final List<int> groupKey;

  /// IPv4 addresses of the device showing the code, a hint only: discovery
  /// by tag is the fallback.
  final List<String> addresses;

  /// Null when the showing device doesn't listen.
  final int? port;

  /// The showing device's name, for "Linked to `name`".
  final String name;
  final int expiresAtMillis;

  const LinkCode({
    required this.groupKey,
    required this.addresses,
    required this.port,
    required this.name,
    required this.expiresAtMillis,
  });

  /// How long a code shown on screen stays good.
  static const lifetime = Duration(minutes: 5);

  bool expiredAt(int nowMillis) => nowMillis >= expiresAtMillis;

  String encode() =>
      prefix +
      base64Url
          .encode(utf8.encode(jsonEncode({
            'k': base64Url.encode(groupKey),
            if (addresses.isNotEmpty) 'a': addresses,
            if (port != null) 'p': port,
            'n': name,
            'x': expiresAtMillis,
          })))
          .replaceAll('=', '');

  /// Null for anything that isn't a well-formed link code. Whitespace and
  /// line breaks (a pasted code) are ignored.
  static LinkCode? decode(String text) {
    final t = text.replaceAll(RegExp(r'\s'), '');
    if (!t.startsWith(prefix)) return null;
    try {
      final body = t.substring(prefix.length);
      final json = jsonDecode(utf8.decode(
          base64Url.decode(body.padRight((body.length + 3) & ~3, '='))));
      if (json is! Map<String, Object?>) return null;
      final key = base64Url.decode(json['k'] as String);
      if (key.length != 32) return null;
      final port = json['p'] as int?;
      if (port != null && (port <= 0 || port > 65535)) return null;
      return LinkCode(
        groupKey: key,
        addresses: [
          for (final a in (json['a'] as List? ?? const [])) a as String
        ],
        port: port,
        name: json['n'] as String? ?? '',
        expiresAtMillis: json['x'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Where [LibriVoxService] keeps its search cache between launches, so a
/// cold start shows Discover's shelves at once instead of waiting ~20s on
/// the LibriVox feed.
///
/// Backed by `shared_preferences` (works on web too). Like `UiPreferences`,
/// every call is defensive: a missing platform channel or a bad write just
/// means no disk cache, never a broken screen.
class SearchCacheStore {
  static const String _key = 'discover.search_cache.v1';

  /// In-memory store used by tests; replaces `shared_preferences` entirely.
  final Map<String, String>? _overrides;

  const SearchCacheStore({Map<String, String>? overrides})
      : _overrides = overrides;

  Future<String?> read() async {
    final overrides = _overrides;
    if (overrides != null) return overrides[_key];
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_key] = value;
      return;
    }
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value);
    } catch (_) {
      // No disk cache this time; the in-memory one still works.
    }
  }
}

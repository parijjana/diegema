import 'package:shared_preferences/shared_preferences.dart';

/// The folders the user has added as library locations: places on the
/// device Diegema reads books from **in place**. It never copies, moves or
/// writes anything there — see `library_locations_scanner_io.dart`.
///
/// Stored as a plain string list in `shared_preferences`. Pure Dart (no
/// `dart:io`), so it is safe to import from the web build too.
class LibraryLocationsStore {
  static const String _key = 'library_locations.v1';

  /// Security-scoped bookmarks (macOS/iOS), one `"<base64>\t<path>"` per
  /// location. Base64 never contains a tab, so the first tab splits them.
  static const String _bookmarksKey = 'library_locations.bookmarks.v1';

  /// In-memory store used by tests; replaces `shared_preferences` entirely.
  final Map<String, List<String>>? _overrides;

  const LibraryLocationsStore({Map<String, List<String>>? overrides})
      : _overrides = overrides;

  Future<List<String>> read() => _readList(_key);

  /// Adds [path] unless it is already a location. Returns false when it was.
  /// A [bookmark] is stored (or refreshed) either way.
  Future<bool> add(String path, {String? bookmark}) async {
    if (bookmark != null) await setBookmark(path, bookmark);
    final current = await read();
    if (current.contains(path)) return false;
    await _writeList(_key, [...current, path]);
    return true;
  }

  Future<void> remove(String path) async {
    final current = await read();
    await _writeList(_key, current.where((l) => l != path).toList());
    final bookmarks = await readBookmarks();
    if (bookmarks.remove(path) != null) await _writeBookmarks(bookmarks);
  }

  /// Bookmarks by location path.
  Future<Map<String, String>> readBookmarks() async {
    return {
      for (final entry in await _readList(_bookmarksKey))
        if (entry.contains('\t'))
          entry.substring(entry.indexOf('\t') + 1):
              entry.substring(0, entry.indexOf('\t')),
    };
  }

  Future<void> setBookmark(String path, String bookmark) async {
    final bookmarks = await readBookmarks();
    bookmarks[path] = bookmark;
    await _writeBookmarks(bookmarks);
  }

  Future<void> _writeBookmarks(Map<String, String> bookmarks) => _writeList(
      _bookmarksKey,
      [for (final e in bookmarks.entries) '${e.value}\t${e.key}']);

  Future<List<String>> _readList(String key) async {
    final overrides = _overrides;
    if (overrides != null) return List.of(overrides[key] ?? const []);
    try {
      return (await SharedPreferences.getInstance()).getStringList(key) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<String> values) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[key] = values;
      return;
    }
    try {
      await (await SharedPreferences.getInstance()).setStringList(key, values);
    } catch (_) {
      // Not persisted this time; the folder can be added again.
    }
  }
}

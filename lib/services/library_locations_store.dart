import 'package:shared_preferences/shared_preferences.dart';

/// The folders the user has added as library locations: places on the
/// device Diegema reads books from **in place**. It never copies, moves or
/// writes anything there — see `library_locations_scanner_io.dart`.
///
/// Stored as a plain string list in `shared_preferences`. Pure Dart (no
/// `dart:io`), so it is safe to import from the web build too.
class LibraryLocationsStore {
  static const String _key = 'library_locations.v1';

  /// In-memory store used by tests; replaces `shared_preferences` entirely.
  final Map<String, List<String>>? _overrides;

  const LibraryLocationsStore({Map<String, List<String>>? overrides})
      : _overrides = overrides;

  Future<List<String>> read() async {
    final overrides = _overrides;
    if (overrides != null) return List.of(overrides[_key] ?? const []);
    try {
      return (await SharedPreferences.getInstance()).getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Adds [path] unless it is already a location. Returns false when it was.
  Future<bool> add(String path) async {
    final current = await read();
    if (current.contains(path)) return false;
    await _write([...current, path]);
    return true;
  }

  Future<void> remove(String path) async {
    final current = await read();
    await _write(current.where((l) => l != path).toList());
  }

  Future<void> _write(List<String> locations) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_key] = locations;
      return;
    }
    try {
      await (await SharedPreferences.getInstance())
          .setStringList(_key, locations);
    } catch (_) {
      // Not persisted this time; the folder can be added again.
    }
  }
}

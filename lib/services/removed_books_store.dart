import 'package:shared_preferences/shared_preferences.dart';

/// Ids of library-folder books the user removed from the library. The
/// folder scan skips these so a removed book does not reappear on the next
/// scan, while its files (which Diegema never owns) stay untouched.
///
/// Pure Dart, safe for the web build.
class RemovedBooksStore {
  static const String _key = 'removed_book_ids.v1';
  final Map<String, List<String>>? _overrides;

  const RemovedBooksStore({Map<String, List<String>>? overrides})
      : _overrides = overrides;

  Future<Set<String>> read() async {
    final o = _overrides;
    if (o != null) return (o[_key] ?? const []).toSet();
    try {
      return ((await SharedPreferences.getInstance()).getStringList(_key) ?? [])
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> add(String id) async {
    final next = (await read())..add(id);
    final o = _overrides;
    if (o != null) {
      o[_key] = next.toList();
      return;
    }
    try {
      await (await SharedPreferences.getInstance())
          .setStringList(_key, next.toList());
    } catch (_) {}
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ids of books the user hid from the Library on THIS device.
///
/// Hiding is a per-device view preference: it is never synced, and it does
/// not touch files, progress, bookmarks or downloads (it is not removal).
/// Ids are opaque strings. Today they are book ids; later sync work may put
/// portable keys in the same set, so nothing here assumes a format.
///
/// Pure Dart, safe for the web build.
class HiddenBooksStore {
  static const String _key = 'hidden_book_ids.v1';

  /// Bumped after every change made through any instance, so screens that
  /// show the library can reload right away. Listen with
  /// `HiddenBooksStore.changes.addListener`.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final Map<String, List<String>>? _overrides;

  const HiddenBooksStore({Map<String, List<String>>? overrides})
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

  Future<void> hide(String id) => _change((ids) => ids.add(id));

  Future<void> unhide(String id) => _change((ids) => ids.remove(id));

  Future<void> _change(void Function(Set<String>) edit) async {
    final next = await read();
    edit(next);
    final sorted = next.toList()..sort();
    final o = _overrides;
    if (o != null) {
      o[_key] = sorted;
    } else {
      try {
        await (await SharedPreferences.getInstance())
            .setStringList(_key, sorted);
      } catch (_) {}
    }
    changes.value++;
  }
}

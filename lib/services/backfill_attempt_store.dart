import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where [LocalCoverBackfillService] remembers which local books it has
/// already tried (and failed) to find a cover for, keyed by book id and
/// timestamped, so a book with no findable art isn't re-queried on every
/// app launch — same `shared_preferences` technique as
/// `search_cache_store.dart`.
///
/// Pure Dart (no `dart:io`), so it's safe to import from a file compiled
/// into the web build too, even though the backfill itself is IO-only.
class BackfillAttemptStore {
  static const String _key = 'local_cover_backfill.attempted.v1';

  /// In-memory store used by tests; replaces `shared_preferences` entirely.
  final Map<String, String>? _overrides;

  const BackfillAttemptStore({Map<String, String>? overrides})
      : _overrides = overrides;

  /// Book id -> when it was last attempted.
  Future<Map<String, DateTime>> read() async {
    final raw = await _readRaw();
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final parsed = DateTime.tryParse(entry.value as String);
        if (parsed != null) result[entry.key] = parsed;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Map<String, DateTime> attempts) async {
    final encoded = jsonEncode(
        attempts.map((id, at) => MapEntry(id, at.toIso8601String())));
    await _writeRaw(encoded);
  }

  Future<String?> _readRaw() async {
    final overrides = _overrides;
    if (overrides != null) return overrides[_key];
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRaw(String value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_key] = value;
      return;
    }
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value);
    } catch (_) {
      // No disk record this time; worst case a book gets re-attempted.
    }
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import 'librivox_service.dart';

/// One-off: gives LibriVox books saved before schema v5 their readers.
///
/// One rate-limited LibriVox call per book that lacks readers. Finishes
/// (sets the done flag) only when every book was either filled or answered
/// "not found"; if any call failed it stays unset and is retried on a later
/// launch, at most [maxAttempts] launches in all. Never throws.
class NarratorBackfillService {
  static const String doneKey = 'narrator_backfill.done.v1';
  static const String attemptsKey = 'narrator_backfill.attempts.v1';
  static const int maxAttempts = 3;

  final AppDatabase db;
  final LibriVoxService service;

  /// In-memory prefs for tests; null uses `shared_preferences`.
  final Map<String, Object>? _overrides;

  NarratorBackfillService({
    required this.db,
    required this.service,
    Map<String, Object>? overrides,
  }) : _overrides = overrides;

  Future<bool> get isDone async => (await _getInt(doneKey)) == 1;

  Future<void> run() async {
    try {
      if (await isDone) return;
      final attempts = await _getInt(attemptsKey);
      if (attempts >= maxAttempts) return;
      await _setInt(attemptsKey, attempts + 1);

      final books = await db.getAllAudiobooks();
      var failed = false;
      for (final book in books) {
        if (book.origin != BookIdentity.originLibrivox ||
            book.narrators.isNotEmpty) {
          continue;
        }
        try {
          final names =
              await service.narratorsForArchiveId(book.id, book.title);
          if (names != null && names.isNotEmpty) {
            await db.setNarrators(book.id, names);
          }
          // null / empty: LibriVox has no readers for it; unresolvable.
        } catch (_) {
          failed = true;
          // A dead network will fail every book; stop rather than hammer.
          break;
        }
      }
      if (!failed) await _setInt(doneKey, 1);
    } catch (_) {
      // Best-effort maintenance; never surfaces to the user.
    }
  }

  Future<int> _getInt(String key) async {
    final o = _overrides;
    if (o != null) return (o[key] as int?) ?? 0;
    try {
      return (await SharedPreferences.getInstance()).getInt(key) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _setInt(String key, int value) async {
    final o = _overrides;
    if (o != null) {
      o[key] = value;
      return;
    }
    try {
      await (await SharedPreferences.getInstance()).setInt(key, value);
    } catch (_) {}
  }
}

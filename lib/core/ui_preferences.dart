import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small, non-content UI preferences that must survive a restart but do not
/// belong in the audiobook schema — the drift schema is for library data,
/// not for "is this row expanded".
///
/// Backed by `shared_preferences`, which works on web too, so the
/// `DEMO_MODE` build behaves the same as native. Every read is defensive:
/// if the platform channel is unavailable (as in a bare widget test) the
/// default is returned rather than throwing, because a missing preference
/// must never be able to break a screen.
class UiPreferences {
  static const String _pinnedRowVisibleKey = 'now_playing.pinned_row_visible';

  /// In-memory store used by tests. When supplied it replaces
  /// `shared_preferences` entirely, so no platform channel is touched.
  final Map<String, Object>? _overrides;

  const UiPreferences({Map<String, Object>? overrides})
      : _overrides = overrides;

  Future<bool> getPinnedRowVisible({bool defaultValue = true}) async {
    final overrides = _overrides;
    if (overrides != null) {
      final value = overrides[_pinnedRowVisibleKey];
      return value is bool ? value : defaultValue;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pinnedRowVisibleKey) ?? defaultValue;
    } catch (e) {
      debugPrint('UiPreferences: read failed, using default: $e');
      return defaultValue;
    }
  }

  Future<void> setPinnedRowVisible(bool value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_pinnedRowVisibleKey] = value;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pinnedRowVisibleKey, value);
    } catch (e) {
      debugPrint('UiPreferences: write failed: $e');
    }
  }
}

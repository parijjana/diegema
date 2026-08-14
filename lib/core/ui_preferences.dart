import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
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
  static const String _themeModeKey = 'appearance.theme_mode';

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

  /// The theme the user chose, or [ThemeMode.system] when they never have.
  ///
  /// System is the default deliberately: an install that has expressed no
  /// preference should follow the OS rather than pin itself to light, which
  /// is what the app did for as long as this value lived only in `State`.
  Future<ThemeMode> getThemeMode({
    ThemeMode defaultValue = ThemeMode.system,
  }) async {
    final overrides = _overrides;
    if (overrides != null) {
      final value = overrides[_themeModeKey];
      return value is String ? _decodeThemeMode(value, defaultValue) : defaultValue;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_themeModeKey);
      return stored == null
          ? defaultValue
          : _decodeThemeMode(stored, defaultValue);
    } catch (e) {
      debugPrint('UiPreferences: read failed, using default: $e');
      return defaultValue;
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    final encoded = _encodeThemeMode(value);
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_themeModeKey] = encoded;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, encoded);
    } catch (e) {
      debugPrint('UiPreferences: write failed: $e');
    }
  }

  /// Stored as a name rather than an index so that reordering or extending
  /// [ThemeMode] upstream cannot silently reinterpret an existing install's
  /// choice. An unrecognised name — a key written by a newer build, then
  /// read back by an older one — falls back to the default instead of
  /// throwing, in keeping with every other read here.
  static String _encodeThemeMode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decodeThemeMode(String raw, ThemeMode defaultValue) =>
      switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => defaultValue,
      };
}

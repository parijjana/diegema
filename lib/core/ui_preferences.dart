import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'playback_constants.dart';
import 'player_controls_style.dart';

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
  static const String _skipSecondsKey = 'playback.skip_seconds';
  static const String _defaultSpeedKey = 'playback.default_speed';
  static const String _bookSpeedPrefix = 'playback.book_speed.';
  static const String _controlsStyleKey = 'now_playing.controls_style';
  static const String _transportStyleKey = 'now_playing.transport_style';
  static const String _accentKey = 'appearance.accent';
  static const String _backgroundKey = 'appearance.background';
  static const String _shadowsKey = 'appearance.shadows';
  static const String _libraryLayoutKey = 'library.layout';
  static const String _ambienceKey = 'ambience.v1';
  static const String _downloadsWifiOnlyKey = 'downloads.wifi_only';

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
      return value is String
          ? _decodeThemeMode(value, defaultValue)
          : defaultValue;
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

  /// How far the skip controls jump, in seconds. Validated against
  /// [kSkipSecondsOptions] on the way out rather than trusted: a value the
  /// panel can no longer offer would otherwise be stuck on the device
  /// forever, with no UI able to change it.
  Future<int> getSkipSeconds({int defaultValue = kSkipSeconds}) async {
    final overrides = _overrides;
    if (overrides != null) {
      final value = overrides[_skipSecondsKey];
      return value is int && kSkipSecondsOptions.contains(value)
          ? value
          : defaultValue;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_skipSecondsKey);
      return stored != null && kSkipSecondsOptions.contains(stored)
          ? stored
          : defaultValue;
    } catch (e) {
      debugPrint('UiPreferences: read failed, using default: $e');
      return defaultValue;
    }
  }

  Future<void> setSkipSeconds(int value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_skipSecondsKey] = value;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_skipSecondsKey, value);
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

  /// The Now Playing action-row style.
  Future<PlayerControlsStyle> getPlayerControlsStyle() =>
      _getStyle(_controlsStyleKey, PlayerControlsStyle.tiles);

  Future<void> setPlayerControlsStyle(PlayerControlsStyle style) =>
      _setStyle(_controlsStyleKey, style);

  /// The speed a book opens at when it has none of its own. Validated
  /// against [kPlaybackSpeedOptions] on the way out, like the skip
  /// interval: a stored value the app no longer offers falls back.
  Future<double> getDefaultSpeed({double defaultValue = 1.0}) async =>
      await _getSpeed(_defaultSpeedKey) ?? defaultValue;
  Future<void> setDefaultSpeed(double value) =>
      _setSpeed(_defaultSpeedKey, value);

  /// A book's own speed, remembered from the last time the user changed it
  /// while it played; null when it has never been changed. Keyed by book id
  /// here rather than stored in the drift schema, which is for library data.
  Future<double?> getBookSpeed(String bookId) =>
      _getSpeed('$_bookSpeedPrefix$bookId');
  Future<void> setBookSpeed(String bookId, double value) =>
      _setSpeed('$_bookSpeedPrefix$bookId', value);

  Future<double?> _getSpeed(String key) async {
    final overrides = _overrides;
    Object? stored;
    if (overrides != null) {
      stored = overrides[key];
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        stored = prefs.get(key);
      } catch (e) {
        debugPrint('UiPreferences: read failed, using default: $e');
        return null;
      }
    }
    return stored is num && kPlaybackSpeedOptions.contains(stored.toDouble())
        ? stored.toDouble()
        : null;
  }

  Future<void> _setSpeed(String key, double value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[key] = value;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('UiPreferences: write failed: $e');
    }
  }

  /// The Now Playing transport (play, skip, chapter) style.
  Future<PlayerControlsStyle> getTransportStyle() =>
      _getStyle(_transportStyleKey, PlayerControlsStyle.round);

  Future<void> setTransportStyle(PlayerControlsStyle style) =>
      _setStyle(_transportStyleKey, style);

  /// Styles are stored by enum name, so an unknown or missing value falls
  /// back to [fallback].
  Future<PlayerControlsStyle> _getStyle(
      String key, PlayerControlsStyle fallback) async {
    final overrides = _overrides;
    if (overrides != null) {
      final value = overrides[key];
      return PlayerControlsStyle.fromName(value is String ? value : null,
          fallback: fallback);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return PlayerControlsStyle.fromName(prefs.getString(key),
          fallback: fallback);
    } catch (e) {
      debugPrint('UiPreferences: read failed, using default: $e');
      return fallback;
    }
  }

  Future<void> _setStyle(String key, PlayerControlsStyle style) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[key] = style.name;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, style.name);
    } catch (e) {
      debugPrint('UiPreferences: write failed: $e');
    }
  }

  /// The chosen accent palette id; null when never chosen. Unknown ids are
  /// resolved (to the default) by the palette lookup, not here.
  Future<String?> getAccentId() => _getString(_accentKey);
  Future<void> setAccentId(String id) => _setString(_accentKey, id);

  /// The chosen background pair id; null when never chosen.
  Future<String?> getBackgroundId() => _getString(_backgroundKey);
  Future<void> setBackgroundId(String id) => _setString(_backgroundKey, id);

  /// The drop-shadow style's enum name; null when never chosen.
  Future<String?> getShadowsName() => _getString(_shadowsKey);
  Future<void> setShadowsName(String name) => _setString(_shadowsKey, name);

  /// The Library layout's enum name (`list` or `tiles`); null when never
  /// chosen. Unknown names are resolved (to list) by `LibraryLayout.fromName`.
  Future<String?> getLibraryLayoutName() => _getString(_libraryLayoutKey);
  Future<void> setLibraryLayoutName(String name) =>
      _setString(_libraryLayoutKey, name);

  /// The ambience mixer's saved settings, as JSON (see `AmbienceState`).
  Future<String?> getAmbienceJson() => _getString(_ambienceKey);
  Future<void> setAmbienceJson(String json) => _setString(_ambienceKey, json);

  /// Whether downloads wait for Wi-Fi (Settings > Downloads). Off unless
  /// chosen: most people expect a tap on Download to start downloading.
  Future<bool> getDownloadsWifiOnly() async {
    final overrides = _overrides;
    if (overrides != null) {
      final value = overrides[_downloadsWifiOnlyKey];
      return value is bool ? value : false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_downloadsWifiOnlyKey) ?? false;
    } catch (e) {
      debugPrint('UiPreferences: read failed, using default: $e');
      return false;
    }
  }

  Future<void> setDownloadsWifiOnly(bool value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[_downloadsWifiOnlyKey] = value;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_downloadsWifiOnlyKey, value);
    } catch (e) {
      debugPrint('UiPreferences: write failed: $e');
    }
  }

  Future<String?> _getString(String key) async {
    final overrides = _overrides;
    if (overrides != null) {
      final value = overrides[key];
      return value is String ? value : null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      debugPrint('UiPreferences: read failed, using default: $e');
      return null;
    }
  }

  Future<void> _setString(String key, String value) async {
    final overrides = _overrides;
    if (overrides != null) {
      overrides[key] = value;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('UiPreferences: write failed: $e');
    }
  }
}

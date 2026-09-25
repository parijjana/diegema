import 'package:flutter/material.dart';

import 'playback_constants.dart';
import 'player_controls_style.dart';
import 'ui_preferences.dart';

/// Every user-adjustable preference, in one place, read from and written
/// back to [UiPreferences].
///
/// This exists because the alternative does not scale: the theme used to be
/// a `bool` plus a `VoidCallback` threaded from `AudiobookApp` through
/// `HomeScreen` and `AppShell` to the two widgets that displayed the
/// toggle. That is four files touched per setting, and the settings panel
/// adds several. A [ChangeNotifier] behind an [InheritedNotifier] means a
/// new preference touches this class, the panel, and whatever reads it —
/// and nothing in between.
///
/// Reads are async and the first frame is not, so every value starts at its
/// default and is corrected by [load]. Nothing here blocks startup.
class AppSettings extends ChangeNotifier {
  final UiPreferences _preferences;

  /// A theme forced by the caller — the demo's `?theme=` deep link, or a
  /// test pinning a mode. It wins over the stored value at [load] time
  /// only: choosing a theme in the panel afterwards is still honoured, and
  /// still persists, because a deep link sets where you start and not where
  /// you have to stay.
  final ThemeMode? _forcedThemeMode;

  ThemeMode _themeMode;
  int _skipSeconds;
  PlayerControlsStyle _controlsStyle = PlayerControlsStyle.tiles;
  PlayerControlsStyle _transportStyle = PlayerControlsStyle.round;

  AppSettings({
    required UiPreferences preferences,
    ThemeMode? initialThemeMode,
  })  : _preferences = preferences,
        _forcedThemeMode = initialThemeMode,
        _themeMode = initialThemeMode ?? ThemeMode.system,
        _skipSeconds = kSkipSeconds;

  ThemeMode get themeMode => _themeMode;

  /// How far the rewind/fast-forward controls jump. Always one of
  /// [kSkipSecondsOptions].
  int get skipSeconds => _skipSeconds;

  /// Shape of the phone Now Playing Up next / Speed / Sleep row.
  PlayerControlsStyle get controlsStyle => _controlsStyle;

  /// Shape and size of the play, skip and chapter-jump buttons.
  PlayerControlsStyle get transportStyle => _transportStyle;

  /// Pulls the persisted values in. Safe to call once, from `initState`.
  Future<void> load() async {
    final storedTheme = _forcedThemeMode ?? await _preferences.getThemeMode();
    final storedSkip = await _preferences.getSkipSeconds();
    final storedStyle = await _preferences.getPlayerControlsStyle();
    final storedTransport = await _preferences.getTransportStyle();

    if (storedTheme == _themeMode &&
        storedSkip == _skipSeconds &&
        storedStyle == _controlsStyle &&
        storedTransport == _transportStyle) {
      return;
    }
    _themeMode = storedTheme;
    _skipSeconds = storedSkip;
    _controlsStyle = storedStyle;
    _transportStyle = storedTransport;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _preferences.setThemeMode(mode);
  }

  Future<void> setSkipSeconds(int seconds) async {
    if (seconds == _skipSeconds || !kSkipSecondsOptions.contains(seconds)) {
      return;
    }
    _skipSeconds = seconds;
    notifyListeners();
    await _preferences.setSkipSeconds(seconds);
  }

  Future<void> setControlsStyle(PlayerControlsStyle style) async {
    if (style == _controlsStyle) return;
    _controlsStyle = style;
    notifyListeners();
    await _preferences.setPlayerControlsStyle(style);
  }

  Future<void> setTransportStyle(PlayerControlsStyle style) async {
    if (style == _transportStyle) return;
    _transportStyle = style;
    notifyListeners();
    await _preferences.setTransportStyle(style);
  }
}

/// Puts [AppSettings] in scope for the whole app. An [InheritedNotifier], so
/// a widget that reads a setting rebuilds when it changes without anyone
/// having to thread a callback down to it.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this widget');
    return scope!.notifier!;
  }

  /// For widgets that may be built outside the app shell — notably in a
  /// widget test that pumps one screen in isolation rather than the whole
  /// app. Returns null instead of asserting, so a control can fall back to
  /// its default rather than requiring every test to build a scope.
  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}

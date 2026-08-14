import 'package:flutter/material.dart';

import 'playback_constants.dart';
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

  /// Pulls the persisted values in. Safe to call once, from `initState`.
  Future<void> load() async {
    final storedTheme =
        _forcedThemeMode ?? await _preferences.getThemeMode();
    final storedSkip = await _preferences.getSkipSeconds();

    if (storedTheme == _themeMode && storedSkip == _skipSeconds) return;
    _themeMode = storedTheme;
    _skipSeconds = storedSkip;
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

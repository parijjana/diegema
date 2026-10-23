import 'package:flutter/material.dart';

import 'playback_constants.dart';
import 'player_controls_style.dart';
import '../theme/app_palettes.dart';
import 'ui_preferences.dart';

/// How the Library screen lays its books out. Stored by name, so reordering
/// or adding a value never reinterprets a saved choice; an unknown stored
/// name falls back to [list].
enum LibraryLayout {
  list('List'),
  tiles('Grid');

  final String label;
  const LibraryLayout(this.label);

  static LibraryLayout fromName(String? name) => LibraryLayout.values
      .firstWhere((l) => l.name == name, orElse: () => LibraryLayout.list);
}

/// How the Library orders its books. Stored by name; unknown falls back to
/// [recent].
enum LibrarySort {
  recent('Recent'),
  title('Title'),
  author('Author'),
  progress('Progress');

  final String label;
  const LibrarySort(this.label);

  static LibrarySort fromName(String? name) => LibrarySort.values
      .firstWhere((s) => s.name == name, orElse: () => LibrarySort.recent);
}

/// Which books the Library shows. Stored by name; unknown falls back to
/// [all].
enum LibraryFilter {
  all('All'),
  inProgress('In progress'),
  finished('Finished'),
  downloaded('Downloaded'),
  local('Local');

  final String label;
  const LibraryFilter(this.label);

  static LibraryFilter fromName(String? name) => LibraryFilter.values
      .firstWhere((f) => f.name == name, orElse: () => LibraryFilter.all);
}

/// How far playback rewinds when resumed after a pause. Stored by name.
enum SkipBackOnResume {
  off('Off', 0),
  s5('Back 5 seconds', 5),
  s10('Back 10 seconds', 10),
  s30('Back 30 seconds', 30);

  final String label;
  final int seconds;
  const SkipBackOnResume(this.label, this.seconds);

  static SkipBackOnResume fromName(String? name) => SkipBackOnResume.values
      .firstWhere((s) => s.name == name, orElse: () => SkipBackOnResume.s5);
}

/// What happens when a book finishes. Stored by name.
enum AutoAdvance {
  stop('Stop'),
  nextBook('Next book');

  final String label;
  const AutoAdvance(this.label);

  static AutoAdvance fromName(String? name) => AutoAdvance.values
      .firstWhere((a) => a.name == name, orElse: () => AutoAdvance.stop);
}

/// In-app text size, applied on top of the system text scale. Stored by
/// name; unknown falls back to [system].
enum TextSizeChoice {
  system('Device setting', 1.0),
  small('Small', 0.9),
  large('Large', 1.15),
  larger('Larger', 1.3);

  final String label;
  final double factor;
  const TextSizeChoice(this.label, this.factor);

  static TextSizeChoice fromName(String? name) => TextSizeChoice.values
      .firstWhere((t) => t.name == name, orElse: () => TextSizeChoice.system);
}

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
  double _defaultSpeed = 1.0;
  PlayerControlsStyle _controlsStyle = PlayerControlsStyle.tiles;
  PlayerControlsStyle _transportStyle = PlayerControlsStyle.round;
  AccentPalette _accent = AccentPalette.fallback;
  BackgroundPair _background = BackgroundPair.fallback;
  ShadowStyle _shadows = ShadowStyle.off;
  bool _downloadsWifiOnly = false;
  LibraryLayout _libraryLayout = LibraryLayout.list;
  LibrarySort _librarySort = LibrarySort.recent;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  SkipBackOnResume _skipBackOnResume = SkipBackOnResume.s5;
  AutoAdvance _autoAdvance = AutoAdvance.stop;
  TextSizeChoice _textSize = TextSizeChoice.system;

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

  /// The speed books open at unless they have their own. Always one of
  /// [kPlaybackSpeedOptions].
  double get defaultSpeed => _defaultSpeed;

  /// Shape of the phone Now Playing Up next / Speed / Sleep row.
  PlayerControlsStyle get controlsStyle => _controlsStyle;

  /// Shape and size of the play, skip and chapter-jump buttons.
  PlayerControlsStyle get transportStyle => _transportStyle;

  /// The accent colour (Settings > Colours).
  AccentPalette get accent => _accent;

  /// The light/dark background pair (Settings > Colours).
  BackgroundPair get background => _background;

  /// Drop shadows under cards, tiles and buttons (Settings > Colours).
  ShadowStyle get shadows => _shadows;

  /// Whether downloads wait for Wi-Fi (Settings > Downloads).
  bool get downloadsWifiOnly => _downloadsWifiOnly;

  /// List or tiles in the Library (header toggle and Settings > Appearance).
  LibraryLayout get libraryLayout => _libraryLayout;

  /// Library ordering and filter (Library header controls).
  LibrarySort get librarySort => _librarySort;
  LibraryFilter get libraryFilter => _libraryFilter;

  /// Rewind applied when resuming after a pause (Settings > Playback).
  /// The playback service reads the stored value itself.
  SkipBackOnResume get skipBackOnResume => _skipBackOnResume;

  /// What happens when a book ends (Settings > Playback).
  AutoAdvance get autoAdvance => _autoAdvance;

  /// In-app text size (Settings > Appearance).
  TextSizeChoice get textSize => _textSize;

  /// Pulls the persisted values in. Safe to call once, from `initState`.
  Future<void> load() async {
    final storedTheme = _forcedThemeMode ?? await _preferences.getThemeMode();
    final storedSkip = await _preferences.getSkipSeconds();
    final storedSpeed = await _preferences.getDefaultSpeed();
    final storedStyle = await _preferences.getPlayerControlsStyle();
    final storedTransport = await _preferences.getTransportStyle();
    final storedAccent = AccentPalette.byId(await _preferences.getAccentId());
    final storedBackground =
        BackgroundPair.byId(await _preferences.getBackgroundId());
    final storedShadows =
        ShadowStyle.fromName(await _preferences.getShadowsName());
    final storedWifiOnly = await _preferences.getDownloadsWifiOnly();
    final storedLayout =
        LibraryLayout.fromName(await _preferences.getLibraryLayoutName());
    final storedSort =
        LibrarySort.fromName(await _preferences.getLibrarySortName());
    final storedFilter =
        LibraryFilter.fromName(await _preferences.getLibraryFilterName());
    final storedSkipBack =
        SkipBackOnResume.fromName(await _preferences.getSkipBackOnResumeName());
    final storedAdvance =
        AutoAdvance.fromName(await _preferences.getAutoAdvanceName());
    final storedTextSize =
        TextSizeChoice.fromName(await _preferences.getTextSizeName());

    if (storedTheme == _themeMode &&
        storedSkip == _skipSeconds &&
        storedSpeed == _defaultSpeed &&
        storedStyle == _controlsStyle &&
        storedTransport == _transportStyle &&
        storedAccent == _accent &&
        storedBackground == _background &&
        storedShadows == _shadows &&
        storedWifiOnly == _downloadsWifiOnly &&
        storedLayout == _libraryLayout &&
        storedSort == _librarySort &&
        storedFilter == _libraryFilter &&
        storedSkipBack == _skipBackOnResume &&
        storedAdvance == _autoAdvance &&
        storedTextSize == _textSize) {
      return;
    }
    _themeMode = storedTheme;
    _skipSeconds = storedSkip;
    _defaultSpeed = storedSpeed;
    _controlsStyle = storedStyle;
    _transportStyle = storedTransport;
    _accent = storedAccent;
    _background = storedBackground;
    _shadows = storedShadows;
    _downloadsWifiOnly = storedWifiOnly;
    _libraryLayout = storedLayout;
    _librarySort = storedSort;
    _libraryFilter = storedFilter;
    _skipBackOnResume = storedSkipBack;
    _autoAdvance = storedAdvance;
    _textSize = storedTextSize;
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

  Future<void> setDefaultSpeed(double speed) async {
    if (speed == _defaultSpeed || !kPlaybackSpeedOptions.contains(speed)) {
      return;
    }
    _defaultSpeed = speed;
    notifyListeners();
    await _preferences.setDefaultSpeed(speed);
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

  Future<void> setAccent(AccentPalette accent) async {
    if (accent == _accent) return;
    _accent = accent;
    notifyListeners();
    await _preferences.setAccentId(accent.id);
  }

  Future<void> setBackground(BackgroundPair background) async {
    if (background == _background) return;
    _background = background;
    notifyListeners();
    await _preferences.setBackgroundId(background.id);
  }

  Future<void> setShadows(ShadowStyle shadows) async {
    if (shadows == _shadows) return;
    _shadows = shadows;
    notifyListeners();
    await _preferences.setShadowsName(shadows.name);
  }

  Future<void> setLibraryLayout(LibraryLayout layout) async {
    if (layout == _libraryLayout) return;
    _libraryLayout = layout;
    notifyListeners();
    await _preferences.setLibraryLayoutName(layout.name);
  }

  Future<void> setLibrarySort(LibrarySort sort) async {
    if (sort == _librarySort) return;
    _librarySort = sort;
    notifyListeners();
    await _preferences.setLibrarySortName(sort.name);
  }

  Future<void> setLibraryFilter(LibraryFilter filter) async {
    if (filter == _libraryFilter) return;
    _libraryFilter = filter;
    notifyListeners();
    await _preferences.setLibraryFilterName(filter.name);
  }

  Future<void> setSkipBackOnResume(SkipBackOnResume value) async {
    if (value == _skipBackOnResume) return;
    _skipBackOnResume = value;
    notifyListeners();
    await _preferences.setSkipBackOnResumeName(value.name);
  }

  Future<void> setAutoAdvance(AutoAdvance value) async {
    if (value == _autoAdvance) return;
    _autoAdvance = value;
    notifyListeners();
    await _preferences.setAutoAdvanceName(value.name);
  }

  Future<void> setTextSize(TextSizeChoice value) async {
    if (value == _textSize) return;
    _textSize = value;
    notifyListeners();
    await _preferences.setTextSizeName(value.name);
  }

  Future<void> setDownloadsWifiOnly(bool value) async {
    if (value == _downloadsWifiOnly) return;
    _downloadsWifiOnly = value;
    notifyListeners();
    await _preferences.setDownloadsWifiOnly(value);
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

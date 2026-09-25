import 'dart:async';

import 'package:flutter/material.dart';
import 'core/app_info.dart';
import 'core/app_settings.dart';
import 'core/demo_deeplink.dart';
import 'core/demo_mode.dart';
import 'core/host_page_demo_notice.dart';
import 'core/ui_preferences.dart';
import 'database/app_database.dart';
import 'main.dart';
import 'screens/library_screen.dart' show LibraryScanner;
import 'services/artwork_enrichment_service.dart';
import 'services/audio_playback_service.dart';
import 'services/librivox_downloader.dart';
import 'services/librivox_service.dart';
import 'services/local_cover_backfill_service.dart';
import 'theme/app_theme.dart';

/// Root widget. [database], [libriVoxService], [downloader], and
/// [artworkService] are optional injection points so tests can supply an
/// in-memory database and a mocked HTTP client instead of the real
/// path_provider-backed database and live librivox.org network calls that
/// the defaults use — and so the canned web demo (`DEMO_MODE=true`, see
/// `core/demo_mode.dart`) can supply its stub, network-free catalog
/// services without forking any widget.
class AudiobookApp extends StatefulWidget {
  final AppDatabase? database;
  final LibriVoxService? libriVoxService;
  final LibriVoxStreamAndDownloader? downloader;
  final ArtworkEnrichmentService? artworkService;

  /// Injectable so tests can supply a fake instead of the real
  /// `just_audio`-backed service — see the identical doc comment on
  /// `AppShell.audioService`, which this is threaded straight through to.
  final AudioPlaybackService? audioService;

  /// Injectable UI preference store, so widget tests never need the
  /// `shared_preferences` platform channel.
  final UiPreferences preferences;

  /// Injectable downloads-folder scan; see [LibraryScanner]. Tests pass a
  /// stub so no `path_provider` channel is touched.
  final LibraryScanner? libraryScanner;

  /// Which theme the app starts in, overriding whatever [preferences] has
  /// stored. Only tests and the demo deep link set this; leave it null and
  /// the persisted choice is loaded instead, defaulting to
  /// [ThemeMode.system]. The in-app toggle drives it at runtime.
  final ThemeMode? initialThemeMode;

  /// Demo-only query-string entry point; see [DemoDeepLink]. Ignored
  /// entirely outside `--dart-define=DEMO_MODE=true` builds.
  final DemoDeepLink deepLink;

  const AudiobookApp({
    super.key,
    this.initialThemeMode,
    this.database,
    this.libriVoxService,
    this.downloader,
    this.artworkService,
    this.audioService,
    this.preferences = const UiPreferences(),
    this.libraryScanner,
    this.deepLink = DemoDeepLink.none,
  });

  @override
  State<AudiobookApp> createState() => _AudiobookAppState();
}

class _AudiobookAppState extends State<AudiobookApp>
    with WidgetsBindingObserver {
  late final AppDatabase _db;
  late final AppSettings _settings;

  @override
  void initState() {
    super.initState();
    // Every value starts at its default and is corrected when `load`
    // returns. Reading preferences is asynchronous and the first frame is
    // not, so there is no arrangement in which the persisted values are
    // available here.
    _settings = AppSettings(
      preferences: widget.preferences,
      initialThemeMode: widget.initialThemeMode,
    );
    _settings.addListener(_onSettingsChanged);
    _db = widget.database ?? AppDatabase();
    WidgetsBinding.instance.addObserver(this);
    _settings.load();
    _syncHostPageTheme();

    // Step 4 of the local-import cover pipeline: once per launch, give
    // already-imported local books another shot at a cover. Only for a
    // real, non-injected database — widget/unit tests inject their own
    // [AppDatabase] (same reason [artworkService]/[libriVoxService] are
    // injectable) and must never trigger a real network call via
    // [CoverLookupService]'s default client.
    if (widget.database == null && !kDemoMode) {
      unawaited(LocalCoverBackfillService(db: _db).run());
    }
  }

  void _onSettingsChanged() {
    // `MaterialApp.themeMode` is read in `build`, so the app itself needs a
    // rebuild; the host page's CSS chrome needs telling separately.
    setState(_syncHostPageTheme);
  }

  /// Only relevant under [ThemeMode.system]: the app's own colours follow the
  /// OS automatically via [MaterialApp.themeMode], but the demo host page's
  /// chrome is plain CSS and has to be told, or it stays on the old theme
  /// while the app inside it flips.
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (_settings.themeMode != ThemeMode.system) return;
    setState(_syncHostPageTheme);
  }

  /// Whether the app is *showing* dark right now — which under
  /// [ThemeMode.system] is a question about the OS, not about [_themeMode].
  /// Read from the platform dispatcher rather than a [MediaQuery] because
  /// this widget sits above [MaterialApp], so there is no guaranteed
  /// `MediaQuery` ancestor to read from. Reached via `WidgetsBinding` — not
  /// `PlatformDispatcher.instance` — so that a widget test driving
  /// `tester.platformDispatcher` is actually obeyed.
  bool get _isDarkMode => switch (_settings.themeMode) {
        ThemeMode.light => false,
        ThemeMode.dark => true,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  /// Keeps the demo host page's chrome (the preview banner and the stage
  /// around the app — see `web/demo_banner.css`) on the same theme as the
  /// app. Demo-only and web-only: a no-op everywhere else, and never called
  /// at all outside `kDemoMode`, so a normal build is untouched.
  ///
  /// Without this the chrome follows the OS `prefers-color-scheme` while the
  /// app follows its own toggle, so flipping the theme inside the demo leaves
  /// a light page wrapped around a dark app.
  void _syncHostPageTheme() {
    if (!kDemoMode) return;
    setHostPageTheme(dark: _isDarkMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _settings.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: _settings,
      child: MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        // Both themes are supplied so the framework can cross-fade between
        // them; `themeMode` is what the settings panel actually drives. The
        // two `ThemeData` blocks of raw hex that used to live here are gone
        // — every value now comes from `lib/theme/`, built from
        // `design/tokens.css`.
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _settings.themeMode,
        home: HomeScreen(
          db: _db,
          preferences: widget.preferences,
          libraryScanner: widget.libraryScanner,
          deepLink: widget.deepLink,
          libriVoxService: widget.libriVoxService,
          downloader: widget.downloader,
          artworkService: widget.artworkService,
          audioService: widget.audioService,
        ),
      ),
    );
  }
}

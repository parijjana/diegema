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
import 'services/sync/sync_controller.dart';
import 'services/download_manager.dart';
import 'services/librivox_downloader.dart';
import 'services/librivox_service.dart';
import 'services/ambience_service.dart';
import 'services/local_cover_backfill_service.dart';
import 'services/local_import_migration_service.dart';
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

  /// Whether to run the once-per-launch cover backfill for imported books.
  /// Only `main.dart` turns this on.
  final bool runCoverBackfill;

  /// Whether to run the once-per-launch local-import path migration (moves
  /// already-imported chapters that still point outside
  /// `diegema/library/<bookId>/` — e.g. file_picker's Android cache dir —
  /// into that durable location; see
  /// `services/local_import_migration_service_io.dart`). A sibling of
  /// [runCoverBackfill], set only by `main.dart` for the same reason: tests
  /// leave it off so they never touch real storage, and it runs before the
  /// cover backfill so a freshly-migrated book's files are already in
  /// their durable location by the time the backfill re-reads them.
  final bool runImportMigration;
  final LibriVoxService? libriVoxService;
  final LibriVoxStreamAndDownloader? downloader;
  final ArtworkEnrichmentService? artworkService;

  /// Injectable so tests can supply a fake instead of the real
  /// `just_audio`-backed service — see the identical doc comment on
  /// `AppShell.audioService`, which this is threaded straight through to.
  final AudioPlaybackService? audioService;

  /// The background-sound channel. Null on the web demo and in tests that
  /// don't exercise it; the player then hides the ambience controls.
  final AmbienceService? ambience;

  /// The app-wide download queue, put in scope by [DownloadsScope]. Null on
  /// the web demo and in tests that don't supply one; Discover's Download
  /// is then unavailable.
  final DownloadManager? downloads;

  /// Linked-device sync; null on the web, in the demo and in tests that
  /// don't supply one (the sync UI then doesn't appear).
  final SyncController? sync;

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
    this.runCoverBackfill = false,
    this.runImportMigration = false,
    this.libriVoxService,
    this.downloader,
    this.artworkService,
    this.audioService,
    this.ambience,
    this.downloads,
    this.sync,
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
    _settings.load().then((_) => _syncDownloads());
    widget.ambience?.init();
    _syncHostPageTheme();

    // Once per launch, before the cover backfill: migrate already-imported
    // local books whose chapters still point outside
    // `diegema/library/<bookId>/` (see
    // `services/local_import_migration_service_io.dart`), then give
    // already-imported local books another shot at a cover (step 4 of the
    // local-import cover pipeline). Both are opt-in rather than inferred
    // from "no injected database": main.dart injects its native database
    // too (for background playback), which would silently disable this in
    // the real app. Tests leave both off so they never touch real storage
    // or hit [CoverLookupService]'s real network client.
    if (!kDemoMode && (widget.runImportMigration || widget.runCoverBackfill)) {
      unawaited(_runStartupMaintenance());
    }
  }

  Future<void> _runStartupMaintenance() async {
    if (widget.runImportMigration) {
      await LocalImportMigrationService(db: _db).run();
    }
    if (widget.runCoverBackfill) {
      await LocalCoverBackfillService(db: _db).run();
    }
  }

  void _onSettingsChanged() {
    _syncDownloads();
    // `MaterialApp.themeMode` is read in `build`, so the app itself needs a
    // rebuild; the host page's CSS chrome needs telling separately.
    setState(_syncHostPageTheme);
  }

  /// The Wi-Fi only toggle lives in [AppSettings] like every preference;
  /// the queue needs to hear about it, including the stored value at start.
  void _syncDownloads() =>
      widget.downloads?.setWifiOnly(_settings.downloadsWifiOnly);

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
      child: _withAmbience(MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        // Both themes are supplied so the framework can cross-fade between
        // them; `themeMode` is what the settings panel actually drives. The
        // two `ThemeData` blocks of raw hex that used to live here are gone
        // — every value now comes from `lib/theme/`, built from
        // `design/tokens.css`.
        theme: AppTheme.light(
            accent: _settings.accent,
            background: _settings.background,
            shadows: _settings.shadows),
        darkTheme: AppTheme.dark(
            accent: _settings.accent,
            background: _settings.background,
            shadows: _settings.shadows),
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
      )),
    );
  }

  Widget _withAmbience(Widget app) {
    final ambience = widget.ambience;
    final downloads = widget.downloads;
    final sync = widget.sync;
    final withSync =
        sync == null ? app : SyncScope(controller: sync, child: app);
    final withDownloads = downloads == null
        ? withSync
        : DownloadsScope(manager: downloads, child: withSync);
    return ambience == null
        ? withDownloads
        : AmbienceScope(service: ambience, child: withDownloads);
  }
}

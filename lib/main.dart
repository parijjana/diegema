import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/demo_deeplink.dart';
import 'core/error_handling.dart';
import 'core/demo_mode.dart';
import 'core/host_page_demo_notice.dart';
import 'core/ui_preferences.dart';
import 'database/app_database.dart';
import 'screens/app_shell.dart';
import 'screens/library_screen.dart' show LibraryScanner;
import 'services/app_paths.dart';
import 'services/downloads_location.dart';
import 'services/artwork_enrichment_service.dart';
import 'services/demo_artwork_service.dart';
import 'services/demo_downloader.dart';
import 'services/demo_librivox_service.dart';
import 'services/ambience_service.dart';
import 'services/audio_playback_service.dart';
import 'services/diegema_audio_handler.dart';
import 'services/folder_access.dart';
import 'services/demo_seed.dart';
import 'services/librivox_downloader.dart';
import 'services/librivox_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  if (!kIsWeb && await AppDatabase.isLibraryFromNewerVersion()) {
    runApp(const NewerLibraryApp());
    return;
  }
  // The "this is a preview" notice now lives in the host HTML page
  // (`web/index.html`), outside the Flutter app entirely — see Task 1 of
  // the UI redesign and `core/host_page_demo_notice.dart`. It ships
  // hidden in the DOM on every web build and is only ever revealed here,
  // so a non-demo build never shows it.
  if (kDemoMode) {
    revealHostPageDemoNotice();
  }
  // Demo builds only; `DemoDeepLink.fromUri` hands back an empty link in
  // every other build, whatever the URL says.
  final deepLink = DemoDeepLink.fromUri(Uri.base);

  // DEMO_MODE only (Tasks 4 & 5): seed the two playable demo titles into
  // the library as though the user already owns them, one of them with
  // ~30% saved progress, before the first frame renders — so Library and
  // Now Playing open already populated instead of racing their own
  // `initState` loads against this seed. Built here (rather than letting
  // `AudiobookApp` create its own database) specifically so `main` can
  // `await` the seed before `runApp`; every other build keeps passing
  // `database: null` and gets exactly the startup path it always had.
  AppDatabase? demoDb;
  if (kDemoMode) {
    demoDb = AppDatabase();
    await seedDemoLibrary(demoDb);
  }

  // Background playback (`audio_service`) needs one long-lived
  // `AudioPlaybackService` that exists *before* `runApp` — the plugin's own
  // requirement, so the lock screen/notification are wired up before the
  // first frame rather than only once `AppShell` happens to build. That
  // means the database it saves progress against has to exist this early
  // too, so it is created here rather than left to `AudiobookApp`'s own
  // `widget.database ?? AppDatabase()` fallback (which still runs, and is
  // still what web — `audio_service` has no web support worth wiring up
  // here — and every widget test continue to use).
  //
  // `AppShell.audioService`/`AudiobookApp.audioService` already exist as
  // injection seams (tests use them to supply `FakePlaybackService`), so
  // handing this instance down through them rather than letting `AppShell`
  // construct its own is a wiring change only, not a new seam.
  AppDatabase? nativeDb;
  AudioPlaybackService? audioService;
  AmbienceService? ambience;
  if (!kIsWeb) {
    // Before anything scans or plays from a library folder: on macOS/iOS
    // the sandbox forgets picked folders between launches.
    await openLibraryLocations();
    await openDownloadsFolder();
    nativeDb = demoDb ?? AppDatabase();
    // Before playback restores the last book: iOS moves the app's folder
    // on every update, and the database stores absolute paths into it.
    await rebaseAppPathsIfMoved(nativeDb);
    // Same reason: downloads made before the user-visible folder existed
    // move there once, and their stored paths with them.
    await moveDownloadsToVisibleFolder(nativeDb);
    audioService =
        AudioPlaybackService(db: nativeDb, preferences: const UiPreferences());
    ambience = AmbienceService(book: audioService);
    try {
      await initDiegemaAudioService(audioService, ambience: ambience);
    } catch (e) {
      // A platform `audio_service` cannot set up on (or a misconfigured
      // manifest) must not block the app from starting — playback itself
      // still works through `audioService` directly, just without the
      // lock-screen/notification surface.
      debugPrint('main: audio_service init failed: $e');
    }
  }

  runApp(AudiobookApp(
    database: demoDb ?? nativeDb,
    runCoverBackfill: nativeDb != null,
    runImportMigration: nativeDb != null,
    audioService: audioService,
    ambience: ambience,
    deepLink: deepLink,
    // `?theme=` overrides the stored choice when present, and only then —
    // absent a deep link this stays null so the persisted preference (or
    // ThemeMode.system for a fresh install) wins. The demo relies on the
    // override; a normal build never sees one.
    initialThemeMode: switch (deepLink.dark) {
      true => ThemeMode.dark,
      false => ThemeMode.light,
      null => null,
    },
    // Wire the canned web demo's stub, network-free catalog services when
    // built with --dart-define=DEMO_MODE=true; every other build keeps
    // using the real LibriVox/archive.org-backed services (the null
    // defaults below). See core/demo_mode.dart.
    libriVoxService: kDemoMode ? DemoLibriVoxService() : null,
    downloader: kDemoMode ? DemoDownloader() : null,
    artworkService: kDemoMode ? DemoArtworkService() : null,
  ));
}

/// Thin adapter kept so `AudiobookApp` (and the widget tests that drive it)
/// have one stable entry point while the shell underneath is the redesigned
/// [AppShell]. All the storefront state that used to live here — search
/// expansion, the active tab, category results, the selected book — moved
/// into the individual screens that own it.
class HomeScreen extends StatelessWidget {
  final AppDatabase db;

  /// Optional injected services, used by tests to avoid live HTTP calls and
  /// by the canned web demo to serve its bundled catalog instead. Default
  /// to the real network-backed services when omitted.
  final LibriVoxService? libriVoxService;
  final LibriVoxStreamAndDownloader? downloader;
  final ArtworkEnrichmentService? artworkService;

  /// Injectable so tests can supply a fake instead of the real
  /// `just_audio`-backed service. See `AppShell.audioService`.
  final AudioPlaybackService? audioService;

  /// Injectable so widget tests need no `shared_preferences` channel.
  final UiPreferences preferences;

  /// Injectable downloads-folder scan; see [LibraryScanner].
  final LibraryScanner? libraryScanner;

  /// Demo-only query-string entry point; see [DemoDeepLink].
  final DemoDeepLink deepLink;

  const HomeScreen({
    super.key,
    required this.db,
    this.libriVoxService,
    this.downloader,
    this.artworkService,
    this.audioService,
    this.preferences = const UiPreferences(),
    this.libraryScanner,
    this.deepLink = DemoDeepLink.none,
  });

  @override
  Widget build(BuildContext context) {
    return AppShell(
      db: db,
      libriVoxService: libriVoxService,
      downloader: downloader,
      artworkService: artworkService,
      audioService: audioService,
      preferences: preferences,
      libraryScanner: libraryScanner,
      deepLink: deepLink,
    );
  }
}

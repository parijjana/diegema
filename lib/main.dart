import 'package:flutter/material.dart';

import 'app.dart';
import 'core/demo_deeplink.dart';
import 'core/demo_mode.dart';
import 'core/host_page_demo_notice.dart';
import 'core/ui_preferences.dart';
import 'database/app_database.dart';
import 'screens/app_shell.dart';
import 'screens/library_screen.dart' show LibraryScanner;
import 'services/artwork_enrichment_service.dart';
import 'services/demo_artwork_service.dart';
import 'services/demo_downloader.dart';
import 'services/demo_librivox_service.dart';
import 'services/audio_playback_service.dart';
import 'services/demo_seed.dart';
import 'services/librivox_downloader.dart';
import 'services/librivox_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(AudiobookApp(
    database: demoDb,
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
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

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
    required this.isDarkMode,
    required this.onToggleTheme,
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
      isDarkMode: isDarkMode,
      onToggleTheme: onToggleTheme,
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

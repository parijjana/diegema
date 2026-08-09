import 'package:flutter/material.dart';
import 'core/demo_deeplink.dart';
import 'core/ui_preferences.dart';
import 'database/app_database.dart';
import 'main.dart';
import 'screens/library_screen.dart' show LibraryScanner;
import 'services/artwork_enrichment_service.dart';
import 'services/librivox_downloader.dart';
import 'services/librivox_service.dart';
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

  /// Injectable UI preference store, so widget tests never need the
  /// `shared_preferences` platform channel.
  final UiPreferences preferences;

  /// Injectable downloads-folder scan; see [LibraryScanner]. Tests pass a
  /// stub so no `path_provider` channel is touched.
  final LibraryScanner? libraryScanner;

  /// Which theme the app starts in. Only tests and the demo deep link set
  /// this; the in-app toggle drives it at runtime.
  final bool initialDarkMode;

  /// Demo-only query-string entry point; see [DemoDeepLink]. Ignored
  /// entirely outside `--dart-define=DEMO_MODE=true` builds.
  final DemoDeepLink deepLink;

  const AudiobookApp({
    super.key,
    this.initialDarkMode = false,
    this.database,
    this.libriVoxService,
    this.downloader,
    this.artworkService,
    this.preferences = const UiPreferences(),
    this.libraryScanner,
    this.deepLink = DemoDeepLink.none,
  });

  @override
  State<AudiobookApp> createState() => _AudiobookAppState();
}

class _AudiobookAppState extends State<AudiobookApp> {
  late final AppDatabase _db;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _db = widget.database ?? AppDatabase();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibriVox Audiobook Player',
      debugShowCheckedModeBanner: false,
      // Both themes are supplied so the framework can cross-fade between
      // them; `themeMode` is what the in-app toggle actually drives. The
      // two `ThemeData` blocks of raw hex that used to live here are gone —
      // every value now comes from `lib/theme/`, built from
      // `design/tokens.css`.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        db: _db,
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
        preferences: widget.preferences,
        libraryScanner: widget.libraryScanner,
        deepLink: widget.deepLink,
        libriVoxService: widget.libriVoxService,
        downloader: widget.downloader,
        artworkService: widget.artworkService,
      ),
    );
  }
}

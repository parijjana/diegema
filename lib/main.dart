import 'package:flutter/material.dart';

import 'app.dart';
import 'core/demo_mode.dart';
import 'core/ui_preferences.dart';
import 'database/app_database.dart';
import 'screens/app_shell.dart';
import 'services/artwork_enrichment_service.dart';
import 'services/demo_artwork_service.dart';
import 'services/demo_downloader.dart';
import 'services/demo_librivox_service.dart';
import 'services/librivox_downloader.dart';
import 'services/librivox_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AudiobookApp(
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

  /// Injectable so widget tests need no `shared_preferences` channel.
  final UiPreferences preferences;

  const HomeScreen({
    super.key,
    required this.db,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.libriVoxService,
    this.downloader,
    this.artworkService,
    this.preferences = const UiPreferences(),
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
      preferences: preferences,
    );
  }
}

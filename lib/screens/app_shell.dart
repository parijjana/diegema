import 'package:flutter/material.dart';

import '../core/demo_deeplink.dart';
import '../core/demo_mode.dart';
import '../core/ui_preferences.dart';
import '../database/app_database.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/audio_playback_service.dart';
import '../services/librivox_downloader.dart';
import '../services/demo_catalog.dart';
import '../services/librivox_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player_bar.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'settings_screen.dart';

/// The navigation shell, replacing the old header-tab shell
/// (`app_header.dart` + `storefront_navigation.dart`).
///
/// - **Now Playing** is index 0 and the landing screen.
/// - **Library** is books the user owns.
/// - **Discover** is the LibriVox storefront.
/// - **Settings** is index 3, appended last so the demo deep link's
///   `?screen=` indices keep their existing meanings.
///
/// **Navigation sits at the bottom at every width**, and so does the mini
/// player directly above it. Two earlier arrangements are gone: the side
/// `NavigationRail` (rejected 08-12 for reading like a web console) and the
/// wide-only top tab bar that replaced it (removed 08-14).
///
/// The top tab bar was the more defensible of the two and it still lost, so
/// the reasoning is worth keeping. It was chosen because a top tab bar is
/// the native desktop pattern, and it meant crossing [Dim.wideBreakpoint]
/// moved **two things at once** — the nav jumped top-to-bottom, and the mini
/// player's position in the stack changed with it. Simultaneous motion in
/// two elements is what read as "the app changed shape", which the owner
/// called jarring on 08-14.
///
/// The cost is accepted knowingly: a bottom bar on a 1440px desktop window
/// is not the native macOS idiom. iOS is this project's lead platform and
/// macOS is the port, so the phone idiom wins, and what is bought is that
/// **the mini player never moves** — one position, every screen size.
///
/// Individual screens still adapt at [Dim.wideBreakpoint] for their own
/// content (gutters, detail panes); it is only the shell chrome that no
/// longer does.
///
/// The shell is deliberately thin. There is no persistent app header, no
/// tagline, no collapsing search animation and no category sub-bar at this
/// level — all of that was chrome competing with the content, and the
/// verdict on the previous UI was "too high context".
class AppShell extends StatefulWidget {
  final AppDatabase db;

  final LibriVoxService? libriVoxService;
  final LibriVoxStreamAndDownloader? downloader;
  final ArtworkEnrichmentService? artworkService;

  /// Injectable so tests can supply a fake instead of the real
  /// `just_audio`-backed service. Now Playing's Task 3 restore feature
  /// (`_maybeRestoreLastPlayed`) means any test that mounts this shell with
  /// a seeded `PlaybackProgress` row calls `loadBook` on the very first
  /// frame, unprompted — the real service's `AudioPlayer` reaches for its
  /// platform channel the moment that happens, which throws
  /// `MissingPluginException` under `flutter_test` (see
  /// `test/support/fake_playback_service.dart`).
  final AudioPlaybackService? audioService;

  /// Injectable so tests can supply in-memory preferences instead of the
  /// `shared_preferences` platform channel.
  final UiPreferences preferences;

  /// Injectable downloads-folder scan for [LibraryScreen]; see
  /// [LibraryScanner].
  final LibraryScanner? libraryScanner;

  /// Demo-only query-string entry point; see [DemoDeepLink]. It chooses
  /// the landing screen and can put the app straight into its playing
  /// state, which is otherwise unreachable without a tap — and a tap is
  /// not something browser automation can perform on a canvas.
  final DemoDeepLink deepLink;

  const AppShell({
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LibriVoxService _libriVoxService;
  late final ArtworkEnrichmentService _artworkService;
  late final LibriVoxStreamAndDownloader _downloader;
  late final AudioPlaybackService _audioService;

  /// Whether this shell created [_audioService] itself, as opposed to
  /// receiving one via [AppShell.audioService]. Only the shell disposes an
  /// instance it owns — an injected one is the caller's responsibility
  /// (e.g. a test's own `tearDown`), and disposing it twice is a bug
  /// waiting to happen.
  bool get _ownsAudioService => widget.audioService == null;

  /// Index 0 — Now Playing — is the default landing screen.
  late int _index = widget.deepLink.screen;

  @override
  void initState() {
    super.initState();
    _libriVoxService = widget.libriVoxService ?? LibriVoxService();
    _artworkService = widget.artworkService ?? ArtworkEnrichmentService();
    _downloader = widget.downloader ?? LibriVoxStreamAndDownloader();
    _audioService = widget.audioService ?? AudioPlaybackService(db: widget.db);
    if (kDemoMode && widget.deepLink.play != null) {
      _startDeepLinkedPlayback(widget.deepLink.play!);
    }
  }

  /// Loads the deep-linked demo book through the same path the book view
  /// uses, so the resulting UI is the real playing state rather than a
  /// mock-up of one. Failures are swallowed: a bad `?play=` value must
  /// leave the app on its normal landing screen, not break it.
  Future<void> _startDeepLinkedPlayback(String idOrFlag) async {
    try {
      final catalog = await DemoCatalog.load();
      final playable = catalog.where((e) => e.playable);
      if (playable.isEmpty) return;
      final entry = playable.firstWhere(
        (e) => e.id == idOrFlag,
        orElse: () => playable.first,
      );
      final book = await _downloader.parseStreamableBook(entry.toLibriVoxBook());
      if (!mounted) return;
      await _audioService.loadBook(book);
    } catch (e) {
      debugPrint('AppShell: demo deep-link playback failed: $e');
    }
  }

  @override
  void dispose() {
    if (_ownsAudioService) {
      _audioService.dispose();
    }
    super.dispose();
  }

  void _go(int index) => setState(() => _index = index);

  /// Order is load-bearing: the demo deep link addresses screens by index
  /// (`?screen=`), so Settings is appended rather than slotted in — 0/1/2
  /// keep meaning what every existing demo URL says they mean.
  static const List<_Destination> _destinations = [
    _Destination('Now playing', Icons.headphones_outlined, Icons.headphones_rounded),
    _Destination('Library', Icons.book_outlined, Icons.book_rounded),
    _Destination('Discover', Icons.explore_outlined, Icons.explore_rounded),
    _Destination('Settings', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _screenFor(_index)),
            // The mini player never appears on Now Playing: that screen
            // *is* the player, and a second copy of the same controls
            // is exactly the redundancy this redesign removes.
            if (_index != 0)
              MiniPlayerBar(
                audioService: _audioService,
                onOpenPlayer: () => _go(0),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        destinations: _destinations,
        onSelect: _go,
      ),
    );
  }

  Widget _screenFor(int index) {
    // No theme toggle anywhere in here any more. It used to sit in each
    // screen's heading and in the top tab bar — the same control up to
    // three times over — and then, after that dedup, on Now Playing only,
    // explicitly as an interim placement. Settings is the final home, so
    // the interim is gone.
    switch (index) {
      case 1:
        return LibraryScreen(
          db: widget.db,
          audioService: _audioService,
          onGoToDiscover: () => _go(2),
          scanLibrary: widget.libraryScanner,
        );
      case 2:
        return DiscoverScreen(
          db: widget.db,
          openBookId: kDemoMode ? widget.deepLink.book : null,
          audioService: _audioService,
          libriVoxService: _libriVoxService,
          artworkService: _artworkService,
          downloader: _downloader,
        );
      case 3:
        return const SettingsScreen();
      default:
        return NowPlayingScreen(
          db: widget.db,
          audioService: _audioService,
          preferences: widget.preferences,
          onGoToDiscover: () => _go(2),
        );
    }
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}

class _BottomNav extends StatelessWidget {
  final int index;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  const _BottomNav({
    required this.index,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
              tooltip: d.label,
            ),
        ],
      ),
    );
  }
}

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

/// The three-screen navigation shell, replacing the old header-tab shell
/// (`app_header.dart` + `storefront_navigation.dart`).
///
/// - **Now Playing** is index 0 and the landing screen.
/// - **Library** is books the user owns.
/// - **Discover** is the LibriVox storefront.
///
/// Layout is chosen from the shell's own [BoxConstraints], not
/// `MediaQuery.size`: a `NavigationBar` at the bottom below
/// [Dim.wideBreakpoint], a `NavigationRail` at the side above it. The old
/// header was a single unwrapped `Row` that could not fit 390px at all.
///
/// The shell is deliberately thin. There is no persistent app header, no
/// tagline, no collapsing search animation and no category sub-bar at this
/// level — all of that was chrome competing with the content, and the
/// verdict on the previous UI was "too high context".
class AppShell extends StatefulWidget {
  final AppDatabase db;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

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

  static const List<_Destination> _destinations = [
    _Destination('Now playing', Icons.headphones_outlined, Icons.headphones_rounded),
    _Destination('Library', Icons.book_outlined, Icons.book_rounded),
    _Destination('Discover', Icons.explore_outlined, Icons.explore_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= Dim.wideBreakpoint;

            final Widget content = Column(
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
            );

            if (!wide) {
              return content;
            }

            // Wide layouts get a top tab bar, not a side rail: a vertical
            // strip of nav pills down the left edge reads like a web
            // console/dashboard, which was the owner's exact complaint
            // after seeing the desktop-width demo. A top tab bar is the
            // native-app pattern at this width (browser chrome, mail
            // clients, most macOS/iOS apps with more than a couple of top-
            // level sections).
            //
            // Phone width deliberately keeps the bottom `NavigationBar`
            // (see `_BottomNav` / `bottomNavigationBar` below) rather than
            // moving it to the top too: a bottom tab bar *is* the native
            // pattern on both iOS and Android at phone width, and moving it
            // would make the phone layout read less like an app, not more.
            return Column(
              children: [
                _TopTabBar(
                  index: _index,
                  destinations: _destinations,
                  onSelect: _go,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
                Divider(height: 1, color: c.border),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Dim.wideBreakpoint) {
            return const SizedBox.shrink();
          }
          return _BottomNav(
            index: _index,
            destinations: _destinations,
            onSelect: _go,
          );
        },
      ),
    );
  }

  Widget _screenFor(int index) {
    // The theme toggle lives on Now Playing ONLY, at every width. It used
    // to sit in each screen's heading and in the top tab bar, so the same
    // control appeared up to three times over.
    //
    // Interim placement, not the final home: this becomes a row in the
    // settings panel once that exists. Now Playing is the landing screen,
    // so the control stays reachable in one tap until then.
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
      default:
        return NowPlayingScreen(
          db: widget.db,
          audioService: _audioService,
          preferences: widget.preferences,
          onGoToDiscover: () => _go(2),
          headerAction: ThemeToggleButton(
            isDarkMode: widget.isDarkMode,
            onToggle: widget.onToggleTheme,
          ),
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

/// Wide-layout navigation: a top tab bar, replacing the old `NavigationRail`
/// (see the class doc comment on the call site in `AppShell.build`).
class _TopTabBar extends StatelessWidget {
  final int index;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const _TopTabBar({
    required this.index,
    required this.destinations,
    required this.onSelect,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      child: Padding(
        key: const ValueKey('top-tab-bar'),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x5, vertical: Sp.x2),
        child: Row(
          children: [
            // No wordmark here. This app is not LibriVox's and should not
            // wear their name as branding; the recordings' provenance
            // belongs in an About surface as attribution, not in the chrome.
            for (var i = 0; i < destinations.length; i++) ...[
              if (i != 0) const SizedBox(width: Sp.x2),
              _TopTabItem(
                destination: destinations[i],
                selected: index == i,
                onTap: () => onSelect(i),
              ),
            ],
            const Spacer(),
            ThemeToggleButton(isDarkMode: isDarkMode, onToggle: onToggleTheme),
          ],
        ),
      ),
    );
  }
}

/// One top tab. Selected state is carried by a filled pill background
/// *and* a bolder label weight *and* the icon swapping to its filled
/// variant — never colour alone (`design/tokens.md` §8, rule 4).
class _TopTabItem extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _TopTabItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.sm,
        child: Container(
          constraints: const BoxConstraints(minHeight: Dim.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          decoration: BoxDecoration(
            color: selected ? c.accentFill : Colors.transparent,
            borderRadius: R.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: Dim.iconMd,
                color: selected ? c.textOnAccent : c.text,
              ),
              const SizedBox(width: Sp.x2),
              Text(
                destination.label,
                style: AppType.label.copyWith(
                  color: selected ? c.textOnAccent : c.text,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled dark-mode toggle carrying `Semantics(toggled:)`. Replaces the
/// custom 56×28 sliding switch in the old header, which had no accessible
/// name and no label at all.
class ThemeToggleButton extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggle;

  const ThemeToggleButton({
    super.key,
    required this.isDarkMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final label = isDarkMode ? 'Dark theme' : 'Light theme';
    return Semantics(
      button: true,
      toggled: isDarkMode,
      label: '$label. Activate to switch.',
      excludeSemantics: true,
      child: IconButton(
        tooltip: isDarkMode ? 'Switch to light theme' : 'Switch to dark theme',
        onPressed: onToggle,
        icon: Icon(isDarkMode
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded),
      ),
    );
  }
}

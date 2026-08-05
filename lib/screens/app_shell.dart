import 'package:flutter/material.dart';

import '../core/demo_mode.dart';
import '../core/ui_preferences.dart';
import '../database/app_database.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/audio_playback_service.dart';
import '../services/librivox_downloader.dart';
import '../services/librivox_service.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_notice.dart';
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

  /// Injectable so tests can supply in-memory preferences instead of the
  /// `shared_preferences` platform channel.
  final UiPreferences preferences;

  const AppShell({
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LibriVoxService _libriVoxService;
  late final ArtworkEnrichmentService _artworkService;
  late final LibriVoxStreamAndDownloader _downloader;
  late final AudioPlaybackService _audioService;

  /// Index 0 — Now Playing — is the default landing screen.
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _libriVoxService = widget.libriVoxService ?? LibriVoxService();
    _artworkService = widget.artworkService ?? ArtworkEnrichmentService();
    _downloader = widget.downloader ?? LibriVoxStreamAndDownloader();
    _audioService = AudioPlaybackService(db: widget.db);
  }

  @override
  void dispose() {
    _audioService.dispose();
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
                if (kDemoMode)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, 0),
                    child: DemoNotice(),
                  ),
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

            return Row(
              children: [
                _SideNav(
                  index: _index,
                  destinations: _destinations,
                  onSelect: _go,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
                VerticalDivider(width: 1, color: c.border),
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
    // On narrow layouts there is no side rail, so each screen's heading
    // carries the theme toggle instead. Nothing is hover-only and nothing
    // is reachable from only one screen.
    final headerAction = ThemeToggleButton(
      isDarkMode: widget.isDarkMode,
      onToggle: widget.onToggleTheme,
    );
    switch (index) {
      case 1:
        return LibraryScreen(
          db: widget.db,
          audioService: _audioService,
          onGoToDiscover: () => _go(2),
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        );
      case 2:
        return DiscoverScreen(
          db: widget.db,
          audioService: _audioService,
          libriVoxService: _libriVoxService,
          artworkService: _artworkService,
          downloader: _downloader,
          headerAction: headerAction,
        );
      default:
        return NowPlayingScreen(
          db: widget.db,
          audioService: _audioService,
          preferences: widget.preferences,
          onGoToDiscover: () => _go(2),
          headerAction: headerAction,
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

class _SideNav extends StatelessWidget {
  final int index;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const _SideNav({
    required this.index,
    required this.destinations,
    required this.onSelect,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      minWidth: 88,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.x5, horizontal: Sp.x2),
        child: Semantics(
          header: true,
          child: Text(
            'LibriVox',
            textAlign: TextAlign.center,
            // Serif wordmark: a public-domain library, not a console.
            style: AppType.serif(AppType.titleSm).copyWith(color: c.accentText),
          ),
        ),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Sp.x5),
            child: ThemeToggleButton(
              isDarkMode: isDarkMode,
              onToggle: onToggleTheme,
            ),
          ),
        ),
      ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
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

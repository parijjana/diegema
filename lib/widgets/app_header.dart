import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import 'now_playing_screen.dart';

class AppHeader extends StatelessWidget {
  final int activeNavTab;
  final ValueChanged<int> onSelectTab;
  final bool isSearchExpanded;
  final VoidCallback onToggleSearch;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchSubmitted;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AudioPlaybackService audioService;
  final AppDatabase db;
  final VoidCallback onOpenDrawer;

  const AppHeader({
    super.key,
    required this.activeNavTab,
    required this.onSelectTab,
    required this.isSearchExpanded,
    required this.onToggleSearch,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.audioService,
    required this.db,
    required this.onOpenDrawer,
  });

  Widget _buildNavPill(
      String label, int index, bool isActive, ThemeData theme) {
    return InkWell(
      onTap: () => onSelectTab(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? null
              : Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: isActive
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingToggleSwitch(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final isDark = isDarkMode;

    return Tooltip(
      message: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
      child: InkWell(
        onTap: onToggleTheme,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E262B) : const Color(0xFFE8E6DF),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: primary.withValues(alpha: 0.5), width: 1.2),
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Icon(Icons.wb_sunny_rounded,
                        size: 12, color: primary.withValues(alpha: 0.5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.nightlight_round,
                        size: 12, color: primary.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment:
                    isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSearch(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isSearchExpanded ? 200 : 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSearchExpanded
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onToggleSearch,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                size: 18,
                color: isSearchExpanded
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (isSearchExpanded)
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                style:
                    TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search audiobooks...',
                  hintStyle: TextStyle(
                      fontSize: 11,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(right: 12),
                ),
                onSubmitted: onSearchSubmitted,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.headphones_rounded,
                    color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AULOS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'public domain audiobook player',
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          _buildNavPill('LIBRARY', 0, activeNavTab == 0, theme),
          const SizedBox(width: 8),
          _buildNavPill('DISCOVER', 1, activeNavTab == 1, theme),
          ValueListenableBuilder<UnifiedAudiobook?>(
            valueListenable: audioService.currentBookNotifier,
            builder: (context, playingBook, child) {
              if (playingBook == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.6)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.graphic_eq_rounded,
                      color: theme.colorScheme.primary, size: 16),
                  label: Text(
                    'NOW PLAYING',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.0),
                  ),
                  onPressed: () => AulosNowPlayingScreen.openFullPage(context,
                      audioService: audioService, db: db),
                ),
              );
            },
          ),
          const Spacer(),
          _buildExpandableSearch(theme),
          const SizedBox(width: 12),
          ValueListenableBuilder<UnifiedAudiobook?>(
            valueListenable: audioService.currentBookNotifier,
            builder: (context, book, child) {
              if (book == null) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.bookmark_outline_rounded,
                    color: theme.colorScheme.primary, size: 20),
                tooltip: 'Bookmarks',
                onPressed: onOpenDrawer,
              );
            },
          ),
          const SizedBox(width: 12),
          _buildSlidingToggleSwitch(theme),
        ],
      ),
    );
  }
}

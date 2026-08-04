import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../domain/models/librivox_book.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/audio_playback_service.dart';
import '../services/librivox_downloader.dart';
import 'auto_resume_banner.dart';
import 'book_detail_pane.dart';
import 'glass_card.dart';
import 'library_view.dart';
import 'storefront_shelves.dart';

class CategorySubBar extends StatelessWidget {
  final List<Map<String, String>> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSelectCategory;

  const CategorySubBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat['name'];
          return ChoiceChip(
            label: Text(cat['name']!, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
            labelStyle: TextStyle(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
            onSelected: (_) => onSelectCategory(cat['name']!),
          );
        },
      ),
    );
  }
}

class StorefrontBodyLayout extends StatelessWidget {
  final int activeNavTab;
  final bool isSearching;
  final bool isLoading;
  final List<LibriVoxBook> searchResults;
  final Map<String, List<LibriVoxBook>> categoryResults;
  final List<Map<String, String>> categories;
  final LibriVoxBook? selectedBook;
  final ValueChanged<LibriVoxBook> onSelectBook;
  final AppDatabase db;
  final AudioPlaybackService audioService;
  final ArtworkEnrichmentService artworkService;
  final LibriVoxStreamAndDownloader downloader;
  final VoidCallback onGoToDiscover;

  const StorefrontBodyLayout({
    super.key,
    required this.activeNavTab,
    required this.isSearching,
    required this.isLoading,
    required this.searchResults,
    required this.categoryResults,
    required this.categories,
    required this.selectedBook,
    required this.onSelectBook,
    required this.db,
    required this.audioService,
    required this.artworkService,
    required this.downloader,
    required this.onGoToDiscover,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    Widget buildDiscoverContent() {
      return Column(
        children: [
          AutoResumeBanner(db: db, audioService: audioService),
          Expanded(
            child: isSearching
                ? SearchResultsGrid(
                    isLoading: isLoading,
                    searchResults: searchResults,
                    selectedBook: selectedBook,
                    onSelectBook: onSelectBook,
                  )
                : StorefrontShelves(
                    isLoading: isLoading,
                    categoryResults: categoryResults,
                    categories: categories,
                    selectedBook: selectedBook,
                    onSelectBook: onSelectBook,
                  ),
          ),
        ],
      );
    }

    if (!isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: GlassCard(
          fullHeight: true,
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(12),
          child: activeNavTab == 0
              ? Column(
                  children: [
                    AutoResumeBanner(db: db, audioService: audioService),
                    Expanded(child: LibraryView(db: db, audioService: audioService, onGoToDiscover: onGoToDiscover)),
                  ],
                )
              : buildDiscoverContent(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: GlassCard(
              fullHeight: true,
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(12),
              child: activeNavTab == 0
                  ? Column(
                      children: [
                        AutoResumeBanner(db: db, audioService: audioService),
                        Expanded(child: LibraryView(db: db, audioService: audioService, onGoToDiscover: onGoToDiscover)),
                      ],
                    )
                  : buildDiscoverContent(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: GlassCard(
              fullHeight: true,
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(12),
              child: selectedBook != null
                  ? BookDetailPane(
                      book: selectedBook!,
                      artworkService: artworkService,
                      downloader: downloader,
                      audioService: audioService,
                      db: db,
                    )
                  : const Center(
                      child: Text('Select an audiobook to view details', style: TextStyle(color: Colors.grey)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

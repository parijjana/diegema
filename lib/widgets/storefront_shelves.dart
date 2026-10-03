import 'package:flutter/material.dart';
import '../domain/models/librivox_book.dart';
import 'librivox_book_item.dart';
import 'librivox_shelf_view.dart';

class StorefrontShelves extends StatelessWidget {
  final bool isLoading;
  final Map<String, List<LibriVoxBook>> categoryResults;
  final List<Map<String, String>> categories;
  final LibriVoxBook? selectedBook;
  final ValueChanged<LibriVoxBook> onSelectBook;

  const StorefrontShelves({
    super.key,
    required this.isLoading,
    required this.categoryResults,
    required this.categories,
    required this.selectedBook,
    required this.onSelectBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading && categoryResults.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        LibriVoxShelfView(
          title: 'Featured Classics',
          books: categoryResults[''] ?? [],
          selectedBook: selectedBook,
          onSelectBook: onSelectBook,
        ),
        ...categories.skip(1).map((cat) {
          final query = cat['query']!;
          final books = categoryResults[query] ?? [];
          return LibriVoxShelfView(
            title: 'Top ${cat['name']} Books',
            books: books,
            selectedBook: selectedBook,
            onSelectBook: onSelectBook,
          );
        }),
      ],
    );
  }
}

class SearchResultsGrid extends StatelessWidget {
  final bool isLoading;
  final List<LibriVoxBook> searchResults;
  final LibriVoxBook? selectedBook;
  final ValueChanged<LibriVoxBook> onSelectBook;

  const SearchResultsGrid({
    super.key,
    required this.isLoading,
    required this.searchResults,
    required this.selectedBook,
    required this.onSelectBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    if (searchResults.isEmpty) {
      return const Center(child: Text('No audiobooks found for this search.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'SEARCH RESULTS (${searchResults.length})'.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              childAspectRatio: 0.54,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final book = searchResults[index];
              return LibriVoxBookItem(
                book: book,
                isSelected: selectedBook?.id == book.id,
                onTap: () => onSelectBook(book),
              );
            },
          ),
        ),
      ],
    );
  }
}

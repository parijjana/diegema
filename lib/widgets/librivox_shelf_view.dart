import 'package:flutter/material.dart';

import '../domain/models/librivox_book.dart';
import '../theme/app_theme.dart';
import 'librivox_book_item.dart';

/// One horizontal shelf of books on Discover.
///
/// The heading was `title.toUpperCase()` at 10px with `letterSpacing: 1.5`
/// and an alpha-composited accent; it is now sentence case at `title-sm` in
/// an opaque `text` colour. The shelf height is derived from the tile
/// metrics and the current text scale rather than a fixed 240px that
/// clipped at large text sizes.
class LibriVoxShelfView extends StatelessWidget {
  final List<LibriVoxBook> books;
  final String title;
  final LibriVoxBook? selectedBook;
  final void Function(LibriVoxBook book) onSelectBook;

  const LibriVoxShelfView({
    super.key,
    required this.title,
    required this.books,
    this.selectedBook,
    required this.onSelectBook,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (books.isEmpty) return const SizedBox.shrink();

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final shelfHeight =
        LibriVoxBookItem.coverHeight + Sp.x2 + (26 * 2 + 18) * textScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          child: Semantics(
            header: true,
            child: Text(title, style: AppType.titleSm.copyWith(color: c.text)),
          ),
        ),
        const SizedBox(height: Sp.x3),
        SizedBox(
          height: shelfHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: Sp.x3),
            itemBuilder: (context, index) {
              final book = books[index];
              return LibriVoxBookItem(
                book: book,
                isSelected: selectedBook?.id == book.id,
                onTap: () => onSelectBook(book),
              );
            },
          ),
        ),
        const SizedBox(height: Sp.sectionGap),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../core/utils/sync_format.dart';
import '../sync/sync_view.dart';
import '../theme/app_theme.dart';
import 'app_book_cover.dart';
import 'library_tiles.dart';

/// Library's "On your other devices": books another linked device has that
/// this one does not. Purely presentational; the Library screen decides
/// what a tap and a long-press do.
class RemoteBooksSection extends StatelessWidget {
  final SyncView view;
  final List<RemoteBook> books;
  final ValueChanged<RemoteBook> onTap;
  final ValueChanged<RemoteBook> onLongPress;

  /// Show the books as a grid of tiles instead of rows.
  final bool tiles;

  const RemoteBooksSection({
    super.key,
    required this.view,
    required this.books,
    required this.onTap,
    required this.onLongPress,
    this.tiles = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('On your other devices',
              style: AppType.titleSm.copyWith(color: c.text)),
        ),
        const SizedBox(height: Sp.x3),
        if (tiles)
          LibraryTileGrid(
            count: books.length,
            itemBuilder: (context, i, size) {
              final book = books[i];
              final devices = deviceListLabel(view, book.deviceIds);
              return LibraryTile(
                // Dimmed: it is not on this device yet.
                cover: Opacity(
                  opacity: 0.5,
                  child: AppBookCover(
                    bookId: book.key,
                    title: book.title,
                    width: size,
                    height: size,
                  ),
                ),
                title: book.title,
                author: book.author,
                caption: 'On $devices',
                semanticsLabel: '${book.title}'
                    '${book.author.isEmpty ? '' : ', by ${book.author}'}'
                    ', not on this device, on $devices',
                onTap: () => onTap(book),
                onLongPress: () => onLongPress(book),
              );
            },
          )
        else
          for (final book in books)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.listGap),
              child: _RemoteBookRow(
                book: book,
                devices: deviceListLabel(view, book.deviceIds),
                onTap: () => onTap(book),
                onLongPress: () => onLongPress(book),
              ),
            ),
      ],
    );
  }
}

class _RemoteBookRow extends StatelessWidget {
  final RemoteBook book;
  final String devices;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RemoteBookRow({
    required this.book,
    required this.devices,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      type: MaterialType.transparency,
      borderRadius: R.md,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: R.md,
        child: Semantics(
          button: true,
          label: '${book.title}, on $devices',
          excludeSemantics: true,
          child: Ink(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: R.md,
              border: Border.all(color: c.border),
              boxShadow: c.shadow1,
            ),
            padding: const EdgeInsets.all(Sp.x3),
            child: Row(
              children: [
                // Dimmed: it is not on this device yet.
                Opacity(
                  opacity: 0.5,
                  child: AppBookCover(
                    bookId: book.key,
                    title: book.title,
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyLg.copyWith(
                            color: c.text, fontWeight: FontWeight.w600),
                      ),
                      if (book.author.isNotEmpty) ...[
                        const SizedBox(height: Sp.x1),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(color: c.textSecondary),
                        ),
                      ],
                      const SizedBox(height: Sp.x1),
                      Text(
                        'On $devices',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.x2),
                Icon(Icons.chevron_right_rounded,
                    size: Dim.iconXl, color: c.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/utils/duration_format.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import 'app_book_cover.dart';

/// The Library-screen counterpart of Discover's `BookDetailPane`.
///
/// `BookDetailPane` is built around `LibriVoxBook` — it resolves cover art
/// over the network, offers a ZIP download, and gates chapters on
/// `demoPlayable`. None of that applies to a [UnifiedAudiobook] already
/// sitting in the local library (art is already local-or-known, there is
/// nothing left to download, nothing is demo-gated), and bending
/// `BookDetailPane` to accept either type would mean threading optional
/// fields through a widget that is not its own. So this is a small,
/// separate overlay that matches the *look* (same card, same type scale)
/// rather than a forced reuse.
class LibraryBookDetailOverlay extends StatelessWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;

  const LibraryBookDetailOverlay({
    super.key,
    required this.book,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.only(bottom: Sp.x5),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBookCover(
              bookId: book.id,
              title: book.title,
              coverUrl: book.coverArtUrlOrPath,
              width: 110,
              height: 110,
            ),
            const SizedBox(width: Sp.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppType.serif(AppType.titleMd)
                        .copyWith(color: c.text, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    book.author,
                    style: AppType.bodyLg.copyWith(color: c.accentFill),
                  ),
                  if (book.narrators.isNotEmpty) ...[
                    const SizedBox(height: Sp.x1),
                    Text(
                      'Narrated by: ${book.narrators.join(', ')}',
                      style: AppType.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.x5),
        // The explicit action tapping a row used to trigger implicitly.
        // Reachable without disturbing whatever the mini-player is already
        // doing — this is the only thing in the overlay that can start
        // playback.
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              audioService.loadBook(book);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play'),
          ),
        ),
        const SizedBox(height: Sp.x5),
        if (book.description.trim().isNotEmpty) ...[
          Text('Description', style: AppType.titleSm.copyWith(color: c.text)),
          const SizedBox(height: Sp.x2),
          Text(
            book.description,
            style: AppType.body.copyWith(color: c.textSecondary, height: 1.5),
          ),
          const SizedBox(height: Sp.x5),
        ],
        Text('Chapters (${book.chapters.length})',
            style: AppType.titleSm.copyWith(color: c.text)),
        const SizedBox(height: Sp.x2),
        for (final entry in book.chapters.asMap().entries)
          _ChapterTile(
            title: entry.value.title,
            runtime: formatRuntime(entry.value.durationSeconds),
            onTap: () {
              audioService.loadBook(book, initialChapterIndex: entry.key);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final String title;
  final String? runtime;
  final VoidCallback onTap;

  const _ChapterTile(
      {required this.title, required this.runtime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      decoration: BoxDecoration(
        borderRadius: R.sm,
        border: Border.all(color: c.border),
      ),
      // The background used to live on the outer `Container`'s
      // `BoxDecoration`, which sits between `ListTile` and the nearest
      // `Material` ancestor — `ListTile` paints its own background and
      // ink splashes on that ancestor, so the opaque `DecoratedBox` was
      // silently hiding both (Flutter asserts on this once the tile is
      // actually built, which nothing previously exercised). Moving the
      // fill onto its own `Material` gives `ListTile` a paintable surface
      // right above it and keeps the border/radius on the `Container`.
      child: Material(
        color: c.surface,
        borderRadius: R.sm,
        child: ListTile(
          dense: true,
          shape: const RoundedRectangleBorder(borderRadius: R.sm),
          leading: Icon(Icons.play_circle_fill_rounded, color: c.accentFill),
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyLg.copyWith(color: c.text)),
          subtitle: runtime == null
              ? null
              : Text(runtime!,
                  style: AppType.caption.copyWith(color: c.textMuted)),
          onTap: onTap,
        ),
      ),
    );
  }
}

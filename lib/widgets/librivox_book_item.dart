import 'package:flutter/material.dart';

import '../domain/models/librivox_book.dart';
import '../theme/app_theme.dart';
import 'app_book_cover.dart';

/// A book tile on the Discover shelves.
///
/// Redesigned onto the token system: 148px wide (was 110), title 16px (was
/// 10px bold), author 13px `text-secondary` (was 9px at `onSurface` α0.5,
/// which measured 2.94:1 and failed AA badly). Selection is a 2px accent
/// outline plus the badge, never colour alone. The neon accent strip, the
/// glossy sheen and the hue-tinted glow shadow are gone — see
/// [AppBookCover].
///
/// The **preview-only** treatment is unchanged in substance and must stay:
/// the canned web demo has to mark every entry whose audio was not bundled,
/// so nobody believes they were shown a working app that isn't one. The
/// badge text is part of the accessible label, not just a visual.
class LibriVoxBookItem extends StatelessWidget {
  final LibriVoxBook book;
  final bool isSelected;
  final VoidCallback onTap;

  static const double tileWidth = 148;
  static const double coverHeight = 196;

  const LibriVoxBookItem({
    super.key,
    required this.book,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPreviewOnly = !book.demoPlayable;

    final semanticLabel = [
      book.title,
      'by ${book.authorNames}',
      if (isPreviewOnly) 'Preview only, not playable',
      if (isSelected) 'Selected',
    ].join('. ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.md,
        child: SizedBox(
          width: tileWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Opacity(
                    // Desaturating outright needs a colour matrix; dimming
                    // reads the same at tile size and costs nothing.
                    opacity: isPreviewOnly ? 0.72 : 1.0,
                    child: AppBookCover(
                      bookId: book.id,
                      title: book.title,
                      coverUrl: book.coverArtUrl,
                      width: tileWidth,
                      height: coverHeight,
                      isSelected: isSelected,
                    ),
                  ),
                  if (isPreviewOnly)
                    Positioned(
                      left: Sp.x1,
                      right: Sp.x1,
                      bottom: Sp.x1,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Sp.x2, vertical: Sp.x1),
                          decoration: BoxDecoration(
                            color: c.warning,
                            borderRadius: R.xs,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded,
                                  size: 14, color: c.textOnAccent),
                              const SizedBox(width: Sp.x1),
                              Flexible(
                                child: Text(
                                  'Preview only',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.caption
                                      .copyWith(color: c.textOnAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Sp.x2),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.body
                    .copyWith(color: c.text, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Sp.x1),
              Text(
                book.authorNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Columns and tile width for the Library's tile view.
///
/// Tiles aim for [targetWidth] logical px (roughly 140-180), so a 360 px
/// phone gets 2 columns and a desktop window gets as many as fit. Never
/// fewer than 2: a single full-width "tile" is just a worse row.
({int columns, double tileWidth}) libraryTileMetrics(
  double availableWidth, {
  double gap = Sp.x3,
  double targetWidth = 160,
}) {
  final columns =
      (((availableWidth + gap) / (targetWidth + gap)).round()).clamp(2, 12);
  final tileWidth = (availableWidth - gap * (columns - 1)) / columns;
  return (columns: columns, tileWidth: tileWidth);
}

/// A responsive grid of [LibraryTile]s. Built as rows of equal-height tiles
/// (not a `SliverGrid`) so it can sit inside the Library's existing list of
/// section widgets; text scale changes tile height, which a fixed-extent
/// sliver grid cannot absorb without overflowing.
class LibraryTileGrid extends StatelessWidget {
  final int count;

  /// Builds tile [index]; [coverSize] is the square cover edge to use.
  final Widget Function(BuildContext context, int index, double coverSize)
      itemBuilder;

  const LibraryTileGrid({
    super.key,
    required this.count,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final m = libraryTileMetrics(constraints.maxWidth);
      final coverSize = m.tileWidth - 2 * LibraryTile.inset;
      final rows = <Widget>[];
      for (var start = 0; start < count; start += m.columns) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: Sp.x3),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < m.columns; i++) ...[
                  if (i > 0) const SizedBox(width: Sp.x3),
                  Expanded(
                    child: start + i < count
                        ? itemBuilder(context, start + i, coverSize)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    });
  }
}

/// One book as a card: cover, title (2 lines), author (1 line), and a
/// progress bar or caption. Presentational only; the caller supplies the
/// same tap and long-press callbacks its list row uses.
class LibraryTile extends StatefulWidget {
  /// Space between the card edge and the cover: 8 px padding plus the 2 px
  /// border (the border keeps its width when it becomes the focus ring).
  static const double inset = Sp.x2 + 2;

  final Widget cover;
  final String title;
  final String author;

  /// 0.0-1.0 draws the thin accent bar; null draws none.
  final double? progress;

  /// Small line under the bar (percent, chapter count, "On Desk PC").
  final String? caption;
  final bool captionAccent;

  /// Everything a screen reader hears, as one node.
  final String semanticsLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const LibraryTile({
    super.key,
    required this.cover,
    required this.title,
    required this.author,
    required this.semanticsLabel,
    required this.onTap,
    this.onLongPress,
    this.progress,
    this.caption,
    this.captionAccent = false,
  });

  @override
  State<LibraryTile> createState() => _LibraryTileState();
}

class _LibraryTileState extends State<LibraryTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      type: MaterialType.transparency,
      borderRadius: R.md,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: (f) => setState(() => _focused = f),
        borderRadius: R.md,
        child: Semantics(
          button: true,
          label: widget.semanticsLabel,
          excludeSemantics: true,
          child: Ink(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: R.md,
              // The focus ring: a 2 px outline in place of the hairline,
              // so keyboard users can see where they are. Both are drawn
              // inside a fixed 2 px inset, so focus never moves the cover.
              border: Border.all(
                color: _focused ? c.focusRing : c.border,
                width: _focused ? 2 : 1,
              ),
              boxShadow: c.shadow1,
            ),
            padding: EdgeInsets.all(_focused ? Sp.x2 : Sp.x2 + 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: widget.cover),
                const SizedBox(height: Sp.x2),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body
                      .copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
                if (widget.author.isNotEmpty)
                  Text(
                    widget.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: c.textSecondary),
                  ),
                if (widget.progress != null) ...[
                  const SizedBox(height: Sp.x2),
                  ClipRRect(
                    borderRadius: R.pill,
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 4,
                      backgroundColor: c.border,
                      valueColor: AlwaysStoppedAnimation(c.accentFill),
                    ),
                  ),
                ],
                if (widget.caption != null) ...[
                  const SizedBox(height: Sp.x1),
                  Text(
                    widget.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(
                        color:
                            widget.captionAccent ? c.accentText : c.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

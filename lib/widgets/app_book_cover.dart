import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'book_cover_image.dart';

/// A book cover at the design system's cover treatment: a uniform corner
/// radius scaled with its size ([R.coverFor]), a `shadow-cover` drop
/// shadow, and a procedural fallback carrying the serif letter emblem.
///
/// Deliberately gone from the old `librivox_book_item` cover: the neon
/// accent strip, the glossy sheen gradient, and the per-book hue bloom
/// shadow. Those were residue of the rejected neon-cyberpunk pass. The
/// spine crease and the serif emblem are kept.
///
/// Cover *source* selection is unchanged and still delegated to
/// [BookCoverImage], so the DEMO_MODE bundled-asset path keeps working
/// exactly as before (Flutter web is CanvasKit-only and hotlinked
/// archive.org images are CORS-blocked).
class AppBookCover extends StatelessWidget {
  final String bookId;
  final String title;
  final String? coverUrl;
  final double width;
  final double height;

  /// Draws the meaningful 2px accent outline used for selection. Never the
  /// only cue — callers pair it with a fill or a badge.
  final bool isSelected;

  const AppBookCover({
    super.key,
    required this.bookId,
    required this.title,
    this.coverUrl,
    required this.width,
    required this.height,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = R.coverFor(width < height ? width : height);
    final letter =
        title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';

    final Widget procedural = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceAccent,
        borderRadius: radius,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Spine crease — kept from the original cover treatment.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: width * 0.09,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.horizontal(left: radius.topLeft),
              ),
            ),
          ),
          Center(
            child: Text(
              letter,
              style: AppType.serif(AppType.display).copyWith(
                color: c.accentText,
                fontSize: width * 0.38,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Opaque under the image, so the shadow can never show through a
        // cover with transparent pixels.
        color: c.surfaceSunken,
        borderRadius: radius,
        boxShadow: c.shadowCover,
        border: Border.all(
          color: isSelected ? c.accent : c.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BookCoverImage(
          bookId: bookId,
          networkUrl: coverUrl,
          width: width,
          height: height,
          fallbackBuilder: (_) => procedural,
        ),
      ),
    );
  }
}

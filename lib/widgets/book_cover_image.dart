import 'package:flutter/material.dart';
import '../core/demo_mode.dart';

/// Renders a book cover, choosing the right source for the current build:
///
/// - **DEMO_MODE**: the bundled `assets/demo/covers/<bookId>.jpg` asset
///   (see `scripts/fetch_demo_covers.sh`). Flutter web is CanvasKit-only —
///   it fetches image bytes itself via XHR rather than using an `<img>`
///   element, which puts hotlinked images under CORS, and archive.org's
///   `/services/img` endpoint sends no `access-control-allow-origin`
///   header. Every cover silently failed to load in the deployed web demo
///   until bundling them locally sidestepped the problem.
/// - **otherwise**: [networkUrl], a live archive.org URL, exactly as the
///   real app has always done — native platforms have no CORS
///   restriction to work around, and bundling would make no sense there.
///
/// Falls back to [fallbackBuilder] if the chosen source is unavailable: a
/// missing bundled asset, a network error, or no URL at all.
class BookCoverImage extends StatelessWidget {
  final String bookId;
  final String? networkUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder fallbackBuilder;

  const BookCoverImage({
    super.key,
    required this.bookId,
    required this.fallbackBuilder,
    this.networkUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (kDemoMode) {
      return Image.asset(
        'assets/demo/covers/$bookId.jpg',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackBuilder(context),
      );
    }

    final url = networkUrl;
    if (url == null || url.isEmpty) return fallbackBuilder(context);

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallbackBuilder(context),
    );
  }
}

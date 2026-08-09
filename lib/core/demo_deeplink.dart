import 'demo_mode.dart';

/// Query-string entry points into a specific app state, honoured **only in
/// [kDemoMode] builds**.
///
/// Flutter web renders into a single `<canvas>`: there are no DOM nodes, so
/// no browser automation can click a nav destination, flip the theme or
/// start playback. Two previous attempts to capture the screenshot matrix
/// foundered on exactly that and ended up mislabelling whatever state
/// happened to be reachable. A deep link is the honest fix — the states are
/// entered through the app's own code paths, and the URL that produced a
/// screenshot is a record of what it actually shows.
///
/// Recognised parameters:
///
/// | Param | Values | Effect |
/// | :-- | :-- | :-- |
/// | `screen` | `nowplaying` \| `library` \| `discover` | Landing screen |
/// | `theme` | `dark` \| `light` | Starting theme |
/// | `play` | book id, or `1` for the first playable demo book | Loads that book, so Now Playing opens in its active state |
/// | `book` | book id, or `1` for the first | Opens the book view for it |
///
/// Nothing here is reachable in a normal build: [DemoDeepLink.fromUri]
/// returns [DemoDeepLink.none] unless [kDemoMode] is set.
class DemoDeepLink {
  /// 0 Now Playing, 1 Library, 2 Discover.
  final int screen;
  final bool? dark;

  /// Book to load into the player on launch. `'1'` means "the first
  /// playable book in the demo catalog".
  final String? play;

  /// Book whose detail view to open on launch.
  final String? book;

  const DemoDeepLink({
    this.screen = 0,
    this.dark,
    this.play,
    this.book,
  });

  static const DemoDeepLink none = DemoDeepLink();

  bool get isEmpty => screen == 0 && dark == null && play == null && book == null;

  factory DemoDeepLink.fromUri(Uri uri) {
    if (!kDemoMode) return none;
    final q = uri.queryParameters;

    final screen = switch (q['screen']?.toLowerCase()) {
      'library' => 1,
      'discover' => 2,
      'nowplaying' || 'now_playing' || 'player' => 0,
      _ => 0,
    };

    final bool? dark = switch (q['theme']?.toLowerCase()) {
      'dark' => true,
      'light' => false,
      _ => null,
    };

    return DemoDeepLink(
      screen: screen,
      dark: dark,
      play: _nonEmpty(q['play']),
      book: _nonEmpty(q['book']),
    );
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;
}

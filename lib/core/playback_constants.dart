// Shared playback tuning constants used by every player control surface
// (the Now Playing screen and the persistent player bar), so the two
// never drift out of sync with each other again.

/// Speed options offered by the speed-selector popup menus. Conventional
/// audiobook steps: quarter increments below 1x plus the wider top end.
const List<double> kPlaybackSpeedOptions = [
  0.5,
  0.75,
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
];

/// Skip amount (in seconds) for the rewind/fast-forward controls.
///
/// Material Icons only ships `_10_` and `_30_` suffixed skip glyphs (no
/// `_15_` variant exists), so the icon can never literally match this
/// value — see [SkipIntervalIcon] in `lib/widgets/skip_interval_icon.dart`,
/// which renders a generic glyph with this number stamped on it instead of
/// relying on a matching icon asset. Must stay in sync with
/// `AudioPlaybackService`'s own `skipForward`/`skipBackward` defaults.
const int kSkipSeconds = 15;

/// Skip intervals offered in the settings panel. 15 is the default and the
/// category convention; 10 suits dense non-fiction, 30 and 60 suit
/// re-finding your place after drifting off. The stamped-number approach
/// described above is what makes this configurable at all — an icon set
/// with no `_15_` glyph could never have carried four.
const List<int> kSkipSecondsOptions = [10, 15, 30, 60];

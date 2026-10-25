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

/// The default skip amount (in seconds), used for both the rewind and the
/// fast-forward controls until the user picks their own (they are separate
/// settings: `AppSettings.skipBackSeconds` / `skipForwardSeconds`). The
/// number is drawn beside the arrow by [SkipIntervalIcon]
/// (`lib/widgets/skip_interval_icon.dart`), so any interval can be shown.
/// Must stay in sync with `AudioPlaybackService`'s own
/// `skipForward`/`skipBackward` defaults.
const int kSkipSeconds = 15;

/// Skip intervals offered in the settings panel. 15 is the default and the
/// category convention; 10 suits dense non-fiction, 30 and 60 suit
/// re-finding your place after drifting off; 5 suits a quick re-listen.
const List<int> kSkipSecondsOptions = [5, 10, 15, 30, 60];

/// Shared playback tuning constants used by every player control surface
/// (the Now Playing screen and the persistent player bar), so the two
/// never drift out of sync with each other again.

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

/// Skip amount (in seconds) for the rewind/fast-forward controls. Must
/// match the icon used to represent it (`Icons.replay_15_rounded` /
/// `Icons.forward_15_rounded`) and `AudioPlaybackService`'s own defaults.
const int kSkipSeconds = 15;

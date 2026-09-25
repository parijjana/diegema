/// A shape for a group of Now Playing controls. Chosen in Settings, once
/// for the Up next / Speed / Sleep row ("Player buttons") and separately for
/// play, skip and chapter jumps ("Playback controls"); the behaviour is the
/// same in every shape (design canvas boards A, B and C).
enum PlayerControlsStyle {
  /// Three matching tiles, each with a small caption over its live value.
  tiles('Tiles'),

  /// Three round buttons with a caption underneath.
  round('Round'),

  /// One bar split into three segments.
  bar('Bar');

  final String label;
  const PlayerControlsStyle(this.label);

  static PlayerControlsStyle fromName(String? name,
          {PlayerControlsStyle fallback = PlayerControlsStyle.tiles}) =>
      PlayerControlsStyle.values
          .firstWhere((s) => s.name == name, orElse: () => fallback);
}

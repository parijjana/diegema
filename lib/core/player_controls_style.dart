/// How the phone Now Playing screen draws its Up next / Speed / Sleep row.
/// Chosen in Settings; all three share the same popup logic and differ only
/// in shape (design canvas boards A, B and C).
enum PlayerControlsStyle {
  /// Three matching tiles, each with a small caption over its live value.
  tiles('Tiles'),

  /// Three round buttons with a caption underneath.
  round('Round'),

  /// One bar split into three segments.
  bar('Bar');

  final String label;
  const PlayerControlsStyle(this.label);

  static PlayerControlsStyle fromName(String? name) =>
      PlayerControlsStyle.values.firstWhere((s) => s.name == name,
          orElse: () => PlayerControlsStyle.tiles);
}

/// Timecode formatting, in one place. Three widgets each carried their own
/// private, identical `_formatDuration`.
///
/// Rendered with tabular figures (see `AppType.tabularCaption`) so the
/// digits do not jitter as the clock ticks.
String formatTimecode(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final minutes = two(duration.inMinutes.remainder(60));
  final seconds = two(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) return '${duration.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}

/// A human runtime for metadata lines ("4 h 12 m", "38 min").
///
/// Returns `null` — never `"0.0 mins"` — when the duration is unknown.
/// Local content never has its real audio duration probed, so a zero here
/// means "not known", and the caller must render an em dash or omit the
/// row rather than assert the book is zero seconds long.
String? formatRuntime(int seconds) {
  if (seconds <= 0) return null;
  final d = Duration(seconds: seconds);
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes.remainder(60)} m';
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '$seconds s';
}

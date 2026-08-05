import 'package:flutter/material.dart';

/// Which way a [SkipIntervalIcon] skips.
enum SkipDirection { backward, forward }

/// A skip-interval control glyph: a generic replay/fast-forward icon with
/// the actual skip amount (in seconds) stamped on top of it.
///
/// Material Icons only ships `_10_` and `_30_` suffixed skip icons — there
/// is no `_15_` variant — which is why this app used to pair a "10" icon
/// with code that actually skipped 15 seconds. Labelling a generic glyph
/// with the real number sidesteps the problem for any interval, with no
/// icon/behaviour mismatch possible.
///
/// Carries its own [Semantics] label (e.g. "Skip back 15 seconds") since
/// the icon glyph alone conveys nothing to screen reader users; wrap this
/// in an [IconButton] as the `icon:` widget as usual.
class SkipIntervalIcon extends StatelessWidget {
  final SkipDirection direction;
  final int seconds;
  final double size;
  final Color color;

  const SkipIntervalIcon({
    super.key,
    required this.direction,
    required this.seconds,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = direction == SkipDirection.backward
        ? Icons.replay_rounded
        : Icons.fast_forward_rounded;
    final label = direction == SkipDirection.backward
        ? 'Skip back $seconds seconds'
        : 'Skip forward $seconds seconds';

    // Derive the label size from the theme's type scale rather than a
    // hardcoded magic number, so it stays proportionate wherever this is
    // dropped in (48px circular buttons on Now Playing, 20px inline icons
    // on the persistent bar).
    final baseLabelStyle =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 10);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(glyph, size: size, color: color),
            Text(
              '$seconds',
              style: baseLabelStyle.copyWith(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Which way a [SkipIntervalIcon] skips.
enum SkipDirection { backward, forward }

/// A skip-interval control glyph: an open circular-arrow icon with the
/// actual skip amount (in seconds) stamped inside it. Forward mirrors the
/// same glyph rather than using a different one, so the pair matches.
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
    // Both directions use the same open circular-arrow glyph, the forward
    // one mirrored. `Icons.fast_forward_rounded` was used here for forward
    // and it does not work: it is a *filled* double-triangle, so the number
    // stamped on top of it is illegible and the control just reads as a
    // generic fast-forward — losing the "15" that is the whole point. The
    // replay glyph is an open ring with empty space in the middle, which is
    // where the number belongs, and mirroring it keeps the two skip buttons
    // a matched pair (the convention every audiobook player uses).
    final forward = direction == SkipDirection.forward;
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
            // Only the glyph is mirrored — the number must not be, so it
            // stays a sibling in the Stack rather than a child of this.
            Transform.scale(
              scaleX: forward ? -1.0 : 1.0,
              child: Icon(Icons.replay_rounded, size: size, color: color),
            ),
            Text(
              '$seconds',
              style: baseLabelStyle.copyWith(
                // 0.34 put the number at 8.2px inside a 24px glyph — below
                // this design system's own 13px type floor, and verified
                // illegible in a rendered screenshot. The ring's inner hole
                // is what caps this; going much past 0.42 collides with it.
                fontSize: size * 0.42,
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

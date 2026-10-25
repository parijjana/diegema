import 'package:flutter/material.dart';

/// Which way a [SkipIntervalIcon] skips.
enum SkipDirection { backward, forward }

/// The largest the number under a skip arrow is allowed to scale to. The
/// control sits in a fixed-size tap target, so letting the number follow the
/// system text scale without limit (2.0 = 26px) would burst out of it; 1.5
/// is still 19.5px, well above the 13px floor, and the number is a
/// supplement to the arrow, not prose.
const double kSkipNumberMaxTextScale = 1.5;

/// A skip control glyph: a plain arrow with the skip amount (in seconds)
/// **underneath** it, never inside it.
///
/// The layout rule, the same for every transport style and the mini player:
/// the arrow on top, the number centred directly below it, the pair centred
/// in the tap target. (Beside-the-arrow on the outer side was rejected: it
/// widens the transport row past 360dp at larger text, where a column does
/// not.) Back is [Icons.replay_rounded]; forward is its clockwise
/// counterpart [Icons.refresh_rounded]; neither has anything inside it,
/// which is what lets the number be crisp at the 13px floor.
///
/// [size] is the arrow's size; the whole control is at least [size] +
/// the number's line tall and is meant to be centred in a 48dp+ target by
/// the caller. Carries its own [Semantics] label (e.g. "Skip back 30
/// seconds"); the caller's button usually repeats it, which is harmless.
class SkipIntervalIcon extends StatelessWidget {
  final SkipDirection direction;
  final int seconds;

  /// The arrow's size.
  final double size;
  final Color color;

  const SkipIntervalIcon({
    super.key,
    required this.direction,
    required this.seconds,
    required this.size,
    required this.color,
  });

  /// The arrow glyph, exposed so tests can find it.
  static IconData iconFor(SkipDirection direction) =>
      direction == SkipDirection.backward
          ? Icons.replay_rounded
          : Icons.refresh_rounded;

  @override
  Widget build(BuildContext context) {
    final label = direction == SkipDirection.backward
        ? 'Skip back $seconds seconds'
        : 'Skip forward $seconds seconds';
    final base =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 13);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconFor(direction), size: size, color: color),
          Text(
            '$seconds',
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: kSkipNumberMaxTextScale),
            style: base.copyWith(
              // 13px is this design system's type floor.
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

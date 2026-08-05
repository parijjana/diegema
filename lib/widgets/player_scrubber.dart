import 'package:flutter/material.dart';

import '../core/utils/duration_format.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';

/// Seek bar plus elapsed/total timecodes.
///
/// Track is 6px and the thumb 20px (both from the sizing tokens); the old
/// bar used a 3px track and a 6px-radius thumb, which is a 12px target.
/// Timecodes are 13px tabular `text-secondary` — the old 10px
/// `onSurface` α0.6 pair measured 4.29:1 on white and failed AA.
///
/// Playback position is deliberately **not** a live region: announcing
/// every tick would make the screen unusable with a screen reader. The
/// slider itself carries the accessible value.
class PlayerScrubber extends StatelessWidget {
  final AudioPlaybackService audioService;

  const PlayerScrubber({super.key, required this.audioService});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ValueListenableBuilder<Duration>(
      valueListenable: audioService.positionNotifier,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: audioService.durationNotifier,
          builder: (context, duration, __) {
            final max = duration.inSeconds.toDouble();
            final safeMax = max > 0 ? max : 1.0;
            final value = position.inSeconds.toDouble().clamp(0.0, safeMax);

            return Column(
              children: [
                Semantics(
                  slider: true,
                  label: 'Seek',
                  value:
                      '${formatTimecode(position)} of ${formatTimecode(duration)}',
                  excludeSemantics: true,
                  child: Slider(
                    value: value,
                    max: safeMax,
                    onChanged: (v) =>
                        audioService.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatTimecode(position),
                          style: AppType.tabularCaption(c.textSecondary)),
                      Text(formatTimecode(duration),
                          style: AppType.tabularCaption(c.textSecondary)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

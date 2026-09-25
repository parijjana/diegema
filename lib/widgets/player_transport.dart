import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/playback_constants.dart';
import '../core/player_controls_style.dart';
import '../core/utils/duration_format.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import 'skip_interval_icon.dart';

/// The Now Playing transport cluster.
///
/// Differences from the original controls implementation it replaced
/// (`now_playing_controls.dart`, since deleted):
/// - **No outer `FittedBox(scaleDown)`.** When the cluster does not fit it
///   [Wrap]s onto a second line; it never shrinks controls below the 44px
///   minimum target.
/// - **No coloured bloom** behind the play button (the 24px teal glow was
///   neon-pass residue). Elevation comes from `shadow-2`.
/// - Skip buttons render their interval from the same value that drives the
///   seek, via [SkipIntervalIcon], so the old "icon says 10, code does 15"
///   mismatch is structurally impossible. That value is now the user's
///   `playback.skip_seconds` setting rather than a constant, which the
///   stamped-number approach supports for free.
/// - Play/pause is **one toggle whose label changes**, not two icons that
///   swap with no accessible name.
class PlayerTransport extends StatelessWidget {
  final AudioPlaybackService audioService;
  final UnifiedAudiobook book;

  const PlayerTransport({
    super.key,
    required this.audioService,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = SettingsScope.maybeOf(context);
    // Read live rather than passed in: the interval is a user setting
    // (`playback.skip_seconds`) and both the seek and the number
    // stamped on the glyph must come from the same value, which is
    // what makes an "icon says 10, code does 15" mismatch impossible.
    // Falls back to the default when no scope is present, so a test
    // pumping this widget alone needs no settings plumbing.
    final skipSeconds = settings?.skipSeconds ?? kSkipSeconds;
    // The shape and size of the cluster (Settings > "Playback controls").
    final style = settings?.transportStyle ?? PlayerControlsStyle.round;

    final controls = [
      _TransportSpec(
        semanticLabel: 'Previous chapter',
        weight: 1,
        onPressed: () {
          final idx = audioService.chapterIndexNotifier.value;
          if (idx > 0) {
            audioService.loadBook(book, initialChapterIndex: idx - 1);
          }
        },
        child: Icon(Icons.skip_previous_rounded,
            size: style == PlayerControlsStyle.round ? Dim.iconSm : Dim.iconMd,
            color: c.text),
      ),
      _TransportSpec(
        semanticLabel: 'Skip back $skipSeconds seconds',
        weight: 1.25,
        onPressed: () => audioService.skipBackward(seconds: skipSeconds),
        child: SkipIntervalIcon(
          direction: SkipDirection.backward,
          seconds: skipSeconds,
          // iconLg, not iconMd: these two carry a number inside them, so
          // they need more room than a plain glyph.
          size: Dim.iconLg,
          color: c.text,
        ),
      ),
      null, // play/pause
      _TransportSpec(
        semanticLabel: 'Skip forward $skipSeconds seconds',
        weight: 1.25,
        onPressed: () => audioService.skipForward(seconds: skipSeconds),
        child: SkipIntervalIcon(
          direction: SkipDirection.forward,
          seconds: skipSeconds,
          size: Dim.iconLg,
          color: c.text,
        ),
      ),
      _TransportSpec(
        semanticLabel: 'Next chapter',
        weight: 1,
        onPressed: () {
          final idx = audioService.chapterIndexNotifier.value;
          if (idx < book.chapters.length - 1) {
            audioService.loadBook(book, initialChapterIndex: idx + 1);
          }
        },
        child: Icon(Icons.skip_next_rounded,
            size: style == PlayerControlsStyle.round ? Dim.iconSm : Dim.iconMd,
            color: c.text),
      ),
    ];
    const playWeight = 1.5;

    switch (style) {
      case PlayerControlsStyle.round:
        // The original cluster. When it does not fit it wraps onto a
        // second line; it never shrinks controls below the 44px minimum.
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Sp.x2,
          runSpacing: Sp.x3,
          children: [
            for (final spec in controls)
              spec == null
                  ? _PlayPauseButton(
                      audioService: audioService,
                      width: Dim.tapPrimary,
                      height: Dim.tapPrimary,
                    )
                  : _TransportButton(
                      spec: spec,
                      width: spec.weight == 1 ? Dim.tapMin : Dim.tapComfy,
                      height: spec.weight == 1 ? Dim.tapMin : Dim.tapComfy,
                    ),
          ],
        );
      case PlayerControlsStyle.tiles:
      case PlayerControlsStyle.bar:
        final bar = style == PlayerControlsStyle.bar;
        // Fixed widths from the available space, weighted so play is the
        // biggest target and the chapter jumps the smallest. Capped so a
        // wide window does not turn them into slabs.
        return LayoutBuilder(builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 440.0);
          const gap = Sp.x2;
          final totalWeight = controls.fold<double>(
              0, (sum, spec) => sum + (spec?.weight ?? playWeight));
          final usable = bar ? width - 2 : width - gap * 4;
          double widthOf(_TransportSpec? spec) =>
              usable * (spec?.weight ?? playWeight) / totalWeight;
          final height = bar ? 68.0 : 64.0;
          final radius = bar ? R.md : R.lg;
          final row = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0 && !bar) const SizedBox(width: gap),
                controls[i] == null
                    ? Padding(
                        padding: EdgeInsets.all(bar ? Sp.x1 : 0),
                        child: _PlayPauseButton(
                          audioService: audioService,
                          width: widthOf(null) - (bar ? Sp.x1 * 2 : 0),
                          height: bar ? height - Sp.x1 * 2 : Dim.tapPrimary,
                          borderRadius: radius,
                        ),
                      )
                    : _TransportButton(
                        spec: controls[i]!,
                        width: widthOf(controls[i]),
                        height: height,
                        borderRadius: radius,
                        decorated: !bar,
                      ),
              ],
            ],
          );
          return Center(
            child: bar
                ? Container(
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.72),
                      borderRadius: R.lg,
                      border: Border.all(color: c.border),
                      boxShadow: c.shadowUi,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: row,
                  )
                : row,
          );
        });
    }
  }
}

class _TransportSpec {
  final String semanticLabel;

  /// Relative width in the tiles and bar shapes.
  final double weight;
  final VoidCallback onPressed;
  final Widget child;

  const _TransportSpec({
    required this.semanticLabel,
    required this.weight,
    required this.onPressed,
    required this.child,
  });
}

/// The primary play/pause target. One toggle, one changing label. A circle
/// unless [borderRadius] is given (the tiles and bar shapes).
class _PlayPauseButton extends StatelessWidget {
  final AudioPlaybackService audioService;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  const _PlayPauseButton({
    required this.audioService,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = borderRadius;
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: audioService.stateNotifier,
      builder: (context, state, _) {
        final isPlaying = state == PlaybackState.playing;
        final isLoading = state == PlaybackState.loading;
        final label = isLoading ? 'Loading' : (isPlaying ? 'Pause' : 'Play');

        return Semantics(
          button: true,
          label: label,
          toggled: isPlaying,
          excludeSemantics: true,
          child: Tooltip(
            message: label,
            child: InkWell(
              onTap: isLoading ? null : audioService.togglePlayPause,
              customBorder: radius == null
                  ? const CircleBorder()
                  : RoundedRectangleBorder(borderRadius: radius),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: radius,
                  color: c.accentFill,
                  boxShadow: c.shadow2,
                ),
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: Dim.iconMd,
                          height: Dim.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: c.textOnAccent,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: Dim.iconXl,
                        color: c.textOnAccent,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A secondary transport control: a circle by default, a rounded tile when
/// [borderRadius] is given, and undecorated inside the bar shape (the bar
/// draws the surface).
class _TransportButton extends StatelessWidget {
  final _TransportSpec spec;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool decorated;

  const _TransportButton({
    required this.spec,
    required this.width,
    required this.height,
    this.borderRadius,
    this.decorated = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = borderRadius;
    return Semantics(
      button: true,
      label: spec.semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: spec.semanticLabel,
        child: InkWell(
          onTap: spec.onPressed,
          customBorder: radius == null
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: radius),
          child: Container(
            width: width,
            height: height,
            decoration: decorated
                ? BoxDecoration(
                    shape:
                        radius == null ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: radius,
                    color: radius == null
                        ? c.surfaceSunken
                        : c.surface.withValues(alpha: 0.72),
                    border: Border.all(color: c.border),
                    boxShadow: c.shadowUi,
                  )
                : null,
            child: Center(child: spec.child),
          ),
        ),
      ),
    );
  }
}

/// What one Now Playing action shows, independent of the shape it is drawn
/// in (the Settings "Player buttons" toggle picks the shape).
class ActionFace {
  final IconData icon;

  /// What the control is: "Up next", "Speed", "Sleep".
  final String caption;

  /// Its live state: the next chapter, "1.0x", the time left or "Off".
  final String value;

  /// One short word for the compact shapes (round, bar): "Up next",
  /// "1.0x", "Sleep" or the time left.
  final String short;

  /// Something is running (a sleep timer) and deserves emphasis.
  final bool active;

  const ActionFace({
    required this.icon,
    required this.caption,
    required this.value,
    required this.short,
    this.active = false,
  });
}

typedef ActionFaceBuilder = Widget Function(
    BuildContext context, ActionFace face);

/// Playback speed selector. Shows the current value (the old popup showed
/// nothing until opened) and carries an accessible name.
class SpeedSelector extends StatelessWidget {
  final AudioPlaybackService audioService;

  /// Draws the control in the phone Now Playing action row's chosen shape
  /// instead of the free-standing pill. The popup-menu selection logic
  /// below is unchanged either way.
  final ActionFaceBuilder? face;

  const SpeedSelector({
    super.key,
    required this.audioService,
    this.face,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<double>(
      valueListenable: audioService.speedNotifier,
      builder: (context, speed, _) {
        return PopupMenuButton<double>(
          initialValue: speed,
          tooltip: 'Playback speed',
          onSelected: audioService.setSpeed,
          itemBuilder: (context) => kPlaybackSpeedOptions
              .map((s) => PopupMenuItem<double>(
                    value: s,
                    child: Text('${s}x speed'),
                  ))
              .toList(),
          child: Semantics(
            button: true,
            label: 'Playback speed, currently ${speed}x',
            excludeSemantics: true,
            child: face != null
                ? face!(
                    context,
                    ActionFace(
                      icon: Icons.speed_rounded,
                      caption: 'Speed',
                      value: '${speed}x',
                      short: '${speed}x',
                    ),
                  )
                : _ChipShell(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed_rounded,
                            size: Dim.iconSm, color: c.accentText),
                        const SizedBox(width: Sp.x2),
                        Flexible(
                          child: Text('${speed}x',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppType.label.copyWith(color: c.accentText)),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Sleep-timer selector. Active state is signalled by the label text as
/// well as the fill, never by colour alone.
class SleepTimerSelector extends StatelessWidget {
  final AudioPlaybackService audioService;

  /// See [SpeedSelector.face].
  final ActionFaceBuilder? face;

  const SleepTimerSelector({
    super.key,
    required this.audioService,
    this.face,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<Duration?>(
      valueListenable: audioService.sleepTimerNotifier,
      builder: (context, remaining, _) {
        final active = remaining != null;
        final text = active ? formatTimecode(remaining) : 'Sleep timer';
        return PopupMenuButton<int>(
          tooltip: 'Sleep timer',
          onSelected: (minutes) {
            if (minutes == 0) {
              audioService.cancelSleepTimer();
            } else {
              audioService.setSleepTimer(Duration(minutes: minutes));
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<int>(value: 0, child: Text('Off')),
            PopupMenuItem<int>(value: 15, child: Text('15 minutes')),
            PopupMenuItem<int>(value: 30, child: Text('30 minutes')),
            PopupMenuItem<int>(value: 45, child: Text('45 minutes')),
            PopupMenuItem<int>(value: 60, child: Text('60 minutes')),
          ],
          child: Semantics(
            button: true,
            label: active ? 'Sleep timer, $text remaining' : 'Sleep timer, off',
            excludeSemantics: true,
            child: face != null
                ? face!(
                    context,
                    ActionFace(
                      icon: Icons.bedtime_rounded,
                      caption: 'Sleep',
                      value: active ? text : 'Off',
                      short: active ? text : 'Sleep',
                      active: active,
                    ),
                  )
                : _ChipShell(
                    emphasised: active,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bedtime_rounded,
                            size: Dim.iconSm,
                            color: active ? c.accentText : c.textSecondary),
                        const SizedBox(width: Sp.x2),
                        Flexible(
                          child: Text(text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.label.copyWith(
                                  color:
                                      active ? c.accentText : c.textSecondary)),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ChipShell extends StatelessWidget {
  final Widget child;
  final bool emphasised;

  const _ChipShell({
    required this.child,
    this.emphasised = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // No `alignment:` here. A Container with an alignment expands to fill
    // whatever it is given, which made both chips stretch the full width of
    // the player column instead of hugging their labels. Centring is the
    // Row's job.
    return Container(
      constraints: const BoxConstraints(minHeight: Dim.tapMin),
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
      decoration: BoxDecoration(
        color: emphasised ? c.accentWash : c.surfaceSunken,
        borderRadius: R.pill,
        border: Border.all(color: emphasised ? c.accent : c.borderContrast),
        boxShadow: c.shadowUi,
      ),
      // `Flexible`, not a bare child: at large text scales the label is
      // wider than a 360px phone can give it, and an unflexed child in a
      // min-size Row overflows rather than shrinking. The audience for this
      // app explicitly includes low-vision readers, so a 2x text scale is a
      // supported case, not an edge one.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Flexible(child: child)],
      ),
    );
  }
}

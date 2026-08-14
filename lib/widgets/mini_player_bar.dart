import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/playback_constants.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import 'app_book_cover.dart';
import 'skip_interval_icon.dart';

/// Compact persistent player. Replaces `persistent_player_bar.dart`.
///
/// Changes that matter:
/// - **Opaque `surface`**, not a 20-sigma backdrop blur, so its text
///   contrast is a fixed, measured number rather than a function of
///   whatever is scrolling underneath.
/// - The **cover** takes the leading slot; the bookmark button that used to
///   sit there moved out (it belongs in the book view, not the mini bar).
/// - A [LayoutBuilder] **drops** the secondary skip controls below 560px
///   rather than `FittedBox`-shrinking the whole cluster below a usable
///   size. Play/pause is never dropped.
/// - A **playback error state**, which the old bar had none of.
class MiniPlayerBar extends StatelessWidget {
  final AudioPlaybackService audioService;

  /// Opens the full player (the Now Playing screen's active state).
  final VoidCallback onOpenPlayer;

  const MiniPlayerBar({
    super.key,
    required this.audioService,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Read live rather than passed in: the interval is a user setting
    // (`playback.skip_seconds`) and both the seek and the number
    // stamped on the glyph must come from the same value, which is
    // what makes an "icon says 10, code does 15" mismatch impossible.
    // Falls back to the default when no scope is present, so a test
    // pumping this widget alone needs no settings plumbing.
    final skipSeconds =
        SettingsScope.maybeOf(context)?.skipSeconds ?? kSkipSeconds;

    return ValueListenableBuilder<UnifiedAudiobook?>(
      valueListenable: audioService.currentBookNotifier,
      builder: (context, book, _) {
        if (book == null) return const SizedBox.shrink();

        return Material(
          color: c.surface,
          child: InkWell(
            onTap: onOpenPlayer,
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: c.border)),
                boxShadow: c.shadow3,
              ),
              padding: const EdgeInsets.fromLTRB(Sp.x3, Sp.x2, Sp.x3, Sp.x2),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showSkips = constraints.maxWidth >= 560;
                    return Row(
                      children: [
                        Semantics(
                          label: 'Open player for ${book.title}',
                          button: true,
                          child: AppBookCover(
                            bookId: book.id,
                            title: book.title,
                            coverUrl: book.coverArtUrlOrPath,
                            width: 40,
                            height: 52,
                          ),
                        ),
                        const SizedBox(width: Sp.x3),
                        Expanded(child: _TitleBlock(book: book, audioService: audioService)),
                        const SizedBox(width: Sp.x2),
                        if (showSkips)
                          _BarIconButton(
                            label: 'Skip back $skipSeconds seconds',
                            onPressed: () => audioService.skipBackward(
                                seconds: skipSeconds),
                            child: SkipIntervalIcon(
                              direction: SkipDirection.backward,
                              seconds: skipSeconds,
                              size: Dim.iconSm,
                              color: c.text,
                            ),
                          ),
                        _MiniPlayPause(audioService: audioService),
                        if (showSkips)
                          _BarIconButton(
                            label: 'Skip forward $skipSeconds seconds',
                            onPressed: () => audioService.skipForward(
                                seconds: skipSeconds),
                            child: SkipIntervalIcon(
                              direction: SkipDirection.forward,
                              seconds: skipSeconds,
                              size: Dim.iconSm,
                              color: c.text,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  const _TitleBlock({required this.book, required this.audioService});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.bodyLg.copyWith(
              color: c.text, fontWeight: FontWeight.w600),
        ),
        ValueListenableBuilder<PlaybackState>(
          valueListenable: audioService.stateNotifier,
          builder: (context, state, _) {
            if (state == PlaybackState.error) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: Dim.iconSm, color: c.danger),
                  const SizedBox(width: Sp.x1),
                  Flexible(
                    child: Text(
                      'Could not play this chapter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: c.danger),
                    ),
                  ),
                ],
              );
            }
            return ValueListenableBuilder<int>(
              valueListenable: audioService.chapterIndexNotifier,
              builder: (context, index, __) {
                final title = index < book.chapters.length
                    ? book.chapters[index].title
                    : '';
                return Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: c.textSecondary),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _MiniPlayPause extends StatelessWidget {
  final AudioPlaybackService audioService;
  const _MiniPlayPause({required this.audioService});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: audioService.stateNotifier,
      builder: (context, state, _) {
        if (state == PlaybackState.loading) {
          return const SizedBox(
            width: Dim.tapMin,
            height: Dim.tapMin,
            child: Center(
              child: SizedBox(
                  width: Dim.iconSm,
                  height: Dim.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final isPlaying = state == PlaybackState.playing;
        final label = isPlaying ? 'Pause' : 'Play';
        return Semantics(
          button: true,
          label: label,
          toggled: isPlaying,
          excludeSemantics: true,
          child: IconButton(
            tooltip: label,
            onPressed: audioService.togglePlayPause,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: Dim.iconLg,
              color: c.accentText,
            ),
          ),
        );
      },
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget child;
  const _BarIconButton({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: child,
      ),
    );
  }
}

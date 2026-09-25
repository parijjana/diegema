import 'package:flutter/material.dart';

import '../core/utils/duration_format.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';

/// "Up next" — the queue for the book currently playing.
///
/// For an audiobook the queue *is* the chapter list: there is no shuffle and
/// no next-track ambiguity, so "what plays after this" is simply "the next
/// chapter". Until this existed the player could only step one chapter at a
/// time with next/prev, with no way to see where you were in the book or to
/// jump to a specific point — the one thing you actually want mid-listen.
///
/// This replaces the old "Your list" peek, which flipped Now Playing back to
/// the continue-listening list while audio kept running. That list now has a
/// permanent home in Library's "In progress" section, so the player no longer
/// has to double as a way back to it.
///
/// Opened via [showUpNext], which picks a bottom sheet on phone widths and a
/// centred dialog on wide ones — the same selection-surface split Discover
/// and Library use, so all three screens agree. Both surfaces share this
/// same list and sticky footer; only the outer size constraints differ.
///
/// Rows read their state from [chapter's index vs the live
/// `chapterIndexNotifier`]: **played** (dimmed, a check mark, "Played ·
/// duration"), **current** (a highlighted tile with an equalizer glyph,
/// "Playing · mm:ss left" and a thin live progress bar driven by
/// `positionNotifier`/`durationNotifier`), or **upcoming** (a plain number
/// and duration, as before).
class UpNextSheet extends StatefulWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;

  const UpNextSheet({
    super.key,
    required this.book,
    required this.audioService,
  });

  @override
  State<UpNextSheet> createState() => _UpNextSheetState();
}

/// Estimate used only to open the list pre-scrolled to the current chapter.
/// It does not need to be exact — `ListView`'s own layout still determines
/// real row positions — it only has to land close enough that "near the top
/// of the list" holds without the initial frame flashing chapter 1 first.
const double _estimatedRowExtent = 64;

class _UpNextSheetState extends State<UpNextSheet> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final current = widget.audioService.chapterIndexNotifier.value;
    final target = (current * _estimatedRowExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final book = widget.book;
    final audioService = widget.audioService;

    return AnimatedBuilder(
      animation: Listenable.merge([
        audioService.chapterIndexNotifier,
        audioService.positionNotifier,
        audioService.durationNotifier,
      ]),
      builder: (context, _) {
        final currentIndex = audioService.chapterIndexNotifier.value;
        final isLastChapter = currentIndex >= book.chapters.length - 1;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(book: book, currentIndex: currentIndex),
            Divider(height: 1, color: c.border),
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                itemCount: book.chapters.length,
                itemBuilder: (context, i) {
                  // Any chapter, played or not, is a place to go: the list
                  // is for free navigation, not only for looking ahead.
                  void jumpTo(int index) {
                    Navigator.of(context).pop();
                    audioService.loadBook(book, initialChapterIndex: index);
                  }

                  if (i < currentIndex) {
                    return _PlayedRow(
                      chapter: book.chapters[i],
                      onTap: () => jumpTo(i),
                    );
                  }
                  if (i == currentIndex) {
                    return _CurrentRow(
                      chapter: book.chapters[i],
                      audioService: audioService,
                    );
                  }
                  return _UpcomingRow(
                    index: i,
                    chapter: book.chapters[i],
                    onTap: () => jumpTo(i),
                  );
                },
              ),
            ),
            _Footer(
              nextChapterTitle: isLastChapter
                  ? null
                  : book.chapters[currentIndex + 1].title,
              onClose: () => Navigator.of(context).pop(),
              onSkip: () => audioService.nextChapter(),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final UnifiedAudiobook book;
  final int currentIndex;
  const _Header({required this.book, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Chapters strictly after the one playing now — "left" means "not
    // started yet", so the current, partially-heard chapter is excluded
    // from both the count and (mostly) the time, same as the mockup's
    // "26 of 28 left" against a 28-chapter book sitting on chapter 2.
    final remainingCount = book.chapters.length - currentIndex - 1;
    var remainingSeconds = 0;
    for (var i = currentIndex + 1; i < book.chapters.length; i++) {
      remainingSeconds += book.chapters[i].durationSeconds;
    }
    final remainingTime = formatRuntime(remainingSeconds);

    final summary = remainingTime == null
        ? '$remainingCount of ${book.chapters.length} left'
        : '$remainingCount of ${book.chapters.length} left · $remainingTime';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x5, Sp.x5, Sp.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              'Up next',
              style: AppType.serif(AppType.titleMd).copyWith(color: c.text),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Text(summary,
              style: AppType.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// A chapter already heard: dimmed, a check mark instead of its number.
class _PlayedRow extends StatelessWidget {
  final AudiobookChapter chapter;
  final VoidCallback onTap;
  const _PlayedRow({required this.chapter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = chapter.durationSeconds > 0
        ? formatTimecode(Duration(seconds: chapter.durationSeconds))
        : null;

    return Semantics(
      button: true,
      label: duration == null
          ? '${chapter.title}. Played.'
          : '${chapter.title}. Played, $duration.',
      excludeSemantics: true,
      child: _Row(
        onTap: onTap,
        leading: Icon(Icons.check_rounded, color: c.textMuted, size: 20),
        title: Text(
          chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.body.copyWith(color: c.textMuted),
        ),
        subtitle: Text(
          duration == null ? 'Played' : 'Played · $duration',
          style: AppType.caption.copyWith(color: c.textMuted),
        ),
      ),
    );
  }
}

/// The chapter playing right now: a highlighted tile with an equalizer
/// glyph, a live "time left" line and a thin progress bar.
class _CurrentRow extends StatelessWidget {
  final AudiobookChapter chapter;
  final AudioPlaybackService audioService;
  const _CurrentRow({required this.chapter, required this.audioService});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final position = audioService.positionNotifier.value;
    final duration = audioService.durationNotifier.value;
    final hasDuration = duration > Duration.zero;
    final rawRemaining = duration - position;
    final remaining = hasDuration
        ? (rawRemaining.isNegative ? Duration.zero : rawRemaining)
        : null;
    final progress =
        hasDuration ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: remaining == null
          ? '${chapter.title}. Playing now.'
          : '${chapter.title}. Playing now, ${formatTimecode(remaining)} left.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x1),
        child: Material(
          color: c.accentWash,
          borderRadius: R.md,
          child: _Row(
            leading: Icon(Icons.graphic_eq_rounded,
                color: c.accentText, size: 22),
            title: Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body
                  .copyWith(color: c.accentText, fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  remaining == null
                      ? 'Playing'
                      : 'Playing · ${formatTimecode(remaining)} left',
                  style: AppType.caption.copyWith(color: c.accentText),
                ),
                const SizedBox(height: Sp.x1),
                ClipRRect(
                  borderRadius: R.pill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: c.accent.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(c.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A chapter not reached yet: plain number, title and duration — unchanged
/// from before this redesign.
class _UpcomingRow extends StatelessWidget {
  final int index;
  final AudiobookChapter chapter;
  final VoidCallback onTap;
  const _UpcomingRow({
    required this.index,
    required this.chapter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = chapter.durationSeconds > 0
        ? formatTimecode(Duration(seconds: chapter.durationSeconds))
        : null;

    return Semantics(
      button: true,
      label: chapter.title,
      excludeSemantics: true,
      child: _Row(
        onTap: onTap,
        leading: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: c.text),
        ),
        title: Text(
          chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.body.copyWith(color: c.text, fontWeight: FontWeight.w500),
        ),
        subtitle: duration == null
            ? null
            : Text(duration, style: AppType.caption.copyWith(color: c.textSecondary)),
      ),
    );
  }
}

/// Shared row shell: a >=56px tall tile with a fixed 28px leading slot,
/// title and optional subtitle. All three row kinds ([_PlayedRow],
/// [_CurrentRow], [_UpcomingRow]) lay out through this so the rhythm of the
/// list stays identical regardless of state.
class _Row extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onTap;

  const _Row({
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: R.md,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 28, child: Center(child: leading)),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: Sp.x1),
                      subtitle!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky footer: a square Close button and, on every chapter but the
/// last, a primary "Skip to `<next>`" button that advances the queue
/// without closing the sheet — the equalizer glyph simply moves down to
/// the new current row.
class _Footer extends StatelessWidget {
  final String? nextChapterTitle;
  final VoidCallback onClose;
  final VoidCallback onSkip;

  const _Footer({
    required this.nextChapterTitle,
    required this.onClose,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, Sp.x5),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Close',
            excludeSemantics: true,
            child: SizedBox(
              width: Dim.tapComfy,
              height: Dim.tapComfy,
              child: OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(borderRadius: R.md),
                  side: BorderSide(color: c.border),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(Icons.close_rounded, color: c.text, size: Dim.iconMd),
              ),
            ),
          ),
          if (nextChapterTitle != null) ...[
            const SizedBox(width: Sp.x3),
            Expanded(
              child: SizedBox(
                height: Dim.tapComfy,
                child: Semantics(
                  button: true,
                  label: 'Skip to $nextChapterTitle',
                  excludeSemantics: true,
                  child: FilledButton.icon(
                    onPressed: onSkip,
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(borderRadius: R.md),
                    ),
                    icon: const Icon(Icons.skip_next_rounded),
                    label: Text(
                      'Skip to $nextChapterTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens [UpNextSheet]. Bottom sheet on phone widths, centred dialog on wide
/// ones — matching Discover's and Library's detail surfaces.
///
/// The phone sheet caps at 70% of the screen height (down from 85%): the
/// sticky footer now eats into that budget on every open, where before the
/// list was the only thing below the drag handle.
Future<void> showUpNext(
  BuildContext context, {
  required UnifiedAudiobook book,
  required AudioPlaybackService audioService,
}) {
  final wide = MediaQuery.sizeOf(context).width >= Dim.wideBreakpoint;
  final sheet = UpNextSheet(book: book, audioService: audioService);

  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: sheet,
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.70,
      ),
      child: sheet,
    ),
  );
}

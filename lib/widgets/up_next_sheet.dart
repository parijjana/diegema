import 'package:flutter/material.dart';

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
/// and Library use, so all three screens agree.
class UpNextSheet extends StatelessWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;

  const UpNextSheet({
    super.key,
    required this.book,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ValueListenableBuilder<int>(
      valueListenable: audioService.chapterIndexNotifier,
      builder: (context, currentIndex, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x5, Sp.x5, Sp.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Up next',
                    style: AppType.serif(AppType.titleMd).copyWith(color: c.text),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                itemCount: book.chapters.length,
                itemBuilder: (context, i) {
                  final chapter = book.chapters[i];
                  final isCurrent = i == currentIndex;
                  final isPast = i < currentIndex;

                  return Semantics(
                    button: true,
                    selected: isCurrent,
                    label: isCurrent
                        ? '${chapter.title}. Playing now.'
                        : chapter.title,
                    excludeSemantics: true,
                    child: ListTile(
                      // Tapping loads the book at this chapter and starts
                      // playing it — the "browse to the exact location" the
                      // next/prev buttons could never give you.
                      onTap: () {
                        Navigator.of(context).pop();
                        audioService.loadBook(
                          book,
                          initialChapterIndex: i,
                        );
                      },
                      leading: SizedBox(
                        width: 28,
                        child: isCurrent
                            ? Icon(Icons.graphic_eq_rounded,
                                color: c.accentText, size: 20)
                            : Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: AppType.body.copyWith(
                                  color: isPast
                                      ? c.textSecondary
                                      : c.text,
                                ),
                              ),
                      ),
                      title: Text(
                        chapter.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                          color: isCurrent ? c.accentText : c.text,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      subtitle: chapter.durationSeconds > 0
                          ? Text(
                              _formatDuration(chapter.durationSeconds),
                              style: AppType.caption
                                  .copyWith(color: c.textSecondary),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

String _formatDuration(int seconds) {
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  final s = d.inSeconds.remainder(60);
  if (m > 0) return '${m}m';
  return '${s}s';
}

/// Opens [UpNextSheet]. Bottom sheet on phone widths, centred dialog on wide
/// ones — matching Discover's and Library's detail surfaces.
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
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: sheet,
    ),
  );
}

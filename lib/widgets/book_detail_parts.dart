import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/book_progress.dart';
import '../core/utils/chapter_title.dart';
import '../core/utils/duration_format.dart';
import '../core/utils/librivox_description.dart';
import '../domain/models/audiobook.dart';
import '../theme/app_theme.dart';

/// Building blocks shared by the Library and Discover book-detail surfaces,
/// so the two read as one family: one primary action, progress first,
/// chapters as a compact list.

/// Phone: pinned under the scrolling content, holding the one primary
/// action (full width, 56px).
class DetailStickyFooter extends StatelessWidget {
  final Widget child;

  const DetailStickyFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, Sp.x5),
      child: child,
    );
  }
}

/// The single filled 56px action of a detail surface.
class DetailPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Keeps the accent fill when [onPressed] is null (a finished download
  /// or one in flight), instead of the greyed disabled look.
  final bool keepFilledWhenDisabled;

  const DetailPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.keepFilledWhenDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: R.md),
          minimumSize: const Size(0, Dim.tapComfy),
          disabledBackgroundColor: keepFilledWhenDisabled ? c.accentFill : null,
          disabledForegroundColor:
              keepFilledWhenDisabled ? c.textOnAccent : null,
        ),
        icon: Icon(icon, size: Dim.iconMd),
        // Wraps rather than shrinks at large text scales.
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

enum BookAction { markFinished, reset, showFolder, hide, remove }

/// The "..." menu: everything that is not the one primary action.
class BookActionsMenu extends StatelessWidget {
  final VoidCallback onMarkFinished;
  final VoidCallback onReset;

  /// Null hides "Show in Finder" (no local files, or not a desktop).
  final VoidCallback? onShowFolder;
  final String showFolderLabel;

  /// Null hides "Hide from library".
  final VoidCallback? onHide;

  /// Null hides "Remove from library...".
  final VoidCallback? onRemove;

  const BookActionsMenu({
    super.key,
    required this.onMarkFinished,
    required this.onReset,
    this.onShowFolder,
    this.showFolderLabel = 'Show folder',
    this.onHide,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    PopupMenuItem<BookAction> item(BookAction a, IconData icon, String label,
        {Color? color}) {
      final fg = color ?? c.text;
      return PopupMenuItem<BookAction>(
        value: a,
        height: Dim.tapMin,
        child: Row(children: [
          Icon(icon, size: Dim.iconSm, color: fg),
          const SizedBox(width: Sp.x3),
          Expanded(child: Text(label, style: AppType.body.copyWith(color: fg))),
        ]),
      );
    }

    return PopupMenuButton<BookAction>(
      tooltip: 'More actions',
      icon: const Icon(Icons.more_horiz_rounded),
      style:
          IconButton.styleFrom(minimumSize: const Size(Dim.tapMin, Dim.tapMin)),
      constraints: const BoxConstraints(minWidth: 256),
      onSelected: (a) {
        switch (a) {
          case BookAction.markFinished:
            onMarkFinished();
          case BookAction.reset:
            onReset();
          case BookAction.showFolder:
            onShowFolder?.call();
          case BookAction.hide:
            onHide?.call();
          case BookAction.remove:
            onRemove?.call();
        }
      },
      itemBuilder: (context) => [
        item(BookAction.markFinished, Icons.check_circle_outline_rounded,
            'Mark as finished'),
        item(BookAction.reset, Icons.restart_alt_rounded, 'Reset progress…'),
        if (onShowFolder != null)
          item(BookAction.showFolder, Icons.folder_open_rounded,
              showFolderLabel),
        if (onHide != null)
          item(BookAction.hide, Icons.visibility_off_outlined,
              'Hide from library'),
        if (onRemove != null) ...[
          const PopupMenuDivider(),
          item(BookAction.remove, Icons.delete_outline_rounded,
              'Remove from library…',
              color: c.danger),
        ],
      ],
    );
  }
}

/// "Chapter 2 of 3", a 6px bar and "41% · 1 h 01 m left". Pieces whose data
/// is unknown (no chapter durations) are left out.
class BookProgressSummary extends StatelessWidget {
  final BookProgress progress;

  /// Wide column: the time left goes on its own line under the bar.
  final bool stacked;

  const BookProgressSummary(
      {super.key, required this.progress, this.stacked = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = progress.fraction;
    final pct = f == null ? null : '${(f * 100).floor()}%';
    final left = progress.finished
        ? null
        : (progress.remainingSeconds == null
            ? null
            : '${formatTimeLeft(progress.remainingSeconds!)} left');

    final title = progress.finished
        ? 'Finished'
        : 'Chapter ${progress.chapterNumber} of ${progress.chapterCount}';
    final trailing = stacked
        ? pct
        : [if (pct != null) pct, if (left != null) left].join(' · ');

    final titleText = Text(title, style: AppType.label.copyWith(color: c.text));
    final trailText = trailing == null || trailing.isEmpty
        ? null
        : Text(trailing, style: AppType.tabularCaption(c.textSecondary));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // A Wrap shrinks to its content; full width keeps the two ends
          // apart.
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Sp.x3,
            runSpacing: Sp.x1,
            children: [
              titleText,
              if (trailText != null) trailText,
            ],
          ),
        ),
        if (f != null) ...[
          const SizedBox(height: Sp.x2),
          Semantics(
            label: 'Book progress',
            value: pct,
            child: ClipRRect(
              borderRadius: R.pill,
              child: LinearProgressIndicator(
                value: f,
                minHeight: 6,
                backgroundColor: c.border,
                valueColor: AlwaysStoppedAnimation(c.accentFill),
              ),
            ),
          ),
        ],
        if (stacked && left != null) ...[
          const SizedBox(height: Sp.x2),
          Text(left, style: AppType.tabularCaption(c.textSecondary)),
        ],
      ],
    );
  }
}

/// One fact about a book: a phone icon+caption chip, or a wide
/// label/value row.
class BookMeta {
  final IconData icon;
  final String label;
  final String value;

  /// Rendered in the success colour (e.g. "Downloaded").
  final bool positive;

  /// A link-style action under the value (wide list), e.g. Show in Finder.
  final String? actionLabel;
  final VoidCallback? onAction;

  const BookMeta({
    required this.icon,
    required this.label,
    required this.value,
    this.positive = false,
    this.actionLabel,
    this.onAction,
  });
}

/// Phone: a wrapping row of icon + caption.
class BookMetaRow extends StatelessWidget {
  final List<BookMeta> items;

  const BookMetaRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Sp.x4,
      runSpacing: Sp.x2,
      children: [
        for (final m in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m.icon,
                size: Dim.iconSm - 4,
                color: m.positive ? c.success : c.textSecondary),
            const SizedBox(width: Sp.x2 - 2),
            Flexible(
              child: Text(
                m.value,
                style: AppType.caption.copyWith(
                    color: m.positive ? c.success : c.textSecondary,
                    fontWeight: m.positive ? FontWeight.w600 : null),
              ),
            ),
          ]),
      ],
    );
  }
}

/// Wide: label / value pairs.
class BookMetaList extends StatelessWidget {
  final List<BookMeta> items;

  const BookMetaList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x2 + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(m.label,
                      style: AppType.caption.copyWith(color: c.textMuted)),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.value,
                          style: AppType.caption.copyWith(
                              color: m.positive ? c.success : c.text,
                              fontWeight: m.positive ? FontWeight.w600 : null)),
                      if (m.actionLabel != null && m.onAction != null)
                        InkWell(
                          onTap: m.onAction,
                          borderRadius: R.xs,
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(minHeight: Dim.tapMin),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(m.actionLabel!,
                                  style: AppType.caption.copyWith(
                                      color: c.accentText,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "About": the summary clamped to three lines with Read more / Show less
/// (offered only when the text actually overflows).
class ExpandableAbout extends StatefulWidget {
  final String text;

  const ExpandableAbout({super.key, required this.text});

  @override
  State<ExpandableAbout> createState() => _ExpandableAboutState();
}

class _ExpandableAboutState extends State<ExpandableAbout> {
  static const int _collapsedLines = 3;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ExpandableAbout old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppType.body.copyWith(color: c.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: AppType.label.copyWith(color: c.text)),
        const SizedBox(height: Sp.x1),
        LayoutBuilder(builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: _collapsedLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              if (overflows)
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                      alignment: Alignment.centerLeft),
                  iconAlignment: IconAlignment.end,
                  icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: Dim.iconSm),
                  label: Text(_expanded ? 'Show less' : 'Read more'),
                ),
            ],
          );
        }),
      ],
    );
  }
}

enum ChapterRowState { normal, finished, current }

/// A compact chapter row (52-64px): number, title, duration. A finished
/// chapter shows a check; the current one a pale accent background, its own
/// mini bar and the time left.
class ChapterListRow extends StatelessWidget {
  /// Zero-based position in the book.
  final int index;
  final String title;
  final int durationSeconds;
  final ChapterRowState state;

  /// Seconds listened in the current chapter ([ChapterRowState.current]).
  final int positionSeconds;
  final bool wide;

  /// Disabled rows (demo previews) cannot be tapped and say why.
  final String? disabledNote;
  final VoidCallback? onTap;

  const ChapterListRow({
    super.key,
    required this.index,
    required this.title,
    required this.durationSeconds,
    this.state = ChapterRowState.normal,
    this.positionSeconds = 0,
    this.wide = false,
    this.disabledNote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = state == ChapterRowState.current;
    final finished = state == ChapterRowState.finished;
    final shown = prettifyChapterTitle(title, index: index);
    final known = durationSeconds > 0;
    final dur =
        known ? formatTimecode(Duration(seconds: durationSeconds)) : null;

    final Color fg =
        current ? c.accentText : (finished ? c.textSecondary : c.text);

    Widget leading;
    if (current) {
      leading = Icon(Icons.equalizer_rounded,
          size: Dim.iconSm, color: c.accentText, semanticLabel: 'Now playing');
    } else if (finished) {
      leading = Icon(Icons.check_rounded,
          size: Dim.iconSm, color: c.success, semanticLabel: 'Finished');
    } else {
      leading = Text('${index + 1}',
          style: AppType.tabularCaption(c.textMuted)
              .copyWith(fontWeight: FontWeight.w600));
    }

    String? trailing;
    if (current) {
      final remaining = known
          ? formatTimecode(Duration(
              seconds: (durationSeconds - positionSeconds)
                  .clamp(0, durationSeconds)))
          : null;
      trailing = remaining == null
          ? null
          : (wide
              ? '${formatTimecode(Duration(seconds: positionSeconds))} / $dur'
              : '$remaining left');
    } else {
      trailing = dur;
    }

    final miniBar = current && known
        ? Padding(
            padding: const EdgeInsets.only(top: Sp.x2 - 2),
            child: ClipRRect(
              borderRadius: R.pill,
              child: LinearProgressIndicator(
                value: (positionSeconds / durationSeconds).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: c.accentFill.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(c.accentFill),
              ),
            ),
          )
        : null;

    final minHeight = current ? (wide ? 64.0 : 60.0) : (wide ? 56.0 : 52.0);

    return Semantics(
      button: onTap != null,
      selected: current,
      child: Material(
        color: current ? c.accentWash : Colors.transparent,
        borderRadius: R.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: R.md,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: wide ? Sp.x3 : Sp.x2, vertical: Sp.x2),
              child: Row(
                children: [
                  SizedBox(width: Sp.x6, child: Center(child: leading)),
                  SizedBox(width: wide ? Sp.x4 : Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shown,
                          style: AppType.body.copyWith(
                              color: onTap == null && disabledNote != null
                                  ? c.textDisabled
                                  : fg,
                              fontWeight: current ? FontWeight.w600 : null),
                        ),
                        if (disabledNote != null)
                          Text(disabledNote!,
                              style: AppType.caption
                                  .copyWith(color: c.textDisabled)),
                        if (miniBar != null) miniBar,
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: Sp.x3),
                    Text(
                      trailing,
                      style: AppType.tabularCaption(
                              current ? c.accentText : c.textMuted)
                          .copyWith(
                              fontWeight: current ? FontWeight.w600 : null),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Chapters" heading with a "3 - 1 h 45 m" count line.
class ChaptersHeader extends StatelessWidget {
  final int count;
  final int totalSeconds;

  const ChaptersHeader(
      {super.key, required this.count, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final runtime = formatRuntime(totalSeconds);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: Sp.x2),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: Sp.x3,
        children: [
          Text('Chapters', style: AppType.titleSm.copyWith(color: c.text)),
          Text(runtime == null ? '$count' : '$count · $runtime',
              style: AppType.tabularCaption(c.textMuted)),
        ],
      ),
    );
  }
}

/// The about text and credit line for a LibriVox-style description:
/// the summary paragraphs, and "Summary by X" for the footnote.
class ParsedAbout {
  final String? text;
  final String? credit;
  final String? readBy;
  final String? formats;

  const ParsedAbout({this.text, this.credit, this.readBy, this.formats});

  factory ParsedAbout.from(String description) {
    final parsed = parseLibriVoxDescription(description);
    final text = parsed.summary.join('\n\n').trim();
    return ParsedAbout(
      text: text.isEmpty ? null : text,
      credit:
          parsed.summaryBy == null ? null : 'Summary by ${parsed.summaryBy}',
      readBy: parsed.readBy,
      formats: parsed.formats,
    );
  }
}

/// The folder holding a book's local files, or null for streamed books.
String? bookFolderPath(UnifiedAudiobook book) {
  for (final ch in book.chapters) {
    final path = ch.audioPathOrUrl;
    if (ch.isStream || path.isEmpty || path.contains('://')) continue;
    return p.dirname(path);
  }
  return null;
}

/// "Show in Finder" / "Show folder" - desktop only; null elsewhere.
String? showFolderLabelForPlatform() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return 'Show in Finder';
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return 'Show folder';
    default:
      return null;
  }
}

/// Opens [folder] in the platform file manager.
Future<void> openFolder(String folder) async {
  try {
    await launchUrl(Uri.directory(folder,
        windows: defaultTargetPlatform == TargetPlatform.windows));
  } catch (e) {
    debugPrint('openFolder: $e');
  }
}

import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import '../core/utils/book_identity.dart';
import '../core/utils/book_progress.dart';
import '../core/utils/duration_format.dart';
import '../domain/models/audiobook.dart';
import '../database/app_database.dart';
import '../services/audio_playback_service.dart';
import '../services/book_removal.dart';
import '../services/hidden_books_store.dart';
import '../theme/app_theme.dart';
import 'app_book_cover.dart';
import 'book_detail_pane.dart' show EmptyChaptersNote;
import 'book_detail_parts.dart';
import 'hide_book_action.dart';

/// The Library-screen counterpart of Discover's `BookDetailPane`: the same
/// family of layout (see `book_detail_parts.dart`) - one primary action,
/// progress first, secondary actions behind the "..." menu, chapters as a
/// compact list - for a [UnifiedAudiobook] already in the local library.
///
/// `BookDetailPane` is built around `LibriVoxBook` (network cover art, ZIP
/// download, demo gating); none of that applies here, so the two stay
/// separate widgets that share parts rather than one widget with optional
/// fields for both.
class LibraryBookDetailOverlay extends StatefulWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;

  /// When set, the overlay offers "Remove from library" and reads the saved
  /// progress.
  final AppDatabase? db;

  /// Called after the book has been removed (the library list should reload).
  final VoidCallback? onRemoved;

  /// Overrides the documents directory the removal plan/removal use (tests).
  final String? documentsPath;

  /// Called after "Mark as finished" or "Reset progress" changed the saved
  /// progress, so the list behind the overlay can refresh.
  final VoidCallback? onProgressChanged;

  /// Two-column dialog layout (wide screens) instead of the phone sheet
  /// with a sticky footer. Supplied by the caller, which knows the screen
  /// width; this widget's own constraints are capped by the dialog.
  final bool wide;

  /// Where "Hide from library" records the hidden id (per device).
  final HiddenBooksStore hiddenStore;

  const LibraryBookDetailOverlay({
    super.key,
    required this.book,
    required this.audioService,
    this.db,
    this.onRemoved,
    this.documentsPath,
    this.onProgressChanged,
    this.wide = false,
    this.hiddenStore = const HiddenBooksStore(),
  });

  @override
  State<LibraryBookDetailOverlay> createState() =>
      _LibraryBookDetailOverlayState();
}

class _LibraryBookDetailOverlayState extends State<LibraryBookDetailOverlay> {
  BookProgress? _progress;

  UnifiedAudiobook get book => widget.book;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final db = widget.db;
    if (db == null) return;
    BookProgress? progress;
    try {
      final saved = await db.getProgress(book.id);
      progress = BookProgress.from(
        book.chapters,
        savedChapterIndex: saved?.chapterIndex,
        savedPositionSeconds: saved?.positionSeconds,
      );
    } catch (_) {}
    if (mounted) setState(() => _progress = progress);
  }

  Future<void> _remove(BuildContext context) async {
    final database = widget.db;
    if (database == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final plan =
        await planBookRemoval(book, documentsPath: widget.documentsPath);
    if (!context.mounted) return;
    final ok =
        await showRemoveBookDialog(context, title: book.title, plan: plan);
    if (!ok) return;
    // Stop first, and before any rows go: a playing book would otherwise
    // write its progress straight back.
    await widget.audioService.stopIfCurrent(book.id);
    final freed =
        await removeBook(database, book, documentsPath: widget.documentsPath);
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(freed > 0
          ? 'Removed "${book.title}" - freed ${formatBytes(freed)}'
          : 'Removed "${book.title}" from your library'),
    ));
    widget.onRemoved?.call();
  }

  Future<void> _hide(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    await hideBookWithUndo(messenger, widget.hiddenStore, book.id);
  }

  Future<void> _markFinished(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.audioService.markFinished(book);
    widget.onProgressChanged?.call();
    await _loadProgress();
    messenger.showSnackBar(
      SnackBar(content: Text('Marked "${book.title}" as finished')),
    );
  }

  Future<void> _resetProgress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: Text('"${book.title}" will start from the beginning next '
            'time. The book and your bookmarks stay.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.audioService.resetProgress(book);
    widget.onProgressChanged?.call();
    await _loadProgress();
    messenger.showSnackBar(
      SnackBar(content: Text('Reset progress for "${book.title}"')),
    );
  }

  void _play() {
    // The only thing in the overlay that starts playback from the saved
    // position; `loadBook` restores it (a finished book starts over).
    widget.audioService.loadBook(book);
    Navigator.of(context).pop();
  }

  List<BookMeta> _meta(ParsedAbout about, {required bool wide}) {
    final narrator =
        book.narrators.isNotEmpty ? book.narrators.join(', ') : about.readBy;
    final total =
        book.chapters.fold<int>(0, (sum, c) => sum + c.durationSeconds);
    final runtime = formatRuntime(total);
    final chapters = book.chapters.length;
    String? format = about.formats;
    if (format == null) {
      for (final ch in book.chapters) {
        if (ch.isStream || ch.audioPathOrUrl.contains('://')) continue;
        final ext = p.extension(ch.audioPathOrUrl).replaceFirst('.', '');
        if (ext.isNotEmpty) format = ext.toUpperCase();
        break;
      }
    }
    final folder = bookFolderPath(book);
    final folderLabel = showFolderLabelForPlatform();
    final librivox = book.origin == BookIdentity.originLibrivox;
    return [
      if (narrator != null && narrator.isNotEmpty)
        BookMeta(
            icon: Icons.headphones_rounded, label: 'Read by', value: narrator),
      if (runtime != null || (wide && chapters > 0))
        BookMeta(
          icon: Icons.schedule_rounded,
          label: 'Length',
          value: wide
              ? [
                  if (runtime != null) runtime,
                  if (chapters > 0)
                    '$chapters ${chapters == 1 ? 'chapter' : 'chapters'}',
                ].join(' · ')
              : runtime!,
        ),
      if (format != null)
        BookMeta(
            icon: Icons.insert_drive_file_outlined,
            label: 'File',
            value: format),
      if (book.isDownloaded)
        BookMeta(
          icon: Icons.check_rounded,
          label: 'Source',
          value: wide && librivox ? 'LibriVox, downloaded' : 'Downloaded',
          positive: true,
        )
      else if (wide && librivox)
        const BookMeta(
            icon: Icons.public_rounded, label: 'Source', value: 'LibriVox'),
      if (wide && folder != null)
        BookMeta(
          icon: Icons.folder_outlined,
          label: 'Folder',
          value: folder,
          actionLabel: folderLabel,
          onAction: folderLabel == null ? null : () => openFolder(folder),
        ),
    ];
  }

  Widget _menu(BuildContext context) {
    final folder = bookFolderPath(book);
    final folderLabel = showFolderLabelForPlatform();
    return BookActionsMenu(
      onMarkFinished: () => _markFinished(context),
      onReset: () => _resetProgress(context),
      onShowFolder: folder != null && folderLabel != null
          ? () => openFolder(folder)
          : null,
      showFolderLabel: folderLabel ?? 'Show folder',
      onHide: () => _hide(context),
      onRemove: widget.db == null ? null : () => _remove(context),
    );
  }

  Widget _chapters() {
    final progress = _progress;
    final total =
        book.chapters.fold<int>(0, (sum, c) => sum + c.durationSeconds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChaptersHeader(count: book.chapters.length, totalSeconds: total),
        const SizedBox(height: Sp.x1),
        if (book.chapters.isEmpty) const EmptyChaptersNote(),
        for (var i = 0; i < book.chapters.length; i++)
          ChapterListRow(
            index: i,
            title: book.chapters[i].title,
            durationSeconds: book.chapters[i].durationSeconds,
            wide: widget.wide,
            state: progress == null
                ? ChapterRowState.normal
                : (progress.finished || i < progress.chapterIndex)
                    ? ChapterRowState.finished
                    : i == progress.chapterIndex
                        ? ChapterRowState.current
                        : ChapterRowState.normal,
            positionSeconds: progress?.positionSeconds ?? 0,
            onTap: () {
              widget.audioService.loadBook(book, initialChapterIndex: i);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  Widget _titleBlock(BuildContext context, {required bool wide}) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: AppType.serif(wide ? AppType.titleLg : AppType.titleMd)
              .copyWith(color: c.text, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: Sp.x1),
        Text(
          book.author,
          style: (wide ? AppType.bodyLg : AppType.body)
              .copyWith(color: c.accentText, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = _progress;
    final about = ParsedAbout.from(book.description);
    final credit = [
      if (about.credit != null) about.credit!,
      if (book.origin == BookIdentity.originLibrivox)
        'Public-domain recording from LibriVox',
    ].join(' · ');
    final creditText = credit.isEmpty
        ? null
        : Text(credit, style: AppType.caption.copyWith(color: c.textMuted));
    final primary = DetailPrimaryButton(
      icon: Icons.play_arrow_rounded,
      label: primaryActionLabel(progress),
      onPressed: _play,
    );

    if (widget.wide) {
      return ClipRRect(
        borderRadius: R.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(right: BorderSide(color: c.border)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Sp.x6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppBookCover(
                      bookId: book.id,
                      title: book.title,
                      coverUrl: book.coverArtUrlOrPath,
                      width: 252,
                      height: 252,
                    ),
                    const SizedBox(height: Sp.x5),
                    if (progress != null) ...[
                      BookProgressSummary(progress: progress, stacked: true),
                      const SizedBox(height: Sp.x5),
                    ],
                    primary,
                    const SizedBox(height: Sp.x5),
                    BookMetaList(items: _meta(about, wide: true)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Sp.x8, Sp.x6, Sp.x4, Sp.x4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _titleBlock(context, wide: true)),
                        const SizedBox(width: Sp.x2),
                        _menu(context),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding:
                          const EdgeInsets.fromLTRB(Sp.x8, 0, Sp.x8, Sp.x6),
                      children: [
                        if (about.text != null) ...[
                          ExpandableAbout(text: about.text!),
                          const SizedBox(height: Sp.x6),
                        ],
                        _chapters(),
                        if (creditText != null) ...[
                          const SizedBox(height: Sp.x5),
                          creditText,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x5),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBookCover(
                    bookId: book.id,
                    title: book.title,
                    coverUrl: book.coverArtUrlOrPath,
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(width: Sp.x4),
                  Expanded(child: _titleBlock(context, wide: false)),
                  _menu(context),
                ],
              ),
              const SizedBox(height: Sp.x5),
              if (progress != null) ...[
                BookProgressSummary(progress: progress),
                const SizedBox(height: Sp.x5),
              ],
              BookMetaRow(items: _meta(about, wide: false)),
              if (about.text != null) ...[
                const SizedBox(height: Sp.x5),
                ExpandableAbout(text: about.text!),
              ],
              const SizedBox(height: Sp.x5),
              _chapters(),
              if (creditText != null) ...[
                const SizedBox(height: Sp.x5),
                creditText,
              ],
            ],
          ),
        ),
        DetailStickyFooter(child: primary),
      ],
    );
  }
}

/// Human-readable size, e.g. `12 MB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[i]}';
}

/// Confirmation for "Remove from library". Says plainly what happens to
/// files: a library-folder book's files are never touched; app-owned
/// downloads/copies are deleted (with their size). Returns true on confirm.
Future<bool> showRemoveBookDialog(
  BuildContext context, {
  required String title,
  required BookRemovalPlan plan,
}) async {
  final String body;
  if (plan.filesUntouched) {
    body = 'Files in your library folder are not touched. The book is '
        'removed from Diegema, along with its progress and bookmarks, and '
        'will not be added again when the folder is rescanned.';
  } else if (plan.deletePaths.isNotEmpty) {
    body = 'Downloaded files are deleted (${formatBytes(plan.bytes)}). '
        'Your progress and bookmarks for this book are deleted too.';
  } else {
    body = 'The book, its progress and bookmarks are removed. '
        'No files are stored on this device for it.';
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Remove "$title"?'),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove')),
      ],
    ),
  );
  return result ?? false;
}

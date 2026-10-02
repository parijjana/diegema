import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../services/local_library_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/app_book_cover.dart';
import '../widgets/app_state_view.dart';
import '../widgets/library_book_detail_overlay.dart';
import '../widgets/local_audiobook_importer.dart';

/// Screen 2 — **Library**: books the user owns, whether downloaded through
/// the in-app store or added manually.
///
/// This chunk of the redesign restyles the screen onto the token system and
/// gives it real empty/loading/error states; the pinned-row header and
/// user-supplied cover art land with the rest of Screen 2's spec.

/// The downloads-folder scan this screen runs before listing books.
/// Injectable so tests drive a stub (or a temp-directory scan) instead of
/// the real `path_provider`-backed walk.
typedef LibraryScanner = Future<void> Function(AppDatabase db);

class LibraryScreen extends StatefulWidget {
  final AppDatabase db;
  final AudioPlaybackService audioService;
  final VoidCallback onGoToDiscover;

  /// Defaults to the platform [scanDownloadedLibrary].
  final LibraryScanner? scanLibrary;

  const LibraryScreen({
    super.key,
    required this.db,
    required this.audioService,
    required this.onGoToDiscover,
    this.scanLibrary,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<UnifiedAudiobook> _books = [];

  /// Books with saved progress, most-recent first — the same rule
  /// `AppDatabase.getContinueListening` applies for Now Playing's idle
  /// shortlist (30-second floor, "effectively finished" excluded). This
  /// list intentionally overlaps `_books`: a book in progress belongs in
  /// both sections, since "in progress" is meant to be found here even
  /// once the player has replaced Now Playing's idle state.
  List<UnifiedAudiobook> _inProgress = [];

  /// Fraction complete (0.0-1.0) per in-progress book id, keyed off
  /// [PlaybackProgress] (`chapterIndex` + `positionSeconds`) against the
  /// sum of chapter durations. `null` means the total runtime is unknown
  /// (unprobed local chapters all reporting `durationSeconds == 0`) — the
  /// same case `getContinueListening` treats permissively rather than
  /// dividing by zero.
  final Map<String, double?> _progressById = {};

  bool _loading = true;
  Object? _error;

  /// The root [Navigator] the detail overlay was pushed on, captured at
  /// open time so it can be closed from [dispose] even though `_index`
  /// switching in `AppShell` swaps this screen out of the tree rather than
  /// pushing/popping a route for it — without this, the overlay (shown on
  /// the app's one shared root Navigator, same as the tab switch itself)
  /// would keep floating over whichever tab the user switched to.
  NavigatorState? _openOverlayNavigator;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _openOverlayNavigator?.maybePop();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await (widget.scanLibrary ?? scanDownloadedLibrary)(widget.db);
      final books = await widget.db.getAllAudiobooks();
      final inProgress = await widget.db.getContinueListening();
      final progressById = <String, double?>{};
      for (final book in inProgress) {
        progressById[book.id] = await _fractionComplete(book);
      }
      if (!mounted) return;
      setState(() {
        _books = books;
        _inProgress = inProgress;
        _progressById
          ..clear()
          ..addAll(progressById);
        _loading = false;
      });
    } catch (e) {
      debugPrint('LibraryScreen: scan failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// `PlaybackProgress.positionSeconds` is a position *within
  /// `chapterIndex`*, not an absolute offset into the book, so the
  /// fraction is the sum of every prior chapter's duration plus the
  /// current position, over the sum of all chapter durations. Returns
  /// `null` when the total is `0` (nothing probed yet) rather than
  /// dividing by zero.
  Future<double?> _fractionComplete(UnifiedAudiobook book) async {
    final progress = await widget.db.getProgress(book.id);
    if (progress == null) return null;

    final totalSeconds =
        book.chapters.fold<int>(0, (sum, ch) => sum + ch.durationSeconds);
    if (totalSeconds <= 0) return null;

    var elapsedSeconds = progress.positionSeconds;
    for (var i = 0;
        i < progress.chapterIndex && i < book.chapters.length;
        i++) {
      elapsedSeconds += book.chapters[i].durationSeconds;
    }
    return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  void _import() =>
      LocalAudiobookImporter.showOptionsModal(context, widget.db, _load);

  /// Tapping a row used to call `audioService.loadBook(...)` directly,
  /// which meant looking at a book in your own library interrupted
  /// whatever was already playing. It now opens a detail overlay instead —
  /// same sheet-on-phone / dialog-on-wide treatment Discover uses for the
  /// same "selection reveals detail, at every width" pattern — and playing
  /// moves to an explicit action inside it.
  void _openDetail(BuildContext context, UnifiedAudiobook book,
      {required bool wide}) {
    final navigator = Navigator.of(context, rootNavigator: true);
    _openOverlayNavigator = navigator;
    final Future<void> shown;
    if (wide) {
      shown = showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: const RoundedRectangleBorder(borderRadius: R.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: Dim.detailDialogMaxWidth, maxHeight: 680),
            child: LibraryBookDetailOverlay(
              book: book,
              audioService: widget.audioService,
              db: widget.db,
              onRemoved: _load,
              onProgressChanged: _load,
              wide: true,
            ),
          ),
        ),
      );
    } else {
      shown = showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.92,
          // The overlay pads itself: its sticky footer runs edge to edge.
          child: LibraryBookDetailOverlay(
            book: book,
            audioService: widget.audioService,
            db: widget.db,
            onRemoved: _load,
            onProgressChanged: _load,
          ),
        ),
      );
    }
    shown.whenComplete(() {
      if (identical(_openOverlayNavigator, navigator)) {
        _openOverlayNavigator = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Dim.wideBreakpoint;
        final gutter = wide ? Sp.gutterDesktop : Sp.gutterPhone;

        final Widget body;
        if (_loading) {
          body = const AppLoadingView(label: 'Reading your library');
        } else if (_error != null) {
          body = AppStateView.error(
            headline: 'Could not read your library',
            body: 'Scanning the downloads folder failed. Nothing was lost.',
            action: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          );
        } else if (_books.isEmpty) {
          body = AppStateView.empty(
            icon: Icons.collections_bookmark_rounded,
            headline: 'Your library is empty',
            body: 'Import audiobooks you already have, or download something '
                'free from Discover.',
            action: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: _pairedButton,
                    onPressed: _import,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Import a book'),
                  ),
                  const SizedBox(height: Sp.x3),
                  OutlinedButton.icon(
                    style: _pairedButton,
                    onPressed: widget.onGoToDiscover,
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('Browse Discover'),
                  ),
                ],
              ),
            ),
          );
        } else {
          // "In progress" is omitted entirely when nothing qualifies — no
          // empty-state placeholder for it — so the plain all-books list
          // is exactly what this screen showed before this section
          // existed. A book that is in progress deliberately appears in
          // both sections; see `_inProgress`'s doc comment.
          final rows = <Widget>[
            if (_inProgress.isNotEmpty) ...[
              const _SectionHeader(title: 'In progress'),
              const SizedBox(height: Sp.x3),
              ..._inProgress.map(
                (book) => Padding(
                  padding: const EdgeInsets.only(bottom: Sp.listGap),
                  child: _InProgressRow(
                    book: book,
                    progress: _progressById[book.id],
                    compact: !wide,
                    onTap: () => _openDetail(context, book, wide: wide),
                  ),
                ),
              ),
              const SizedBox(height: Sp.sectionGap),
              const _SectionHeader(title: 'All books'),
              const SizedBox(height: Sp.x3),
            ],
            ..._books.map(
              (book) => Padding(
                padding: const EdgeInsets.only(bottom: Sp.listGap),
                child: _BookRow(
                  book: book,
                  inProgress: _inProgress.any((b) => b.id == book.id),
                  progress: _progressById[book.id],
                  onTap: () => _openDetail(context, book, wide: wide),
                ),
              ),
            ),
          ];

          if (wide) {
            body = ListView(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Sp.x10),
              children: rows,
            );
          } else {
            // Phone: pull-to-refresh replaces the header's refresh icon
            // (removed below), and a `SliverFillRemaining` after the rows
            // gives a short list a quiet prompt to fill the rest of the
            // screen instead of trailing off into blank space — it costs
            // nothing when the list is already tall enough to fill the
            // viewport, since remaining space is then zero. The extra
            // bottom padding keeps the floating Import button clear of
            // the last row.
            body = RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        gutter, 0, gutter, _LibraryFab.reservedHeight),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        ...rows,
                        // Directly under the last card (not pinned to the
                        // bottom of the viewport), so a short list doesn't
                        // leave a gap before the prompt.
                        _RoomForMorePrompt(
                          onBrowseDiscover: widget.onGoToDiscover,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, Sp.x5, gutter, Sp.x4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _books.isEmpty
                                ? 'Library'
                                : 'Library (${_books.length} '
                                    '${_books.length == 1 ? 'book' : 'books'})',
                            style: AppType.serif(AppType.titleLg)
                                .copyWith(color: c.text),
                          ),
                        ),
                      ),
                      // Wide only: on phone, Import moves to the floating
                      // button below (in the thumb zone, above the mini
                      // player) and Refresh becomes pull-to-refresh on the
                      // list itself.
                      if (wide) ...[
                        Semantics(
                          button: true,
                          label: 'Import a book',
                          excludeSemantics: true,
                          child: IconButton(
                            tooltip: 'Import a book',
                            onPressed: _import,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Refresh library',
                          excludeSemantics: true,
                          child: IconButton(
                            tooltip: 'Refresh library',
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
            if (!wide)
              Positioned(
                right: gutter,
                bottom: Sp.x4,
                child: _LibraryFab(onPressed: _import),
              ),
          ],
        );
      },
    );
  }
}

/// Gives paired actions the same height and corner radius, so a filled and
/// an outlined button carry equal weight.
const ButtonStyle _pairedButton = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, Dim.tapComfy)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: R.md),
  ),
);

/// Phone-only floating "Import a book" button, replacing the header icon.
/// Sits above the mini player without any explicit coordination with it:
/// `AppShell` renders the mini player as a sibling *below* this screen's
/// own `Expanded` slot, so a `Positioned` bottom-anchored inside this
/// screen already lands directly above it.
class _LibraryFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _LibraryFab({required this.onPressed});

  /// Vertical space the list must reserve at its end so the last row is
  /// never covered: the button's own height plus the margin on each side
  /// of it.
  static const double reservedHeight = _height + Sp.x4 + Sp.x4;
  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Import a book',
      excludeSemantics: true,
      child: Material(
        // The fill is in the Ink below, over its shadow (see the cards).
        type: MaterialType.transparency,
        // Same radius as the cards it floats over.
        borderRadius: R.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: R.md,
          child: Ink(
            height: _height,
            padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x5, 0),
            decoration: BoxDecoration(
              color: c.accentFill,
              borderRadius: R.md,
              boxShadow: c.shadow2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: c.textOnAccent),
                const SizedBox(width: Sp.x2),
                Text('Import a book',
                    style: AppType.label.copyWith(color: c.textOnAccent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet nudge that follows the last card of the book list, reusing the same callback the empty state's own
/// "Browse Discover" button calls.
class _RoomForMorePrompt extends StatelessWidget {
  final VoidCallback onBrowseDiscover;
  const _RoomForMorePrompt({required this.onBrowseDiscover});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x6, vertical: Sp.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Room for more. Find a free classic, or import one you already '
            'have.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Sp.x2),
          Semantics(
            button: true,
            label: 'Browse Discover',
            excludeSemantics: true,
            child: OutlinedButton.icon(
              style: _pairedButton,
              onPressed: onBrowseDiscover,
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Browse Discover'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading, matching Now Playing's idle-state `_SectionHeader`
/// (sentence case at `titleSm`, not the old build's letter-spaced
/// all-caps). Library can't reuse that class — it's private to
/// `now_playing_screen.dart` — so this is a deliberate small duplicate
/// rather than a shared export, to avoid coupling two screens that are
/// otherwise independent.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      header: true,
      child: Text(title, style: AppType.titleSm.copyWith(color: c.text)),
    );
  }
}

/// Accent-coloured progress bar shared by both list sections, so the same
/// book reads identically wherever it appears.
class _AccentProgressBar extends StatelessWidget {
  final double value;
  const _AccentProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: R.pill,
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: c.border,
        valueColor: AlwaysStoppedAnimation(c.accentFill),
      ),
    );
  }
}

/// One "In progress" row. Visually consistent with `_BookRow` (same
/// cover size, same card chrome) plus a progress bar/percentage in place
/// of the chapter-count caption, and — like every row on this screen —
/// tapping opens the detail overlay rather than resuming playback
/// directly; see `_openDetail`'s doc comment.
class _InProgressRow extends StatelessWidget {
  final UnifiedAudiobook book;

  /// 0.0-1.0, or `null` when the book's total runtime isn't known yet
  /// (see `_LibraryScreenState._fractionComplete`).
  final double? progress;
  final VoidCallback onTap;

  /// Phone gets a tighter card (per the approved mockup: a 64x64 cover
  /// rather than the 56x56 one wide keeps).
  final bool compact;

  const _InProgressRow({
    required this.book,
    required this.progress,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final percentLabel =
        progress == null ? null : '${(progress! * 100).round()}%';

    return Material(
      // Transparent: the fill lives in the Ink below, painted over its own
      // shadow. A fill here with the shadow on a transparent box inside
      // (as before) let the shadow darken the whole card.
      type: MaterialType.transparency,
      borderRadius: R.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.md,
        child: Semantics(
          button: true,
          label: percentLabel == null
              ? 'View details for ${book.title}'
              : 'View details for ${book.title}, $percentLabel complete',
          excludeSemantics: true,
          child: Ink(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: R.md,
              border: Border.all(color: c.border),
              boxShadow: c.shadow1,
            ),
            padding: const EdgeInsets.all(Sp.x3),
            child: Row(
              children: [
                AppBookCover(
                  bookId: book.id,
                  title: book.title,
                  coverUrl: book.coverArtUrlOrPath,
                  width: compact ? 64 : 56,
                  height: compact ? 64 : 56,
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyLg.copyWith(
                            color: c.text, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: Sp.x1),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: Sp.x2),
                      if (percentLabel != null) ...[
                        _AccentProgressBar(value: progress!),
                        const SizedBox(height: Sp.x1),
                        Text(
                          '$percentLabel listened',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: c.textMuted),
                        ),
                      ] else
                        Text(
                          'In progress',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: c.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.x2),
                Icon(Icons.chevron_right_rounded,
                    size: Dim.iconXl, color: c.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final UnifiedAudiobook book;

  /// Opens the detail overlay. Tapping a library book used to play it
  /// immediately (via a now-removed `onPlay`), interrupting whatever was
  /// already playing; the row itself no longer starts playback at all —
  /// that lives inside the overlay as an explicit action.
  final VoidCallback onTap;

  /// True when the book is also listed under "In progress"; the row then
  /// shows its progress so the two entries read as the same book.
  final bool inProgress;
  final double? progress;

  const _BookRow({
    required this.book,
    required this.onTap,
    this.inProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chapters = book.chapters.length;

    return Material(
      // Transparent: the fill lives in the Ink below, painted over its own
      // shadow. A fill here with the shadow on a transparent box inside
      // (as before) let the shadow darken the whole card.
      type: MaterialType.transparency,
      borderRadius: R.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.md,
        child: Semantics(
          button: true,
          label: inProgress && progress != null
              ? 'View details for ${book.title}, ${(progress! * 100).round()}% complete'
              : 'View details for ${book.title}',
          excludeSemantics: true,
          child: Ink(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: R.md,
              border: Border.all(color: c.border),
              boxShadow: c.shadow1,
            ),
            padding: const EdgeInsets.all(Sp.x3),
            child: Row(
              children: [
                AppBookCover(
                  bookId: book.id,
                  title: book.title,
                  coverUrl: book.coverArtUrlOrPath,
                  width: 56,
                  height: 56,
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyLg.copyWith(
                            color: c.text, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: Sp.x1),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: Sp.x1),
                      if (inProgress && progress != null) ...[
                        _AccentProgressBar(value: progress!),
                        const SizedBox(height: Sp.x1),
                        Text(
                          'In progress · ${(progress! * 100).round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: c.accentText),
                        ),
                      ] else if (inProgress)
                        Text(
                          'In progress',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: c.accentText),
                        )
                      else
                        Text(
                          chapters == 0
                              ? (book.source ?? 'Local')
                              : '$chapters ${chapters == 1 ? 'chapter' : 'chapters'} '
                                  '· ${book.source ?? 'Local'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: c.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.x2),
                Icon(Icons.chevron_right_rounded,
                    size: Dim.iconXl, color: c.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

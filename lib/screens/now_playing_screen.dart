import 'package:flutter/material.dart';

import '../core/ui_preferences.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_book_cover.dart';
import '../widgets/app_state_view.dart';
import '../widgets/player_scrubber.dart';
import '../widgets/player_transport.dart';
import '../widgets/up_next_sheet.dart';

/// Screen 1 — **Now Playing**, the app's default landing screen.
///
/// One screen, two states, no competing panels. This is the main answer to
/// "too high context":
///
/// - **Idle**: a short continue-listening shortlist plus the pinned row.
/// - **Active**: the list fades away to reveal the player.
///
/// ## The fade
///
/// A single [AnimationController] (`0` = list, `1` = player) drives both
/// halves, as a **fade-through**: the outgoing layer leaves over roughly
/// the first third of the timeline and the incoming layer starts as it
/// finishes, overlapping by about one frame. See [_outgoingEnd].
///
/// This is the second attempt. The first staggered the halves but left
/// them overlapping by 20%, on the theory that one layer would always
/// dominate. The golden frames in
/// `test/screens/now_playing_fade_golden_test.dart` showed that it did
/// not: at the midpoint both layers sat around 30% opacity on top of each
/// other, with the player's scrubber and transport interleaved with the
/// list's rows and two copies of the book title a few pixels apart. It
/// read as a double exposure — exactly the failure the stagger was meant
/// to prevent. Sequencing them removes it.
///
/// The motion on top of the opacity is deliberately small: the list drifts
/// 12px up as it leaves, the player settles in from 0.97 scale. Both are
/// tied to their own layer's progress, so the transition is symmetric —
/// whichever layer is leaving always gets the short first window,
/// regardless of direction.
///
/// Everything collapses to a single frame when the platform asks for
/// reduced motion; see [_syncFade].
///
/// The idle layer is also kept mounted but [IgnorePointer]-ed and
/// [ExcludeSemantics]-ed once faded out, so a screen reader never
/// encounters an invisible list, and scroll position survives a round trip.
///
/// ## The queue
///
/// The player opens "Up next" (see `lib/widgets/up_next_sheet.dart`) as a
/// surface *over* itself, rather than navigating away. This replaced an
/// earlier "peek", which flipped the screen back to the continue-listening
/// list while audio kept running: that made this screen the only route to
/// that list, and produced a body reading "Nothing in progress" while a book
/// played and was named directly below it. Continue-listening now lives in
/// Library's "In progress" section, so the player no longer has to double as
/// a way back to it.
class NowPlayingScreen extends StatefulWidget {
  final AppDatabase db;
  final AudioPlaybackService audioService;
  final UiPreferences preferences;

  /// Sends the user to Discover — the only sensible action when they own
  /// nothing yet.
  final VoidCallback onGoToDiscover;

  /// Rendered in the screen heading on narrow layouts, where there is no
  /// side rail to hold it. Supplied by the shell.
  final Widget? headerAction;

  const NowPlayingScreen({
    super.key,
    required this.db,
    required this.audioService,
    required this.onGoToDiscover,
    this.headerAction,
    this.preferences = const UiPreferences(),
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;

  List<UnifiedAudiobook> _continueListening = [];
  List<UnifiedAudiobook> _pinned = [];
  Set<String> _pinnedIds = {};
  bool _pinnedRowVisible = true;
  bool _loading = true;
  Object? _loadError;

  bool get _playerShouldShow =>
      widget.audioService.currentBookNotifier.value != null;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: _playerShouldShow ? 1 : 0,
    );
    widget.audioService.currentBookNotifier.addListener(_onCurrentBookChanged);
    _load();
  }

  @override
  void dispose() {
    widget.audioService.currentBookNotifier
        .removeListener(_onCurrentBookChanged);
    _fade.dispose();
    super.dispose();
  }

  void _onCurrentBookChanged() {
    _syncFade();
    // The shortlist changes as soon as something is played.
    _load();
  }

  /// The two windows of the timeline, as fractions of the controller.
  ///
  /// They overlap by ~4% — about one frame at 60Hz. Butting them exactly
  /// together (both at 0.3) was tried first, and the golden at the
  /// handover came out as a completely empty screen: one frame of bare
  /// background with no list and no player, which reads as a blink rather
  /// than a transition. A single overlapping frame removes it, and is far
  /// too short and too faint (roughly 15% and 8% opacity at its midpoint)
  /// to bring back the double-exposure the first attempt suffered from.
  static const double _outgoingEnd = 0.32;
  static const double _incomingStart = 0.28;

  /// Which layer is currently leaving. Only meaningful mid-flight: at
  /// either end both directions produce the same opacities, so a stale
  /// value cannot show a wrong frame.
  bool _reversing = false;

  void _syncFade() {
    if (!mounted) return;
    final target = _playerShouldShow ? 1.0 : 0.0;
    _reversing = target == 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _fade.value = target;
    } else if (target == 1.0) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loadError = null);
    try {
      final continueListening = await widget.db.getContinueListening(limit: 5);
      final pinned = await widget.db.getPinnedBooks();
      final visible = await widget.preferences.getPinnedRowVisible();
      if (!mounted) return;
      setState(() {
        _continueListening = continueListening;
        _pinned = pinned;
        _pinnedIds = pinned.map((b) => b.id).toSet();
        _pinnedRowVisible = visible;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _togglePinnedRow() async {
    final next = !_pinnedRowVisible;
    setState(() => _pinnedRowVisible = next);
    await widget.preferences.setPinnedRowVisible(next);
  }

  /// Hides a book from the continue-listening surface only. The book and
  /// its progress row are untouched — the undo below simply clears the
  /// flag again.
  Future<void> _hide(UnifiedAudiobook book) async {
    setState(() =>
        _continueListening = _continueListening.where((b) => b.id != book.id).toList());
    await widget.db.hideFromContinue(book.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Hid "${book.title}" from Continue listening'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await widget.db.unhideFromContinue(book.id);
            await _load();
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _togglePin(UnifiedAudiobook book) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_pinnedIds.contains(book.id)) {
      await widget.db.unpinBook(book.id);
      await _load();
      return;
    }
    try {
      await widget.db.pinBook(book.id);
      await _load();
    } on PinLimitExceededException catch (e) {
      // Surfaced, never swallowed: pinning a 6th book is refused and the
      // user is told why and what to do about it.
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You can pin up to ${e.limit} books. Unpin one to make room.',
          ),
        ),
      );
    }
  }

  Future<void> _play(UnifiedAudiobook book) async {
    await widget.audioService.loadBook(book);
  }

  /// Opens the queue for the book that is playing. Nothing about the
  /// player's own state changes — this is a surface over it, not a
  /// destination away from it, which is what the old peek got wrong.
  void _showUpNext() {
    final book = widget.audioService.currentBookNotifier.value;
    if (book == null) return;
    showUpNext(
      context,
      book: book,
      audioService: widget.audioService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.audioService.currentBookNotifier;

    return ValueListenableBuilder<UnifiedAudiobook?>(
      valueListenable: playing,
      builder: (context, book, _) {
        return AnimatedBuilder(
          animation: _fade,
          builder: (context, __) {
            final t = _fade.value;

            // Fade-through, not cross-fade — see the class doc comment.
            // `progress` is how far the *current* gesture has run, so the
            // leaving layer always gets the short first window whichever
            // way the screen is going.
            final progress = _reversing ? 1 - t : t;
            final leaving =
                (progress / _outgoingEnd).clamp(0.0, 1.0).toDouble();
            final arriving = ((progress - _incomingStart) /
                    (1 - _incomingStart))
                .clamp(0.0, 1.0)
                .toDouble();

            // How visible each layer is, 0-1, before its curve.
            final listVis = _reversing ? arriving : 1 - leaving;
            final playerVis = _reversing ? 1 - leaving : arriving;

            final listOpacity = _reversing
                ? Motion.decel.transform(listVis)
                : 1 - Motion.accel.transform(1 - listVis);
            final playerOpacity = _reversing
                ? 1 - Motion.accel.transform(1 - playerVis)
                : Motion.decel.transform(playerVis);

            final listGone = t >= 1.0;
            final playerGone = t <= 0.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (!listGone)
                  IgnorePointer(
                    ignoring: listVis < 0.5,
                    child: ExcludeSemantics(
                      excluding: listVis < 0.5,
                      child: Opacity(
                        opacity: listOpacity,
                        child: Transform.translate(
                          offset: Offset(0, -12 * (1 - listVis)),
                          child: _IdleView(
                            loading: _loading,
                            error: _loadError,
                            continueListening: _continueListening,
                            pinned: _pinned,
                            pinnedIds: _pinnedIds,
                            pinnedRowVisible: _pinnedRowVisible,
                            onTogglePinnedRow: _togglePinnedRow,
                            onPlay: _play,
                            onHide: _hide,
                            onTogglePin: _togglePin,
                            onGoToDiscover: widget.onGoToDiscover,
                            onRetry: _load,
                            headerAction: widget.headerAction,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!playerGone && book != null)
                  IgnorePointer(
                    ignoring: playerVis < 0.5,
                    child: ExcludeSemantics(
                      excluding: playerVis < 0.5,
                      child: Opacity(
                        opacity: playerOpacity,
                        child: Transform.scale(
                          scale: 0.97 + 0.03 * playerVis,
                          child: _ActiveView(
                            book: book,
                            audioService: widget.audioService,
                            onShowUpNext: _showUpNext,
                            headerAction: widget.headerAction,
                          ),
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Idle state
// ---------------------------------------------------------------------------

class _IdleView extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<UnifiedAudiobook> continueListening;
  final List<UnifiedAudiobook> pinned;
  final Set<String> pinnedIds;
  final bool pinnedRowVisible;
  final VoidCallback onTogglePinnedRow;
  final ValueChanged<UnifiedAudiobook> onPlay;
  final ValueChanged<UnifiedAudiobook> onHide;
  final ValueChanged<UnifiedAudiobook> onTogglePin;
  final VoidCallback onGoToDiscover;
  final VoidCallback onRetry;
  final Widget? headerAction;

  const _IdleView({
    required this.loading,
    required this.error,
    required this.continueListening,
    required this.pinned,
    required this.pinnedIds,
    required this.pinnedRowVisible,
    required this.onTogglePinnedRow,
    required this.onPlay,
    required this.onHide,
    required this.onTogglePin,
    required this.onGoToDiscover,
    required this.onRetry,
    required this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Dim.wideBreakpoint;
        final gutter = wide ? Sp.gutterDesktop : Sp.gutterPhone;

        // A pinned book that is also in progress must appear ONCE. It
        // stays in Continue listening — the actionable surface — carrying a
        // pin indicator, and is dropped from the pinned row rather than
        // being rendered twice.
        final inProgressIds = continueListening.map((b) => b.id).toSet();
        final pinnedOnly =
            pinned.where((b) => !inProgressIds.contains(b.id)).toList();

        final Widget body;
        if (loading) {
          body = const AppLoadingView(label: 'Loading your books');
        } else if (error != null) {
          body = AppStateView.error(
            headline: 'Could not load your books',
            body: 'Something went wrong reading the library. '
                'Your books and progress are safe.',
            action: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          );
        } else if (continueListening.isEmpty && pinnedOnly.isEmpty) {
          // This layer is now only ever reached with no book loaded (the
          // player replaces it entirely otherwise), so "Nothing in progress"
          // can no longer contradict a book playing underneath it.
          body = AppStateView.empty(
            icon: Icons.auto_stories_rounded,
            headline: 'Nothing in progress',
            body: 'Books you start appear here so you can pick up where '
                'you left off. Find something to listen to in Discover.',
            action: FilledButton.icon(
              onPressed: onGoToDiscover,
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Browse Discover'),
            ),
          );
        } else {
          body = ListView(
            padding: EdgeInsets.fromLTRB(gutter, Sp.x2, gutter, Sp.x10),
            children: [
              if (pinned.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Pinned',
                  trailing: _PinnedRowToggle(
                    visible: pinnedRowVisible,
                    count: pinned.length,
                    onPressed: onTogglePinnedRow,
                  ),
                ),
                if (pinnedRowVisible)
                  _PinnedRow(books: pinnedOnly, onPlay: onPlay)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x4),
                    child: Text(
                      pinnedOnly.isEmpty
                          ? '${pinned.length} pinned, all in progress below'
                          : '${pinned.length} pinned books hidden',
                      style: AppType.body.copyWith(color: c.textSecondary),
                    ),
                  ),
                const SizedBox(height: Sp.x4),
              ],
              _SectionHeader(
                title: 'Continue listening',
                trailing: continueListening.isEmpty
                    ? null
                    : Text('${continueListening.length}',
                        style: AppType.tabularBody(c.textSecondary)),
              ),
              if (continueListening.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.x6),
                  child: Text(
                    'Nothing in progress yet.',
                    style: AppType.bodyLg.copyWith(color: c.textSecondary),
                  ),
                )
              else
                ...continueListening.map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: Sp.listGap),
                    child: _ContinueListeningItem(
                      book: book,
                      isPinned: pinnedIds.contains(book.id),
                      onPlay: () => onPlay(book),
                      onHide: () => onHide(book),
                      onTogglePin: () => onTogglePin(book),
                    ),
                  ),
                ),
            ],
          );
        }

        return Column(
          children: [
            _ScreenTitleBar(
              title: 'Now playing',
              subtitle: 'Pick up where you left off',
              action: wide ? null : headerAction,
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _ScreenTitleBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const _ScreenTitleBar({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x5, Sp.x4, Sp.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style:
                        AppType.serif(AppType.titleLg).copyWith(color: c.text),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Sp.x1),
                  Text(subtitle!,
                      style: AppType.bodyLg.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              // Sentence case at title-sm. The old build rendered this slot
              // as `TITLE`.toUpperCase() at 11px with letterSpacing 1.5.
              child: Text(title,
                  style: AppType.titleSm.copyWith(color: c.text)),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _PinnedRowToggle extends StatelessWidget {
  final bool visible;
  final int count;
  final VoidCallback onPressed;
  const _PinnedRowToggle({
    required this.visible,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = visible ? 'Hide pinned books' : 'Show $count pinned books';
    return Semantics(
      key: const ValueKey('pinned-row-toggle'),
      button: true,
      label: label,
      toggled: visible,
      excludeSemantics: true,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(visible
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined),
        label: Text(visible ? 'Hide' : 'Show'),
      ),
    );
  }
}

/// Horizontal row of pinned books (at most five — the DB refuses a sixth).
class _PinnedRow extends StatelessWidget {
  final List<UnifiedAudiobook> books;
  final ValueChanged<UnifiedAudiobook> onPlay;
  const _PinnedRow({required this.books, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (books.isEmpty) return const SizedBox.shrink();

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    const coverHeight = 148.0;
    // Two `body` lines at 24px line-height, plus the gap above them and the
    // list's own vertical padding. Derived rather than a fixed number so
    // 200% OS text does not clip — the first cut used a flat 148+48 and
    // overflowed by 16px the moment a title wrapped to two lines.
    final rowHeight = coverHeight + Sp.x2 + (24 * 2) * textScale + Sp.x2;

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: Sp.x1),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: Sp.x3),
        itemBuilder: (context, i) {
          final book = books[i];
          return Semantics(
            button: true,
            label: 'Play ${book.title}, pinned',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onPlay(book),
              borderRadius: R.md,
              child: SizedBox(
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AppBookCover(
                          bookId: book.id,
                          title: book.title,
                          coverUrl: book.coverArtUrlOrPath,
                          width: 112,
                          height: coverHeight,
                        ),
                        Positioned(
                          top: Sp.x1,
                          right: Sp.x1,
                          child: Container(
                            padding: const EdgeInsets.all(Sp.x1),
                            decoration: BoxDecoration(
                              color: c.accentFill,
                              borderRadius: R.xs,
                            ),
                            child: Icon(Icons.push_pin_rounded,
                                size: 14, color: c.textOnAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.x2),
                    Expanded(
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                            color: c.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One continue-listening row. Dismissible in either direction; dismissing
/// calls `hideFromContinue`, which touches neither the book nor its
/// progress row, and the snackbar offers an undo.
class _ContinueListeningItem extends StatelessWidget {
  final UnifiedAudiobook book;
  final bool isPinned;
  final VoidCallback onPlay;
  final VoidCallback onHide;
  final VoidCallback onTogglePin;

  const _ContinueListeningItem({
    required this.book,
    required this.isPinned,
    required this.onPlay,
    required this.onHide,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Dismissible(
      key: ValueKey('continue-${book.id}'),
      background: const _DismissBackground(alignment: Alignment.centerLeft),
      secondaryBackground:
          const _DismissBackground(alignment: Alignment.centerRight),
      onDismissed: (_) => onHide(),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: R.md,
          border: Border.all(color: c.border),
          boxShadow: c.shadow1,
        ),
        padding: const EdgeInsets.all(Sp.x3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppBookCover(
              bookId: book.id,
              title: book.title,
              coverUrl: book.coverArtUrlOrPath,
              width: 56,
              height: 74,
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isPinned) ...[
                        Semantics(
                          label: 'Pinned',
                          child: Icon(Icons.push_pin_rounded,
                              size: 16, color: c.accentText),
                        ),
                        const SizedBox(width: Sp.x1),
                      ],
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyLg.copyWith(
                              color: c.text, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.x2),
            Semantics(
              key: ValueKey('pin-toggle-${book.id}'),
              button: true,
              label: isPinned ? 'Unpin ${book.title}' : 'Pin ${book.title}',
              toggled: isPinned,
              excludeSemantics: true,
              child: IconButton(
                tooltip: isPinned ? 'Unpin' : 'Pin',
                onPressed: onTogglePin,
                icon: Icon(
                  isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: isPinned ? c.accentText : c.textSecondary,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Resume ${book.title}',
              excludeSemantics: true,
              child: IconButton(
                tooltip: 'Resume',
                onPressed: onPlay,
                icon: Icon(Icons.play_circle_fill_rounded,
                    size: Dim.iconXl, color: c.accentFill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  final Alignment alignment;
  const _DismissBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: R.md),
      padding: const EdgeInsets.symmetric(horizontal: Sp.x5),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_outlined, color: c.textSecondary),
          const SizedBox(width: Sp.x2),
          Text('Hide', style: AppType.label.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}
class _ActiveView extends StatelessWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  final VoidCallback onShowUpNext;

  /// The theme toggle, shown here only at narrow widths.
  ///
  /// Wide layouts carry their own copy in the top tab bar, but narrow ones
  /// have a bottom `NavigationBar` with nowhere to put it — so when the
  /// player replaced the idle view, the toggle vanished from the phone
  /// layout entirely for as long as a book was loaded. The idle view's
  /// title bar is the only other place it lives.
  final Widget? headerAction;

  const _ActiveView({
    required this.book,
    required this.audioService,
    required this.onShowUpNext,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Dim.wideBreakpoint;
        final gutter = wide ? Sp.gutterDesktop : Sp.gutterPhone;
        // Cover is sized from the *smaller* of the two axes so it can never
        // push the transport off a short window. Phone gets a bigger clamp
        // (up from 220 to 300, at 0.36 of the height rather than 0.30) —
        // the cover is the hero of the phone layout now that the scrubber
        // and transport have moved to the bottom of the screen instead of
        // sitting right underneath it.
        final coverSize = (constraints.maxHeight * (wide ? 0.30 : 0.36))
            .clamp(120.0, wide ? 280.0 : 300.0)
            .toDouble();

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppBookCover(
                bookId: book.id,
                title: book.title,
                coverUrl: book.coverArtUrlOrPath,
                width: coverSize * 0.76,
                height: coverSize,
              ),
              const SizedBox(height: Sp.x5),
              Text(
                book.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(AppType.titleMd).copyWith(color: c.text),
              ),
              const SizedBox(height: Sp.x1),
              ValueListenableBuilder<int>(
                valueListenable: audioService.chapterIndexNotifier,
                builder: (context, index, _) {
                  final chapterLabel = index < book.chapters.length &&
                          book.chapters.isNotEmpty
                      ? '${book.author} · ${book.chapters[index].title} of '
                          '${book.chapters.length}'
                      : book.author;
                  return Text(
                    chapterLabel,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: c.textSecondary),
                  );
                },
              ),
            ],
          ),
        );

        final footer = Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Sp.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerScrubber(audioService: audioService),
              const SizedBox(height: Sp.x5),
              PlayerTransport(audioService: audioService, book: book),
              const SizedBox(height: Sp.x5),
              wide
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      spacing: Sp.x3,
                      runSpacing: Sp.x3,
                      children: [
                        SpeedSelector(audioService: audioService),
                        SleepTimerSelector(audioService: audioService),
                      ],
                    )
                  : _ActionTileRow(
                      audioService: audioService,
                      onShowUpNext: onShowUpNext,
                    ),
            ],
          ),
        );

        return Container(
          color: c.bg,
          child: Column(
            children: [
              // Slim top-right row. It hosts only the playback-error
              // indicator and (on phone) the theme toggle passed down as
              // `headerAction` — neither of which touches playback — and
              // takes no space at all when both are absent. The "Up next"
              // row that used to live here on phone has moved into the
              // action tile row at the bottom, in the thumb zone.
              ValueListenableBuilder<PlaybackState>(
                valueListenable: audioService.stateNotifier,
                builder: (context, state, _) {
                  final showError = state == PlaybackState.error;
                  final showHeaderAction = !wide && headerAction != null;
                  if (!showError && !showHeaderAction) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (showError) ...[
                          Icon(Icons.error_outline_rounded,
                              color: c.danger),
                          const SizedBox(width: Sp.x2),
                          Text('Playback failed',
                              style: AppType.label.copyWith(color: c.danger)),
                        ],
                        if (showError && showHeaderAction)
                          const SizedBox(width: Sp.x3),
                        if (showHeaderAction) headerAction!,
                      ],
                    ),
                  );
                },
              ),
              if (wide)
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [header, const SizedBox(height: Sp.x5), footer],
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Phone: cover/title/chapter pinned at the top, scrubber
                // and transport pushed to the BOTTOM of the available
                // space (the thumb zone).
                //
                // `Expanded(SingleChildScrollView(header)) + footer` rather
                // than the more obvious `ConstrainedBox(minHeight) +
                // IntrinsicHeight + Spacer`: that combination was tried
                // first, but a `Spacer`'s intrinsic height contribution is
                // unbounded, so `IntrinsicHeight` computed an infinite
                // intrinsic size for the column and crashed layout as soon
                // as anything below it (the action-tile row's fixed-height
                // `SizedBox`es) tried to enforce a concrete height against
                // it. Here the footer is a normal, non-scrolling sibling
                // pinned below an `Expanded` scroll area: on a tall screen
                // the header sits at the scroll area's top with blank
                // space below it and the footer directly under that, and
                // on a short one the scroll area simply scrolls — no
                // intrinsic pass involved at all.
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(child: header),
                      ),
                      footer,
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Phone-only action row: three equal-width 48px tiles directly above the
/// bottom nav — Up next, Speed, Sleep. Speed and Sleep reuse
/// [SpeedSelector]/[SleepTimerSelector] (their popup-menu logic is not
/// duplicated here); they are only restyled with a square tile radius and
/// stretched to fill the tile, via the `radius`/`stretch` hooks on
/// `player_transport.dart`'s chip shell.
class _ActionTileRow extends StatelessWidget {
  final AudioPlaybackService audioService;
  final VoidCallback onShowUpNext;
  const _ActionTileRow({
    required this.audioService,
    required this.onShowUpNext,
  });

  @override
  Widget build(BuildContext context) {
    const tileHeight = 48.0;
    // Fixed-width tiles computed from a `LayoutBuilder`, not `Expanded`:
    // this row sits under `AnimatedBuilder`/`Opacity`/`Transform.scale`
    // during the idle<->player cross-fade, and a `PopupMenuButton` (which
    // both `SpeedSelector` and `SleepTimerSelector` are, under the hood)
    // runs an internal dry-layout pass to size its overlay that gave an
    // `Expanded` ancestor here unbounded height and crashed. Three
    // explicit-width `SizedBox`es sidestep flex layout entirely.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - Sp.x2 * 2) / 3;
        return Row(
          children: [
            SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: _UpNextTile(onPressed: onShowUpNext),
            ),
            const SizedBox(width: Sp.x2),
            SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: SpeedSelector(audioService: audioService, tile: true),
            ),
            const SizedBox(width: Sp.x2),
            SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: SleepTimerSelector(audioService: audioService, tile: true),
            ),
          ],
        );
      },
    );
  }
}

class _UpNextTile extends StatelessWidget {
  final VoidCallback onPressed;
  const _UpNextTile({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Up next. The chapters in this book.',
      excludeSemantics: true,
      child: Material(
        color: c.accentWash,
        borderRadius: R.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: R.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_music_rounded, size: Dim.iconSm, color: c.accentText),
              const SizedBox(width: Sp.x2),
              Flexible(
                child: Text('Up next',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: c.accentText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

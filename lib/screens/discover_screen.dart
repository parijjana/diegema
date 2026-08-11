import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../domain/models/librivox_book.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/audio_playback_service.dart';
import '../services/librivox_downloader.dart';
import '../services/librivox_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_view.dart';
import '../widgets/book_detail_pane.dart';
import '../widgets/librivox_book_item.dart';
import '../widgets/librivox_shelf_view.dart';

/// Screen 3 — **Discover**: the LibriVox storefront.
///
/// Search placement follows the decision in `ui_redesign_plan.md`: **bottom
/// centre on phone widths** (thumb reach) and **top on wide layouts**,
/// where a floating bottom-centre field would be merely odd. The breakpoint
/// is read from the screen's own constraints, not `MediaQuery.size`.
///
/// This chunk restyles Discover onto the token system and gives it the
/// missing loading/empty/error states; the fuller categorisation pass lands
/// with the rest of Screen 3's spec.
class DiscoverScreen extends StatefulWidget {
  final AppDatabase db;
  final AudioPlaybackService audioService;
  final LibriVoxService libriVoxService;
  final ArtworkEnrichmentService artworkService;
  final LibriVoxStreamAndDownloader downloader;

  /// Rendered in the screen heading on narrow layouts, where there is no
  /// side rail to hold it. Supplied by the shell.
  final Widget? headerAction;

  /// Demo-only: a book to select (and, on phone widths, open the detail
  /// sheet for) as soon as the shelves land. `'1'` means "the first
  /// featured book". See `core/demo_deeplink.dart` for why this exists.
  final String? openBookId;

  const DiscoverScreen({
    super.key,
    required this.db,
    required this.audioService,
    required this.libriVoxService,
    required this.artworkService,
    required this.downloader,
    this.headerAction,
    this.openBookId,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// Vertical space kept clear at the bottom of every scrollable on phone
  /// widths, so the floating search field never permanently covers the
  /// last shelf heading or an empty state's button. The field is ~52px
  /// tall and sits [Sp.x4] off the bottom; the rest is breathing room.
  ///
  /// It floats *over* content by design (thumb reach beats a fixed bar),
  /// but "floats over" has to mean "you can scroll past it", not "the
  /// bottom of the page is unreachable" — which is what a 360x800 capture
  /// showed: the "Top fiction" heading sat permanently behind the field.
  static const double _floatingSearchReserve = 96;

  static const List<({String name, String query})> _categories = [
    (name: 'Featured', query: ''),
    (name: 'Fiction', query: 'fiction'),
    (name: 'Poetry', query: 'poetry'),
    (name: 'Drama', query: 'drama'),
    (name: 'History', query: 'history'),
    (name: 'Science fiction', query: 'science fiction'),
    (name: 'Biography', query: 'biography'),
    (name: 'Children', query: 'children'),
  ];

  final TextEditingController _search = TextEditingController();

  Map<String, List<LibriVoxBook>> _shelves = {};
  List<LibriVoxBook> _results = [];
  LibriVoxBook? _selected;
  bool _loading = true;
  bool _searching = false;
  Object? _error;

  /// Set while a deep-linked book still has to be opened; cleared the
  /// first time the sheet is shown so it cannot reopen on every rebuild.
  bool _pendingOpen = false;

  @override
  void initState() {
    super.initState();
    _pendingOpen = widget.openBookId != null;
    _loadShelves();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadShelves() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = <String, List<LibriVoxBook>>{};
      final featured = await widget.libriVoxService.searchBooks('', limit: 12);
      results[''] = featured;

      final entries = await Future.wait(
        _categories.skip(1).map((cat) async {
          final books =
              await widget.libriVoxService.searchBooks(cat.query, limit: 10);
          return MapEntry(cat.query, books);
        }),
      );
      for (final e in entries) {
        results[e.key] = e.value;
      }

      if (!mounted) return;
      setState(() {
        _shelves = results;
        final requested = widget.openBookId;
        if (requested != null && featured.isNotEmpty) {
          _selected = featured.firstWhere(
            (b) => b.id == requested,
            orElse: () => featured.first,
          );
        }
        _selected ??= featured.isNotEmpty ? featured.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    setState(() {
      _loading = true;
      _searching = true;
      _error = null;
    });
    try {
      final results =
          await widget.libriVoxService.searchBooks(term, limit: 20);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isNotEmpty) _selected = results.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _clearSearch() {
    _search.clear();
    setState(() {
      _searching = false;
      _results = [];
    });
  }

  void _select(BuildContext context, LibriVoxBook book, {required bool wide}) {
    setState(() => _selected = book);
    if (!wide) _openDetailSheet(context, book);
  }

  void _openDetailSheet(BuildContext context, LibriVoxBook book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x4),
          child: BookDetailPane(
            book: book,
            artworkService: widget.artworkService,
            downloader: widget.downloader,
            audioService: widget.audioService,
            db: widget.db,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Dim.wideBreakpoint;
        final bottomInset = wide ? Sp.x10 : _floatingSearchReserve;

        // A deep-linked book is already visible in the detail pane on wide
        // layouts; on phone widths the book view is a modal sheet, so it
        // has to be pushed once the shelves exist.
        if (_pendingOpen && !_loading && !wide && _selected != null) {
          final book = _selected!;
          _pendingOpen = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetailSheet(context, book);
          });
        }

        // True when the branch below already reserves the space inside its
        // own scrollable; the centred states do not, so the column adds it.
        var childReservesInset = false;

        final Widget browse;
        if (_loading) {
          browse = const AppLoadingView(label: 'Loading the LibriVox catalog');
        } else if (_error != null) {
          browse = AppStateView.error(
            headline: 'Could not reach LibriVox',
            body: 'Check your connection and try again.',
            action: FilledButton.icon(
              onPressed: _searching
                  ? () => _performSearch(_search.text)
                  : _loadShelves,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          );
        } else if (_searching) {
          childReservesInset = _results.isNotEmpty;
          browse = _results.isEmpty
              ? AppStateView.empty(
                  icon: Icons.search_off_rounded,
                  headline: 'No books found',
                  body: 'Nothing in the LibriVox catalog matched '
                      '"${_search.text.trim()}".',
                  action: OutlinedButton(
                    onPressed: _clearSearch,
                    child: const Text('Clear search'),
                  ),
                )
              : _SearchResults(
                  results: _results,
                  selected: _selected,
                  bottomInset: bottomInset,
                  onSelect: (b) => _select(context, b, wide: wide),
                );
        } else {
          childReservesInset = true;
          browse = ListView(
            padding: EdgeInsets.only(bottom: bottomInset),
            children: [
              for (final cat in _categories)
                LibriVoxShelfView(
                  title: cat.query.isEmpty
                      ? 'Featured classics'
                      : 'Top ${cat.name.toLowerCase()}',
                  books: _shelves[cat.query] ?? const [],
                  selectedBook: _selected,
                  onSelectBook: (b) => _select(context, b, wide: wide),
                ),
            ],
          );
        }

        final header = Padding(
          padding: EdgeInsets.fromLTRB(
              wide ? Sp.gutterDesktop : Sp.gutterPhone,
              Sp.x5,
              wide ? Sp.gutterDesktop : Sp.gutterPhone,
              Sp.x4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Discover',
                      style: AppType.serif(AppType.titleLg)
                          .copyWith(color: c.text)),
                ),
              ),
              // Wide layouts get the search field inline in the header.
              if (wide)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _SearchField(
                    controller: _search,
                    onSubmitted: _performSearch,
                    onClear: _clearSearch,
                    searching: _searching,
                  ),
                )
              else if (widget.headerAction != null)
                widget.headerAction!,
            ],
          ),
        );

        final main = Column(
          children: [
            header,
            // Centred states (loading, empty, error) are laid out inside
            // the same reserved area, so their call-to-action button can
            // never end up underneath the floating field either.
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: childReservesInset ? 0 : bottomInset),
                child: browse,
              ),
            ),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: main),
              VerticalDivider(width: 1, color: c.border),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(Sp.gutterDesktop),
                  child: _selected == null
                      ? const AppStateView.empty(
                          icon: Icons.menu_book_rounded,
                          headline: 'Pick a book',
                          body: 'Choose a title to see its details, chapters '
                              'and listening options.',
                        )
                      : BookDetailPane(
                          book: _selected!,
                          artworkService: widget.artworkService,
                          downloader: widget.downloader,
                          audioService: widget.audioService,
                          db: widget.db,
                        ),
                ),
              ),
            ],
          );
        }

        // Phone: search floats bottom centre, within thumb reach. It sits
        // on a short gradient of the page background rather than directly
        // on the shelves — without it, a shelf heading passing behind the
        // field reads as a clipping bug rather than as content scrolling
        // underneath an overlay.
        return Stack(
          children: [
            Positioned.fill(child: main),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x6, Sp.x4, Sp.x4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: 0), c.bg, c.bg],
                    stops: const [0, 0.55, 1],
                  ),
                ),
                child: _SearchField(
                  controller: _search,
                  onSubmitted: _performSearch,
                  onClear: _clearSearch,
                  searching: _searching,
                  elevated: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final bool searching;
  final bool elevated;

  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
    required this.searching,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: AppType.bodyLg.copyWith(color: c.text),
      decoration: InputDecoration(
        hintText: 'Search LibriVox',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searching
            ? Semantics(
                button: true,
                label: 'Clear search',
                excludeSemantics: true,
                child: IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              )
            : null,
      ),
    );

    return Semantics(
      textField: true,
      label: 'Search the LibriVox catalog',
      child: elevated
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: R.sm,
                boxShadow: c.shadow3,
              ),
              child: field,
            )
          : field,
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<LibriVoxBook> results;
  final LibriVoxBook? selected;
  final ValueChanged<LibriVoxBook> onSelect;

  /// Space kept clear for the floating search field; see
  /// `_DiscoverScreenState._floatingSearchReserve`.
  final double bottomInset;

  const _SearchResults({
    required this.results,
    required this.selected,
    required this.onSelect,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x3),
          child: Semantics(
            header: true,
            child: Text(
              '${results.length} '
              '${results.length == 1 ? 'result' : 'results'}',
              style: AppType.titleSm.copyWith(color: c.text),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, bottomInset),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: LibriVoxBookItem.tileWidth + Sp.x4,
              mainAxisExtent: LibriVoxBookItem.coverHeight +
                  Sp.x2 +
                  (26 * 2 + 18) * textScale,
              crossAxisSpacing: Sp.x3,
              mainAxisSpacing: Sp.x4,
            ),
            itemCount: results.length,
            itemBuilder: (context, i) => LibriVoxBookItem(
              book: results[i],
              isSelected: selected?.id == results[i].id,
              onTap: () => onSelect(results[i]),
            ),
          ),
        ),
      ],
    );
  }
}

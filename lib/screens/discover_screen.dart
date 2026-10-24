import 'dart:async';

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

  /// Library's "On your other devices": open this archive.org book's detail
  /// as soon as it is fetched (where the normal Download button lives). If
  /// the lookup fails, [openFallbackQuery] is searched instead.
  final String? openArchiveId;
  final String? openFallbackQuery;

  const DiscoverScreen({
    super.key,
    required this.db,
    required this.audioService,
    required this.libriVoxService,
    required this.artworkService,
    required this.downloader,
    this.headerAction,
    this.openBookId,
    this.openArchiveId,
    this.openFallbackQuery,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// Breathing room under the last row on phone widths. The search field
  /// has its own strip below the list, so nothing needs reserving for it.
  static const double _floatingSearchReserve = Sp.x4;

  /// Results per search page. A short page means the catalog has run out.
  static const int _searchPageSize = 20;

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

  /// Shelves still in flight, and a counter that lets a retry discard
  /// results from the load it replaced.
  int _shelvesPending = 0;
  int _shelfGeneration = 0;

  /// Browse-mode state, kept apart from [_loading]/[_error] (search mode)
  /// so shelves landing mid-search cannot clear the search spinner.
  bool _shelvesLoading = true;
  Object? _shelvesError;
  List<LibriVoxBook> _results = [];

  /// Paging state for the current search. The next page is only fetched on
  /// an explicit "Load more" tap, never ahead of time: archive.org is a
  /// shared, free service and most searches never need page two.
  String _searchTerm = '';
  int _pagesLoaded = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  /// Bumped by every new search or clear, so a page that was still in
  /// flight for the old one is dropped when it lands.
  int _searchGeneration = 0;
  LibriVoxBook? _selected;
  bool _loading = true;
  bool _searching = false;
  Object? _error;

  /// Set while a deep-linked book still has to be opened; cleared the
  /// first time the sheet is shown so it cannot reopen on every rebuild.
  bool _pendingOpen = false;

  /// A book fetched by archive id (see [DiscoverScreen.openArchiveId]),
  /// opened on the next frame.
  LibriVoxBook? _linkedBook;

  @override
  void initState() {
    super.initState();
    _pendingOpen = widget.openBookId != null;
    _loadShelves();
    final id = widget.openArchiveId;
    if (id != null) _openArchiveBook(id);
  }

  Future<void> _openArchiveBook(String id) async {
    LibriVoxBook? book;
    try {
      book = await widget.libriVoxService.getBookById(id);
    } catch (_) {}
    if (!mounted) return;
    if (book != null) {
      setState(() {
        _selected = book;
        _linkedBook = book;
      });
      return;
    }
    final query = widget.openFallbackQuery;
    if (query != null && query.trim().isNotEmpty) {
      _search.text = query;
      unawaited(_performSearch(query));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadShelves() async {
    final generation = ++_shelfGeneration;
    setState(() {
      _shelves = {};
      _shelvesPending = _categories.length;
      _shelvesLoading = true;
      _shelvesError = null;
    });

    // Every shelf is fetched independently and rendered the moment it
    // lands, so a slow LibriVox feed never holds back the category shelves.
    await Future.wait(_categories.map((cat) async {
      var books = const <LibriVoxBook>[];
      try {
        books = await widget.libriVoxService
            .searchBooks(cat.query, limit: cat.query.isEmpty ? 12 : 10);
      } catch (_) {
        // An individual shelf failing just leaves that shelf out.
      }
      // A retry started a newer load; this result belongs to the old one.
      if (!mounted || generation != _shelfGeneration) return;
      setState(() {
        _shelves[cat.query] = books;
        _shelvesPending--;
        if (books.isNotEmpty) _shelvesLoading = false;
        if (cat.query.isEmpty && books.isNotEmpty) {
          final requested = widget.openBookId;
          _selected ??= requested == null
              ? books.first
              : books.firstWhere((b) => b.id == requested,
                  orElse: () => books.first);
        }
        if (_shelvesPending == 0) {
          _shelvesLoading = false;
          if (_shelves.values.every((b) => b.isEmpty)) {
            _shelvesError = 'No shelves could be loaded';
          }
        }
      });
    }));
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _loading = true;
      _searching = true;
      _error = null;
      _searchTerm = term;
      _pagesLoaded = 0;
      _hasMore = false;
      _loadingMore = false;
      _loadMoreFailed = false;
    });
    try {
      final results = await widget.libriVoxService
          .searchBooks(term, limit: _searchPageSize);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _pagesLoaded = 1;
        _hasMore = results.length >= _searchPageSize;
        _loading = false;
        if (results.isNotEmpty) _selected = results.first;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Fetches the next page of the current search and appends it, skipping
  /// anything already listed (a catalog that shifts between pages can
  /// repeat a book). The service caches each page under its own key.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _searchGeneration;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await widget.libriVoxService.searchBooks(_searchTerm,
          limit: _searchPageSize, offset: _pagesLoaded * _searchPageSize);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        final seen = {for (final b in _results) b.id};
        _results = [..._results, ...page.where((b) => seen.add(b.id))];
        _pagesLoaded++;
        _hasMore = page.length >= _searchPageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  void _clearSearch() {
    _search.clear();
    _searchGeneration++;
    setState(() {
      _searching = false;
      _results = [];
      _hasMore = false;
      _loadingMore = false;
    });
  }

  /// Selecting a book always opens the detail surface now — there is no
  /// persistent wide-layout pane to update in place any more. Both widths
  /// share this one path so there is exactly one "show me this book" flow
  /// to keep working (deep links included).
  void _select(BuildContext context, LibriVoxBook book, {required bool wide}) {
    setState(() => _selected = book);
    _openDetailSurface(context, book, wide: wide);
  }

  /// Phone widths get the existing near-full-height bottom sheet (thumb
  /// reach, familiar app pattern). Wide widths get a centred, width-capped
  /// dialog instead of reusing the sheet at full height — a sheet that
  /// only fills a third of a desktop-width window reads as a mistake, and
  /// a full-bleed one would swamp the rest of the page. Both are dismissed
  /// by tapping outside, matching the sheet's default drag/tap-away.
  void _openDetailSurface(BuildContext context, LibriVoxBook book,
      {required bool wide}) {
    if (wide) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: const RoundedRectangleBorder(borderRadius: R.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: Dim.detailDialogMaxWidth, maxHeight: 680),
            child: BookDetailPane(
              book: book,
              artworkService: widget.artworkService,
              downloader: widget.downloader,
              audioService: widget.audioService,
              db: widget.db,
              libriVoxService: widget.libriVoxService,
              wide: true,
            ),
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        // The pane pads itself: its sticky footer runs edge to edge.
        child: BookDetailPane(
          book: book,
          artworkService: widget.artworkService,
          downloader: widget.downloader,
          audioService: widget.audioService,
          db: widget.db,
          libriVoxService: widget.libriVoxService,
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

        // Both widths now show the book via an on-demand surface (sheet or
        // dialog) rather than a persistent pane, so a deep-linked book has
        // to be pushed open explicitly once the shelves exist, regardless
        // of width.
        if (_pendingOpen && !_shelvesLoading && _selected != null) {
          final book = _selected!;
          _pendingOpen = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetailSurface(context, book, wide: wide);
          });
        }

        final linked = _linkedBook;
        if (linked != null) {
          _linkedBook = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetailSurface(context, linked, wide: wide);
          });
        }

        // True when the branch below already reserves the space inside its
        // own scrollable; the centred states do not, so the column adds it.
        var childReservesInset = false;

        final loading = _searching ? _loading : _shelvesLoading;
        final error = _searching ? _error : _shelvesError;

        final Widget browse;
        if (loading) {
          browse = const AppLoadingView(label: 'Loading the LibriVox catalog');
        } else if (error != null) {
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
                  hasMore: _hasMore,
                  loadingMore: _loadingMore,
                  loadMoreFailed: _loadMoreFailed,
                  onLoadMore: _loadMore,
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
              if (_shelvesPending > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Sp.x6),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
            ],
          );
        }

        final header = Padding(
          padding: EdgeInsets.fromLTRB(wide ? Sp.gutterDesktop : Sp.gutterPhone,
              Sp.x5, wide ? Sp.gutterDesktop : Sp.gutterPhone, Sp.x4),
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

        // Wide used to reserve a permanent side column for BookDetailPane,
        // showing a "choose a title" placeholder when nothing was selected
        // — dead chrome that read like a web console rather than an app
        // (the same complaint that killed the old NavigationRail). The
        // grid/list now gets the full width at every breakpoint, and the
        // detail surface only appears once a book is actually picked, via
        // _select above.
        if (wide) {
          return main;
        }

        // Phone: the search field sits bottom centre, within thumb reach,
        // in its own strip under the list. It used to float over the
        // shelves and the results grid, which left a row of covers under
        // it whenever the list was not scrolled to its end; a strip means
        // no content is ever beneath it, and "Load more" stays reachable
        // above it.
        return Column(
          children: [
            Expanded(child: main),
            Container(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x3),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: _SearchField(
                controller: _search,
                onSubmitted: _performSearch,
                onClear: _clearSearch,
                searching: _searching,
                elevated: true,
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
        hintText: 'Search audiobooks',
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
                // Opaque, so the shadow can't show through the field.
                color: c.surface,
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

  /// More pages may exist: the list ends in a "Load more" button, and the
  /// count reads "20+ results" rather than claiming a total.
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
  final VoidCallback onLoadMore;

  /// Space kept clear for the floating search field; see
  /// `_DiscoverScreenState._floatingSearchReserve`.
  final double bottomInset;

  const _SearchResults({
    required this.results,
    required this.selected,
    required this.onSelect,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreFailed,
    required this.onLoadMore,
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
              '${results.length}${hasMore ? '+' : ''} '
              '${results.length == 1 ? 'result' : 'results'}',
              style: AppType.titleSm.copyWith(color: c.text),
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                sliver: SliverGrid.builder(
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
              SliverPadding(
                padding: EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, bottomInset),
                sliver: SliverToBoxAdapter(
                  child: hasMore
                      ? Center(
                          child: loadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(Sp.x3),
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, Dim.tapMin)),
                                  onPressed: onLoadMore,
                                  icon: Icon(loadMoreFailed
                                      ? Icons.refresh_rounded
                                      : Icons.expand_more_rounded),
                                  label: Text(loadMoreFailed
                                      ? 'Could not load more. Try again'
                                      : 'Load more'),
                                ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

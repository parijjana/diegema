import 'package:flutter/material.dart';
import 'app.dart';
import 'database/app_database.dart';
import 'services/librivox_service.dart';
import 'services/artwork_enrichment_service.dart';
import 'services/librivox_downloader.dart';
import 'domain/models/librivox_book.dart';
import 'domain/models/audiobook.dart';
import 'services/audio_playback_service.dart';
import 'widgets/bookmarks_drawer.dart';
import 'widgets/book_detail_pane.dart';
import 'widgets/persistent_player_bar.dart';
import 'widgets/app_header.dart';
import 'widgets/storefront_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AudiobookApp());
}

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Optional injected LibriVoxService, used by tests to avoid live HTTP
  /// calls during the initial category-shelf load in initState. Defaults
  /// to a real LibriVoxService (which makes real network requests) when
  /// omitted.
  final LibriVoxService? libriVoxService;

  const HomeScreen({
    super.key,
    required this.db,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.libriVoxService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LibriVoxService _libriVoxService;
  late final ArtworkEnrichmentService _artworkService;
  late final LibriVoxStreamAndDownloader _downloader;
  late final AudioPlaybackService _audioService;

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _activeNavTab = 1;
  String? _selectedCategory;
  bool _isSearchExpanded = false;
  bool _isSearching = false;
  bool _isLoading = false;

  Map<String, List<LibriVoxBook>> _categoryResults = {};
  List<LibriVoxBook> _searchResults = [];
  LibriVoxBook? _selectedBook;

  final List<Map<String, String>> _categories = const [
    {'name': 'Featured', 'query': ''},
    {'name': 'Fiction', 'query': 'fiction'},
    {'name': 'Poetry', 'query': 'poetry'},
    {'name': 'Drama', 'query': 'drama'},
    {'name': 'History', 'query': 'history'},
    {'name': 'Sci-Fi', 'query': 'science fiction'},
    {'name': 'Biography', 'query': 'biography'},
    {'name': 'Children', 'query': 'children'},
  ];

  @override
  void initState() {
    super.initState();
    _libriVoxService = widget.libriVoxService ?? LibriVoxService();
    _artworkService = ArtworkEnrichmentService();
    _downloader = LibriVoxStreamAndDownloader();
    _audioService = AudioPlaybackService(db: widget.db);

    _loadCategoryShelves();
  }

  @override
  void dispose() {
    _audioService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryShelves() async {
    setState(() => _isLoading = true);
    final Map<String, List<LibriVoxBook>> results = {};

    try {
      final featured = await _libriVoxService.searchBooks('', limit: 12);
      results[''] = featured;
      if (featured.isNotEmpty) {
        _selectedBook = featured.first;
      }

      final futures = _categories.skip(1).map((cat) async {
        final query = cat['query']!;
        final books = await _libriVoxService.searchBooks(query, limit: 10);
        return MapEntry(query, books);
      });

      final entries = await Future.wait(futures);
      for (final e in entries) {
        results[e.key] = e.value;
      }

      setState(() {
        _categoryResults = results;
      });
    } catch (e) {
      debugPrint('Error loading category shelves: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _activeNavTab = 1;
    });

    try {
      final results = await _libriVoxService.searchBooks(term, limit: 20);
      setState(() {
        _searchResults = results;
        if (_searchResults.isNotEmpty) {
          _selectedBook = _searchResults.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _selectedCategory = null;
      _searchController.clear();
      _isSearchExpanded = false;
    });
  }

  void _selectBook(LibriVoxBook book) {
    setState(() => _selectedBook = book);
    if (MediaQuery.of(context).size.width < 768) {
      _showBookDetailsModal(book);
    }
  }

  void _showBookDetailsModal(LibriVoxBook book) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: BookDetailPane(
          book: book,
          artworkService: _artworkService,
          downloader: _downloader,
          audioService: _audioService,
          db: widget.db,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      endDrawer: ValueListenableBuilder<UnifiedAudiobook?>(
        valueListenable: _audioService.currentBookNotifier,
        builder: (context, book, child) {
          if (book == null) return const SizedBox.shrink();
          return BookmarksDrawer(
            audiobookId: book.id,
            db: widget.db,
            audioService: _audioService,
          );
        },
      ),
      body: SafeArea(
        child: ValueListenableBuilder<UnifiedAudiobook?>(
          valueListenable: _audioService.currentBookNotifier,
          builder: (context, playingBook, child) {
            final double bottomInset = playingBook != null ? 95.0 : 0.0;

            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    children: [
                      AppHeader(
                        activeNavTab: _activeNavTab,
                        onSelectTab: (idx) =>
                            setState(() => _activeNavTab = idx),
                        isSearchExpanded: _isSearchExpanded,
                        onToggleSearch: () {
                          setState(() {
                            _isSearchExpanded = !_isSearchExpanded;
                            if (!_isSearchExpanded) {
                              _clearSearch();
                            }
                          });
                        },
                        searchController: _searchController,
                        onSearchSubmitted: _performSearch,
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                        audioService: _audioService,
                        db: widget.db,
                        onOpenDrawer: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                      const SizedBox(height: 8),
                      if (_activeNavTab == 1) ...[
                        CategorySubBar(
                          categories: _categories,
                          selectedCategory: _selectedCategory,
                          onSelectCategory: (name) {
                            setState(() => _selectedCategory = name);
                            final cat = _categories
                                .firstWhere((c) => c['name'] == name);
                            if (cat['query']!.isNotEmpty) {
                              _performSearch(cat['query']!);
                            } else {
                              setState(() => _isSearching = false);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      Expanded(
                        child: StorefrontBodyLayout(
                          activeNavTab: _activeNavTab,
                          isSearching: _isSearching,
                          isLoading: _isLoading,
                          searchResults: _searchResults,
                          categoryResults: _categoryResults,
                          categories: _categories,
                          selectedBook: _selectedBook,
                          onSelectBook: _selectBook,
                          db: widget.db,
                          audioService: _audioService,
                          artworkService: _artworkService,
                          downloader: _downloader,
                          onGoToDiscover: () =>
                              setState(() => _activeNavTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                if (playingBook != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PersistentPlayerBar(
                        audioService: _audioService, db: widget.db),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

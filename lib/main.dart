import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database/app_database.dart';
import 'services/librivox_service.dart';
import 'services/wikipedia_service.dart';
import 'services/artwork_enrichment_service.dart';
import 'services/librivox_downloader.dart';
import 'domain/models/librivox_book.dart';
import 'domain/models/audiobook.dart';
import 'services/audio_playback_service.dart';
import 'widgets/glass_card.dart';
import 'widgets/librivox_book_item.dart';
import 'widgets/librivox_shelf_view.dart';
import 'widgets/wikipedia_knowledge_dialog.dart';
import 'widgets/bookmarks_drawer.dart';
import 'widgets/now_playing_screen.dart';
import 'widgets/library_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AudiobookApp());
}

class AudiobookApp extends StatefulWidget {
  const AudiobookApp({super.key});

  @override
  State<AudiobookApp> createState() => _AudiobookAppState();
}

class _AudiobookAppState extends State<AudiobookApp> {
  late final AppDatabase _db;
  bool _isDarkMode = false; // Default to official LibriVox Light website theme!

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  ThemeData _buildTheme(bool isDark) {
    if (!isDark) {
      // Official LibriVox Light Website Color Scheme
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F8F5), // LibriVox Warm Cream / Off-White
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2E6D7D),   // Official LibriVox Deep Slate Teal
          secondary: Color(0xFFCC4D22), // Official LibriVox Terracotta Accent
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF222222),  // LibriVox Dark Text
          outline: Color(0xFFE0DED6),    // Warm Card Border
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE0DED6)),
          ),
        ),
      );
    } else {
      // LibriVox Dark Slate Theme
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101417), // LibriVox Dark Slate
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E6D7D),   // Official LibriVox Deep Slate Teal
          secondary: Color(0xFFCC4D22), // Official LibriVox Terracotta Accent
          onPrimary: Colors.white,
          surface: Color(0xFF181C20),
          onSurface: Color(0xFFE6E4DF),
          outline: Color(0xFF2E6D7D),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF181C20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibriVox Audiobook Player',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(_isDarkMode),
      home: HomeScreen(
        db: _db,
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.db,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LibriVoxService _libriVoxService;
  late final WikipediaService _wikipediaService;
  late final ArtworkEnrichmentService _artworkService;
  late final LibriVoxStreamAndDownloader _downloader;
  late final AudioPlaybackService _audioService;

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _activeNavTab = 1; // 0: Library, 1: Discover
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
    _libriVoxService = LibriVoxService();
    _wikipediaService = WikipediaService(db: widget.db);
    _artworkService = ArtworkEnrichmentService(wikipediaService: _wikipediaService);
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
      _activeNavTab = 1; // Switch to discover search
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 768;

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
                      _buildHeader(theme),
                      const SizedBox(height: 8),
                      if (_activeNavTab == 1) ...[
                        _buildCategorySubBar(theme),
                        const SizedBox(height: 8),
                      ],
                      Expanded(
                        child: isWide
                            ? _buildWideMasterDetailLayout(theme)
                            : _buildNarrowLayout(theme),
                      ),
                    ],
                  ),
                ),
                if (playingBook != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PersistentPlayerBar(audioService: _audioService, db: widget.db),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.headphones_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LIBRIVOX',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'free public domain audiobooks',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            _buildNavPill('LIBRARY', 0, _activeNavTab == 0, theme),
            const SizedBox(width: 8),
            _buildNavPill('DISCOVER', 1, _activeNavTab == 1, theme),
            ValueListenableBuilder<UnifiedAudiobook?>(
              valueListenable: _audioService.currentBookNotifier,
              builder: (context, playingBook, child) {
                if (playingBook == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.graphic_eq_rounded, color: theme.colorScheme.primary, size: 16),
                    label: Text(
                      'NOW PLAYING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: 1.0),
                    ),
                    onPressed: () => AulosNowPlayingScreen.openFullPage(context, audioService: _audioService, db: widget.db),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            _buildExpandableSearch(theme),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              tooltip: widget.isDarkMode ? 'Switch to LibriVox Light Mode' : 'Switch to LibriVox Dark Mode',
              onPressed: widget.onToggleTheme,
            ),
            IconButton(
              icon: Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
              tooltip: 'Wikipedia Search',
              onPressed: () {
                WikipediaKnowledgeDialog.show(
                  context,
                  query: _searchController.text.isNotEmpty ? _searchController.text : 'Audiobook',
                  wikipediaService: _wikipediaService,
                );
              },
            ),
            ValueListenableBuilder<UnifiedAudiobook?>(
              valueListenable: _audioService.currentBookNotifier,
              builder: (context, book, child) {
                if (book == null) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(Icons.bookmark_outline_rounded, color: theme.colorScheme.primary, size: 20),
                  tooltip: 'Bookmarks',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPill(String label, int index, bool isActive, ThemeData theme) {
    return InkWell(
      onTap: () => setState(() => _activeNavTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? null : Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSearch(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _isSearchExpanded ? 200 : 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isSearchExpanded ? theme.colorScheme.primary.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _clearSearch();
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                size: 18,
                color: _isSearchExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search audiobooks...',
                  hintStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(right: 12),
                ),
                onSubmitted: _performSearch,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySubBar(ThemeData theme) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['name'];
          return ChoiceChip(
            label: Text(cat['name']!, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
            labelStyle: TextStyle(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
            onSelected: (_) {
              setState(() {
                _selectedCategory = cat['name'];
              });
              if (cat['query']!.isNotEmpty) {
                _performSearch(cat['query']!);
              } else {
                setState(() => _isSearching = false);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildWideMasterDetailLayout(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: GlassCard(
              fullHeight: true,
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(12),
              child: _activeNavTab == 0
                  ? LibraryView(
                      db: widget.db,
                      audioService: _audioService,
                      onGoToDiscover: () => setState(() => _activeNavTab = 1),
                    )
                  : (_isSearching
                      ? _buildSearchResultsGrid(theme)
                      : _buildStorefrontShelves(theme)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: GlassCard(
              fullHeight: true,
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(12),
              child: _selectedBook != null
                  ? BookDetailPane(
                      book: _selectedBook!,
                      wikipediaService: _wikipediaService,
                      artworkService: _artworkService,
                      downloader: _downloader,
                      audioService: _audioService,
                      db: widget.db,
                    )
                  : const Center(
                      child: Text('Select an audiobook to view details', style: TextStyle(color: Colors.grey)),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GlassCard(
        fullHeight: true,
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(12),
        child: _activeNavTab == 0
            ? LibraryView(
                db: widget.db,
                audioService: _audioService,
                onGoToDiscover: () => setState(() => _activeNavTab = 1),
              )
            : (_isSearching
                ? _buildSearchResultsGrid(theme)
                : _buildStorefrontShelves(theme)),
      ),
    );
  }

  Widget _buildStorefrontShelves(ThemeData theme) {
    if (_isLoading && _categoryResults.isEmpty) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        LibriVoxShelfView(
          title: 'Featured Classics',
          books: _categoryResults[''] ?? [],
          selectedBook: _selectedBook,
          onSelectBook: (book) => _selectBook(book),
        ),
        ..._categories.skip(1).map((cat) {
          final query = cat['query']!;
          final books = _categoryResults[query] ?? [];
          return LibriVoxShelfView(
            title: 'Top ${cat['name']} Books',
            books: books,
            selectedBook: _selectedBook,
            onSelectBook: (book) => _selectBook(book),
          );
        }),
      ],
    );
  }

  Widget _buildSearchResultsGrid(ThemeData theme) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('No audiobooks found for this search.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'SEARCH RESULTS (${_searchResults.length})'.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              childAspectRatio: 0.54,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final book = _searchResults[index];
              return LibriVoxBookItem(
                book: book,
                isSelected: _selectedBook?.id == book.id,
                onTap: () => _selectBook(book),
              );
            },
          ),
        ),
      ],
    );
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
          wikipediaService: _wikipediaService,
          artworkService: _artworkService,
          downloader: _downloader,
          audioService: _audioService,
          db: widget.db,
        ),
      ),
    );
  }
}

class BookDetailPane extends StatefulWidget {
  final LibriVoxBook book;
  final WikipediaService wikipediaService;
  final ArtworkEnrichmentService artworkService;
  final LibriVoxStreamAndDownloader downloader;
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const BookDetailPane({
    super.key,
    required this.book,
    required this.wikipediaService,
    required this.artworkService,
    required this.downloader,
    required this.audioService,
    required this.db,
  });

  @override
  State<BookDetailPane> createState() => _BookDetailPaneState();
}

class _BookDetailPaneState extends State<BookDetailPane> {
  WikipediaSummary? _wikiSummary;
  String? _coverArtUrl;
  UnifiedAudiobook? _streamableBook;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _loadEnrichmentData();
  }

  @override
  void didUpdateWidget(covariant BookDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) {
      _loadEnrichmentData();
    }
  }

  Future<void> _loadEnrichmentData() async {
    setState(() => _isLoading = true);
    final wikiFuture = widget.wikipediaService.fetchSummary(widget.book.title);
    final coverFuture = widget.artworkService.resolveCoverArtUrl(
      title: widget.book.title,
      author: widget.book.authorNames,
    );
    final streamFuture = widget.downloader.parseStreamableBook(widget.book);

    final results = await Future.wait([wikiFuture, coverFuture, streamFuture]);

    if (mounted) {
      setState(() {
        _wikiSummary = results[0] as WikipediaSummary?;
        _coverArtUrl = results[1] as String?;
        _streamableBook = results[2] as UnifiedAudiobook?;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadBook() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savePath = p.join(appDir.path, 'unamedaudiobookplayer', 'downloads');

      final extractedFiles = await widget.downloader.downloadAndExtractZip(
        widget.book,
        saveDirectoryPath: savePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      final List<AudiobookChapter> chapters = [];
      for (int i = 0; i < extractedFiles.length; i++) {
        final filePath = extractedFiles[i];
        final filename = p.basename(filePath);
        chapters.add(AudiobookChapter(
          id: '${widget.book.id}_local_$i',
          title: filename.replaceAll('.mp3', ''),
          audioPathOrUrl: filePath,
          durationSeconds: 0,
          isStream: false,
        ));
      }

      final downloadedBook = UnifiedAudiobook(
        id: widget.book.id,
        title: widget.book.title,
        author: widget.book.authorNames,
        description: widget.book.description,
        source: 'Downloaded',
        coverArtUrlOrPath: widget.book.coverArtUrl,
        chapters: chapters,
        isDownloaded: true,
      );

      await widget.db.saveAudiobook(downloadedBook);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${extractedFiles.length} chapters to local storage & saved to Library!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _coverArtUrl != null
                  ? Image.network(
                      _coverArtUrl!,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildCoverFallback(theme),
                    )
                  : _buildCoverFallback(theme),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Author: ${widget.book.authorNames}',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                  if (widget.book.narrators.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Narrated by: ${widget.book.narrators.join(', ')}',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isDownloaded ? Colors.teal : theme.colorScheme.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(_isDownloading ? Icons.downloading : (_isDownloaded ? Icons.check_circle : Icons.download_rounded)),
            label: Text(
              _isDownloading
                  ? 'Downloading (${(_downloadProgress * 100).toStringAsFixed(0)}%)...'
                  : (_isDownloaded ? 'Downloaded to Local Storage' : 'Download Full Audiobook (ZIP)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _isDownloading ? null : _downloadBook,
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          title: 'Description',
          borderRadius: BorderRadius.circular(10),
          child: Text(widget.book.description, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), height: 1.5, fontSize: 13)),
        ),
        const SizedBox(height: 16),
        GlassCard(
          title: 'Wikipedia Insights',
          borderRadius: BorderRadius.circular(10),
          borderColor: theme.colorScheme.primary,
          child: _isLoading
              ? CircularProgressIndicator(color: theme.colorScheme.primary)
              : _wikiSummary != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _wikiSummary!.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(_wikiSummary!.extract, style: TextStyle(height: 1.5, fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.85))),
                      ],
                    )
                  : const Text(
                      'No Wikipedia summary found.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
        ),
        const SizedBox(height: 20),
        Text(
          'Chapters (${_streamableBook?.chapters.length ?? 0})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_streamableBook != null)
          ..._streamableBook!.chapters.asMap().entries.map((entry) {
            final idx = entry.key;
            final ch = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassCard(
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.play_circle_fill, color: theme.colorScheme.primary, size: 26),
                    title: Text(ch.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('${(ch.durationSeconds / 60).toStringAsFixed(1)} mins', style: const TextStyle(fontSize: 10)),
                    onTap: () async {
                      await widget.audioService.loadBook(_streamableBook!, initialChapterIndex: idx);
                    },
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCoverFallback(ThemeData theme) {
    return Container(
      width: 110,
      height: 110,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      child: Icon(Icons.book, size: 48, color: theme.colorScheme.primary),
    );
  }
}

class PersistentPlayerBar extends StatelessWidget {
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const PersistentPlayerBar({super.key, required this.audioService, required this.db});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showAddBookmarkDialog(BuildContext context) {
    final noteController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Bookmark'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Enter note for timestamp...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final note = noteController.text.trim();
              if (note.isNotEmpty) {
                await audioService.addBookmark(note);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark saved!')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<UnifiedAudiobook?>(
      valueListenable: audioService.currentBookNotifier,
      builder: (context, book, child) {
        if (book == null) return const SizedBox.shrink();

        return InkWell(
          onTap: () => AulosNowPlayingScreen.openFullPage(context, audioService: audioService, db: db),
          child: GlassCard(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            borderColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<Duration>(
                  valueListenable: audioService.positionNotifier,
                  builder: (context, position, child) {
                    return ValueListenableBuilder<Duration>(
                      valueListenable: audioService.durationNotifier,
                      builder: (context, duration, child) {
                        final maxVal = duration.inSeconds.toDouble();
                        final currentVal = position.inSeconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: theme.colorScheme.primary,
                                thumbColor: theme.colorScheme.primary,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: currentVal,
                                max: maxVal > 0 ? maxVal : 1.0,
                                onChanged: (val) {
                                  audioService.seek(Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                  Text(_formatDuration(duration), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.bookmark_add_outlined, color: theme.colorScheme.primary),
                      tooltip: 'Add Bookmark',
                      onPressed: () => _showAddBookmarkDialog(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: audioService.chapterIndexNotifier,
                            builder: (context, index, child) {
                              final chapterTitle = (index < book.chapters.length) ? book.chapters[index].title : '';
                              return Text(
                                chapterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10, size: 20),
                            onPressed: () => audioService.skipBackward(seconds: 15),
                          ),
                          ValueListenableBuilder<PlaybackState>(
                            valueListenable: audioService.stateNotifier,
                            builder: (context, state, child) {
                              if (state == PlaybackState.loading) {
                                return SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                                );
                              }
                              final isPlaying = state == PlaybackState.playing;
                              return IconButton(
                                icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 34, color: theme.colorScheme.primary),
                                onPressed: () => audioService.togglePlayPause(),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, size: 20),
                            onPressed: () => audioService.skipForward(seconds: 15),
                          ),
                          PopupMenuButton<double>(
                            icon: Icon(Icons.speed, color: theme.colorScheme.primary),
                            onSelected: (speed) => audioService.setSpeed(speed),
                            itemBuilder: (context) => [0.75, 1.0, 1.25, 1.5, 2.0]
                                .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

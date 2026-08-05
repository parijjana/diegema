import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../services/local_library_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/app_book_cover.dart';
import '../widgets/app_state_view.dart';
import '../widgets/local_audiobook_importer.dart';
import 'app_shell.dart' show ThemeToggleButton;

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
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Defaults to the platform [scanDownloadedLibrary].
  final LibraryScanner? scanLibrary;

  const LibraryScreen({
    super.key,
    required this.db,
    required this.audioService,
    required this.onGoToDiscover,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.scanLibrary,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<UnifiedAudiobook> _books = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await (widget.scanLibrary ?? scanDownloadedLibrary)(widget.db);
      final books = await widget.db.getAllAudiobooks();
      if (!mounted) return;
      setState(() {
        _books = books;
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

  void _import() =>
      LocalAudiobookImporter.showOptionsModal(context, widget.db, _load);

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
            action: Wrap(
              spacing: Sp.x3,
              runSpacing: Sp.x3,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Import a book'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onGoToDiscover,
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text('Browse Discover'),
                ),
              ],
            ),
          );
        } else {
          body = ListView.separated(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Sp.x10),
            itemCount: _books.length,
            separatorBuilder: (_, __) => const SizedBox(height: Sp.listGap),
            itemBuilder: (context, i) => _BookRow(
              book: _books[i],
              onPlay: () => widget.audioService.loadBook(_books[i]),
            ),
          );
        }

        return Column(
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
                  if (!wide)
                    ThemeToggleButton(
                      isDarkMode: widget.isDarkMode,
                      onToggle: widget.onToggleTheme,
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _BookRow extends StatelessWidget {
  final UnifiedAudiobook book;
  final VoidCallback onPlay;

  const _BookRow({required this.book, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chapters = book.chapters.length;

    return Container(
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
            height: 74,
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
                  style: AppType.bodyLg
                      .copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: Sp.x1),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Sp.x1),
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
          Semantics(
            button: true,
            label: 'Play ${book.title}',
            excludeSemantics: true,
            child: IconButton(
              tooltip: 'Play',
              onPressed: onPlay,
              icon: Icon(Icons.play_circle_fill_rounded,
                  size: Dim.iconXl, color: c.accentFill),
            ),
          ),
        ],
      ),
    );
  }
}

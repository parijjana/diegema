import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/demo_mode.dart';
import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/librivox_book.dart';
import '../domain/models/audiobook.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/downloads_location.dart';
import '../services/librivox_downloader.dart';
import '../services/librivox_service.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/duration_format.dart';
import 'app_book_cover.dart';
import 'book_detail_parts.dart';

class BookDetailPane extends StatefulWidget {
  final LibriVoxBook book;
  final ArtworkEnrichmentService artworkService;
  final LibriVoxStreamAndDownloader downloader;
  final AudioPlaybackService audioService;
  final AppDatabase db;

  /// Used only to look up the ZIP's size for the phone sticky footer's
  /// second line (see [LibriVoxService.zipSizeBytes]); optional so a test
  /// that only cares about the rest of this pane does not have to supply
  /// one, in which case the footer simply omits the size line.
  final LibriVoxService? libriVoxService;

  /// Whether the *screen* hosting this pane is at the wide breakpoint —
  /// supplied by the caller rather than measured locally. The wide
  /// dialog variant caps this pane's own width well under
  /// [Dim.wideBreakpoint] (see `discover_screen.dart`'s
  /// `_openDetailSurface`), so a `LayoutBuilder` reading this widget's own
  /// constraints would misread a width-capped dialog on a wide screen as
  /// the phone layout.
  final bool wide;

  /// Where a download is saved (see `downloads_location_io.dart`).
  final DownloadsLocation downloadsLocation;

  const BookDetailPane({
    super.key,
    required this.book,
    required this.artworkService,
    required this.downloader,
    required this.audioService,
    required this.db,
    this.libriVoxService,
    this.wide = false,
    this.downloadsLocation = const DownloadsLocation(),
  });

  @override
  State<BookDetailPane> createState() => _BookDetailPaneState();
}

class _BookDetailPaneState extends State<BookDetailPane> {
  String? _coverArtUrl;
  UnifiedAudiobook? _streamableBook;

  /// The chapter list couldn't be fetched (offline, timeout, feed error).
  bool _chaptersFailed = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _allChapters = false;
  static const int _collapsedChapters = 5;
  bool _isDownloaded = false;

  /// Null while unknown (still loading, or the lookup failed/found
  /// nothing) — the footer just shows the button without a size line in
  /// that case rather than blocking on it.
  int? _zipSizeBytes;

  @override
  void initState() {
    super.initState();
    _loadEnrichmentData();
    _loadZipSize();
  }

  @override
  void didUpdateWidget(covariant BookDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) {
      _loadEnrichmentData();
      _loadZipSize();
    }
  }

  Future<void> _loadEnrichmentData() async {
    final coverFuture = widget.artworkService.resolveCoverArtUrl(widget.book);
    final chaptersFuture = _loadChapters();
    final cover = await coverFuture;
    if (mounted) setState(() => _coverArtUrl = cover);
    await chaptersFuture;
  }

  Future<void> _loadChapters() async {
    if (mounted) setState(() => _chaptersFailed = false);
    // A downloaded copy plays from disk, so it needs no feed at all; show
    // it straight away and let the feed only fill in what it adds.
    final saved = await _savedCopy();
    if (saved != null && mounted) {
      setState(() {
        _isDownloaded = true;
        _streamableBook = saved;
      });
    }
    try {
      final book = await widget.downloader.parseStreamableBook(widget.book);
      if (mounted && saved == null) setState(() => _streamableBook = book);
    } on ChaptersUnavailable catch (e) {
      debugPrint('BookDetailPane: chapters unavailable: $e');
      if (mounted && saved == null) setState(() => _chaptersFailed = true);
    }
  }

  /// The downloaded row for this book, if it has one with chapters.
  Future<UnifiedAudiobook?> _savedCopy() async {
    try {
      final id = BookIdentity.archiveIdentifierFor(
        librivoxApiId: widget.book.id,
        urlIarchive: widget.book.urlIarchive,
      );
      final book = await widget.db.getAudiobook(id);
      return book != null && book.isDownloaded && book.chapters.isNotEmpty
          ? book
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadZipSize() async {
    final service = widget.libriVoxService;
    if (service == null) return;
    setState(() => _zipSizeBytes = null);
    final identifier = BookIdentity.archiveIdentifierFor(
      librivoxApiId: widget.book.id,
      urlIarchive: widget.book.urlIarchive,
    );
    final bytes = await service.zipSizeBytes(identifier);
    if (mounted) setState(() => _zipSizeBytes = bytes);
  }

  Future<void> _downloadBook() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final location = widget.downloadsLocation;
      if (location.needsFolderChoice && await location.chooseFolder() != null) {
        // Downloads made before the folder was chosen join it now.
        await moveDownloadsToVisibleFolder(widget.db, location: location);
      }
      final savePath = await location.current();
      if (savePath == null) {
        throw StateError('No folder to download into');
      }

      final extractedFiles = await widget.downloader.downloadAndExtractZip(
        widget.book,
        saveDirectoryPath: savePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      // Same canonical id as `parseStreamableBook` (both derive from the
      // archive.org identifier) so downloading a book that was already
      // being streamed updates the *same* row instead of creating a
      // second one with separate progress/bookmarks.
      final canonicalId = BookIdentity.archiveIdentifierFor(
        librivoxApiId: widget.book.id,
        urlIarchive: widget.book.urlIarchive,
      );

      // The feed's section titles and durations, when it lists exactly the
      // files the ZIP held (LibriVox numbers both the same way); otherwise
      // the file names.
      final feed = _streamableBook?.chapters;
      final fromFeed = feed != null &&
          !(_streamableBook?.isDownloaded ?? false) &&
          feed.length == extractedFiles.length;
      final List<AudiobookChapter> chapters = [];
      for (int i = 0; i < extractedFiles.length; i++) {
        final filePath = extractedFiles[i];
        final filename = p.basename(filePath);
        chapters.add(
          AudiobookChapter(
            id: '${canonicalId}_local_$i',
            title: fromFeed ? feed[i].title : filename.replaceAll('.mp3', ''),
            audioPathOrUrl: filePath,
            durationSeconds: fromFeed ? feed[i].durationSeconds : 0,
            isStream: false,
          ),
        );
      }

      final downloadedBook = UnifiedAudiobook(
        id: canonicalId,
        title: widget.book.title,
        author: widget.book.authorNames,
        description: widget.book.description,
        source: 'Downloaded',
        origin: BookIdentity.originLibrivox,
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
          SnackBar(
              content: Text(
                  'Downloaded ${extractedFiles.length} chapters to local storage & saved to Library!')),
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

  /// The one primary action: Download · ZIP size, its in-flight and done
  /// states, or a disabled stand-in in the web demo (streaming-only, see
  /// rework_plan.md - shown disabled rather than hidden so offline
  /// listening still reads as a feature that exists).
  Widget _primaryAction() {
    final c = context.colors;
    if (kDemoMode) {
      return Semantics(
        enabled: false,
        label: 'Download full audiobook. '
            'Not available in this browser preview.',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DetailPrimaryButton(
              icon: Icons.download_rounded,
              label: 'Download',
              onPressed: null,
            ),
            const SizedBox(height: Sp.x2),
            Text('Offline listening is in the app, not this preview',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: c.textMuted)),
          ],
        ),
      );
    }
    final size = formatZipSize(_zipSizeBytes);
    final String label;
    final IconData icon;
    if (_isDownloading) {
      label = 'Downloading… ${(_downloadProgress * 100).round()}%';
      icon = Icons.downloading_rounded;
    } else if (_isDownloaded) {
      label = 'Downloaded';
      icon = Icons.check_circle_rounded;
    } else {
      label = size == null ? 'Download' : 'Download · ZIP $size';
      icon = Icons.download_rounded;
    }
    final inactive = _isDownloading || _isDownloaded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DetailPrimaryButton(
          icon: icon,
          label: label,
          onPressed: inactive ? null : _downloadBook,
          keepFilledWhenDisabled: true,
        ),
        if (_isDownloading) ...[
          const SizedBox(height: Sp.x2),
          ClipRRect(
            borderRadius: R.pill,
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 3,
              backgroundColor: c.accent.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(c.accent),
            ),
          ),
        ],
      ],
    );
  }

  List<BookMeta> _meta({required bool wide}) {
    final book = widget.book;
    final runtime = formatRuntime(book.totalTimeSecs);
    final chapters = _streamableBook?.chapters.length ?? 0;
    return [
      if (book.narrators.isNotEmpty)
        BookMeta(
            icon: Icons.headphones_rounded,
            label: 'Read by',
            value: book.narrators.join(', ')),
      if (runtime != null)
        BookMeta(icon: Icons.schedule_rounded, label: 'Length', value: runtime),
      if (chapters > 0)
        BookMeta(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Chapters',
            value: '$chapters ${chapters == 1 ? 'chapter' : 'chapters'}'),
      const BookMeta(
          icon: Icons.public_rounded, label: 'Source', value: 'LibriVox'),
      if (_isDownloaded)
        const BookMeta(
            icon: Icons.check_rounded,
            label: 'Saved',
            value: 'Downloaded',
            positive: true),
    ];
  }

  Widget _titleBlock({required bool wide}) {
    final c = context.colors;
    final book = widget.book;
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
          book.authorNames,
          style: (wide ? AppType.bodyLg : AppType.body)
              .copyWith(color: c.accentText, fontWeight: FontWeight.w500),
        ),
        if (!book.demoPlayable) ...[
          const SizedBox(height: Sp.x2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: 5),
            decoration: BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: R.sm,
              border: Border.all(color: c.borderContrast),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 14, color: c.textSecondary),
                const SizedBox(width: Sp.x1 + 1),
                Flexible(
                  child: Text(
                    'Preview only - not streamable in this demo',
                    style: AppType.caption.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chapters({required bool wide}) {
    final chapters = _streamableBook?.chapters ?? const <AudiobookChapter>[];
    final total = chapters.fold<int>(0, (sum, ch) => sum + ch.durationSeconds);
    final playable = widget.book.demoPlayable;
    final collapsible = chapters.length > _collapsedChapters;
    final shown = (collapsible && !_allChapters)
        ? chapters.sublist(0, _collapsedChapters)
        : chapters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChaptersHeader(count: chapters.length, totalSeconds: total),
        const SizedBox(height: Sp.x1),
        if (_chaptersFailed && _streamableBook == null)
          EmptyChaptersNote(onRetry: _loadChapters)
        else if (_streamableBook != null && chapters.isEmpty)
          const EmptyChaptersNote(),
        for (var i = 0; i < shown.length; i++)
          ChapterListRow(
            index: i,
            title: shown[i].title,
            durationSeconds: shown[i].durationSeconds,
            wide: wide,
            disabledNote: playable ? null : 'Preview only',
            onTap: playable
                ? () async {
                    await widget.audioService
                        .loadBook(_streamableBook!, initialChapterIndex: i);
                  }
                : null,
          ),
        if (collapsible)
          TextButton(
            onPressed: () => setState(() => _allChapters = !_allChapters),
            child: Text(_allChapters
                ? 'Show fewer chapters'
                : 'Show all ${chapters.length} chapters'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final book = widget.book;
    final about = ParsedAbout.from(book.description);
    final credit = about.credit;
    final creditText = credit == null
        ? null
        : Text(credit, style: AppType.caption.copyWith(color: c.textMuted));
    final cover = AppBookCover(
      bookId: book.id,
      title: book.title,
      coverUrl: _coverArtUrl,
      width: widget.wide ? 252 : 88,
      height: widget.wide ? 252 : 88,
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
                    cover,
                    const SizedBox(height: Sp.x5),
                    _primaryAction(),
                    const SizedBox(height: Sp.x5),
                    BookMetaList(items: _meta(wide: true)),
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
                        Expanded(child: _titleBlock(wide: true)),
                        const SizedBox(width: Sp.x2),
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
                        _chapters(wide: true),
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
                  cover,
                  const SizedBox(width: Sp.x4),
                  Expanded(child: _titleBlock(wide: false)),
                ],
              ),
              const SizedBox(height: Sp.x5),
              BookMetaRow(items: _meta(wide: false)),
              if (about.text != null) ...[
                const SizedBox(height: Sp.x5),
                ExpandableAbout(text: about.text!),
              ],
              const SizedBox(height: Sp.x5),
              _chapters(wide: false),
              if (creditText != null) ...[
                const SizedBox(height: Sp.x5),
                creditText,
              ],
            ],
          ),
        ),
        DetailStickyFooter(child: _primaryAction()),
      ],
    );
  }
}

/// Shown in place of the (empty) chapter list while the streamable copy of
/// a book has been resolved but turned out to have no chapters — a
/// LibriVox catalog entry occasionally has metadata but no parseable audio
/// files. Explains the gap rather than leaving a blank area under the
/// "Chapters (0)" heading, and points at the fix (download the book,
/// which pulls chapters from the ZIP rather than the RSS feed this pane
/// streams from).
///
/// With [onRetry] it is the failure version instead: the chapter list
/// couldn't be fetched at all (offline, timed out), with a way to try again.
class EmptyChaptersNote extends StatelessWidget {
  final VoidCallback? onRetry;

  const EmptyChaptersNote({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: R.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.menu_book_outlined,
              color: c.textSecondary, size: Dim.iconSm),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Text(
              onRetry != null
                  ? "Couldn't load the chapters. Check your connection and "
                      'try again.'
                  : "The chapter list isn't available yet. Download the book "
                      'to get every chapter.',
              style:
                  AppType.body.copyWith(color: c.textSecondary, height: 1.45),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Formats a byte count as the sticky footer's "ZIP · NNN MB" line, or
/// "1.2 GB" past a gigabyte. `null` means unknown (still loading, or the
/// lookup failed/found nothing), and the caller omits the line entirely
/// in that case rather than showing a placeholder.
String? formatZipSize(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  return '${mb.round()} MB';
}

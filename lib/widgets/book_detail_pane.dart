import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/demo_mode.dart';
import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/librivox_book.dart';
import '../domain/models/audiobook.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/librivox_downloader.dart';
import '../services/audio_playback_service.dart';
import 'book_cover_image.dart';
import 'glass_card.dart';

class BookDetailPane extends StatefulWidget {
  final LibriVoxBook book;
  final ArtworkEnrichmentService artworkService;
  final LibriVoxStreamAndDownloader downloader;
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const BookDetailPane({
    super.key,
    required this.book,
    required this.artworkService,
    required this.downloader,
    required this.audioService,
    required this.db,
  });

  @override
  State<BookDetailPane> createState() => _BookDetailPaneState();
}

class _BookDetailPaneState extends State<BookDetailPane> {
  String? _coverArtUrl;
  UnifiedAudiobook? _streamableBook;
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
    final coverFuture = widget.artworkService.resolveCoverArtUrl(widget.book);
    final streamFuture = widget.downloader.parseStreamableBook(widget.book);

    final results = await Future.wait([coverFuture, streamFuture]);

    if (mounted) {
      setState(() {
        _coverArtUrl = results[0] as String?;
        _streamableBook = results[1] as UnifiedAudiobook?;
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
      final savePath =
          p.join(appDir.path, 'diegema', 'downloads');

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

      final List<AudiobookChapter> chapters = [];
      for (int i = 0; i < extractedFiles.length; i++) {
        final filePath = extractedFiles[i];
        final filename = p.basename(filePath);
        chapters.add(
          AudiobookChapter(
            id: '${canonicalId}_local_$i',
            title: filename.replaceAll('.mp3', ''),
            audioPathOrUrl: filePath,
            durationSeconds: 0,
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
              child: (kDemoMode || _coverArtUrl != null)
                  ? BookCoverImage(
                      bookId: widget.book.id,
                      networkUrl: _coverArtUrl,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      fallbackBuilder: (_) => _buildCoverFallback(theme),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Author: ${widget.book.authorNames}',
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (widget.book.narrators.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Narrated by: ${widget.book.narrators.join(', ')}',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12),
                    ),
                  ],
                  if (!widget.book.demoPlayable) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 12, color: Colors.white70),
                          SizedBox(width: 5),
                          Text(
                            'PREVIEW ONLY — not streamable in this demo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Full-book ZIP download is never available in the web demo (it is
        // streaming-only, see rework_plan.md).
        //
        // Shown disabled rather than hidden: the demo's job is to represent
        // the real app, and silently omitting the control made offline
        // listening look like a feature that does not exist. A greyed box
        // says "this is here, just not in a browser preview" — and it can
        // never fail, because it is not a button at all.
        if (kDemoMode)
          Semantics(
            enabled: false,
            label: 'Download full audiobook. '
                'Not available in this browser preview.',
            excludeSemantics: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Download Full Audiobook (ZIP)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.38),
                          ),
                        ),
                        Text(
                          'Offline listening is in the app, not this preview',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (kDemoMode) const SizedBox(height: 20),
        if (!kDemoMode)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isDownloaded ? Colors.teal : theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(_isDownloading
                  ? Icons.downloading
                  : (_isDownloaded
                      ? Icons.check_circle
                      : Icons.download_rounded)),
              label: Text(
                _isDownloading
                    ? 'Downloading (${(_downloadProgress * 100).toStringAsFixed(0)}%)...'
                    : (_isDownloaded
                        ? 'Downloaded to Local Storage'
                        : 'Download Full Audiobook (ZIP)'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _isDownloading ? null : _downloadBook,
            ),
          ),
        if (!kDemoMode) const SizedBox(height: 20),
        GlassCard(
          title: 'Description',
          borderRadius: BorderRadius.circular(10),
          child: Text(widget.book.description,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  height: 1.5,
                  fontSize: 13)),
        ),
        const SizedBox(height: 20),
        Text(
          'Chapters (${_streamableBook?.chapters.length ?? 0})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_streamableBook != null)
          ..._streamableBook!.chapters.asMap().entries.map((entry) {
            final idx = entry.key;
            final ch = entry.value;
            final playable = widget.book.demoPlayable;
            final disabledColor =
                theme.colorScheme.onSurface.withValues(alpha: 0.35);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassCard(
                borderRadius: BorderRadius.circular(8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      playable ? Icons.play_circle_fill : Icons.lock_rounded,
                      color: playable ? theme.colorScheme.primary : disabledColor,
                      size: playable ? 26 : 20,
                    ),
                    title: Text(ch.title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: playable ? null : disabledColor)),
                    subtitle: Text(
                        playable
                            ? '${(ch.durationSeconds / 60).toStringAsFixed(1)} mins'
                            : 'Preview only — not streamable in this demo',
                        style: TextStyle(
                            fontSize: 10,
                            color: playable ? null : disabledColor)),
                    onTap: playable
                        ? () async {
                            await widget.audioService.loadBook(
                                _streamableBook!,
                                initialChapterIndex: idx);
                          }
                        : null,
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

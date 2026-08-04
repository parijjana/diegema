import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import '../domain/models/librivox_book.dart';
import '../domain/models/audiobook.dart';
import '../services/artwork_enrichment_service.dart';
import '../services/librivox_downloader.dart';
import '../services/audio_playback_service.dart';
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

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
import '../services/librivox_service.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import 'book_cover_image.dart';
import 'book_description_view.dart';
import 'glass_card.dart';

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

  const BookDetailPane({
    super.key,
    required this.book,
    required this.artworkService,
    required this.downloader,
    required this.audioService,
    required this.db,
    this.libriVoxService,
    this.wide = false,
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
    final streamFuture = widget.downloader.parseStreamableBook(widget.book);

    final results = await Future.wait([coverFuture, streamFuture]);

    if (mounted) {
      setState(() {
        _coverArtUrl = results[0] as String?;
        _streamableBook = results[1] as UnifiedAudiobook?;
      });
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
      final appDir = await getApplicationDocumentsDirectory();
      final savePath = p.join(appDir.path, 'diegema', 'downloads');

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
    final wide = widget.wide;
    final content = _buildContent(context, theme, wide: wide);

    // Wide keeps its previous shape exactly: the download button (or its
    // demo-mode stand-in) inline in the scrolling content, no sticky
    // footer, dismissed by tapping outside the dialog as before. Only
    // phone gets the new sticky footer.
    if (wide) return content;

    return Column(
      children: [
        Expanded(child: content),
        _DownloadFooter(
          isDownloading: _isDownloading,
          isDownloaded: _isDownloaded,
          downloadProgress: _downloadProgress,
          zipSizeBytes: _zipSizeBytes,
          onDownload: _isDownloading ? null : _downloadBook,
          onClose: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme,
      {required bool wide}) {
    return ListView(
      padding: EdgeInsets.only(bottom: wide ? 20 : Sp.x2),
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
        // On phone this same action lives in the sticky footer below
        // instead (see [_DownloadFooter]) — inline here only on wide,
        // where the pane has no footer of its own.
        if (!kDemoMode && wide)
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
        if (!kDemoMode && wide) const SizedBox(height: 20),
        // No card title: the view brings its own "About" / "Contents"
        // headings, and a "Description" title over them read twice.
        GlassCard(
          borderRadius: BorderRadius.circular(10),
          child: BookDescriptionView(description: widget.book.description),
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
        if (_streamableBook != null && _streamableBook!.chapters.isEmpty)
          const EmptyChaptersNote(),
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
                      color:
                          playable ? theme.colorScheme.primary : disabledColor,
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
                            await widget.audioService.loadBook(_streamableBook!,
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

/// Shown in place of the (empty) chapter list while the streamable copy of
/// a book has been resolved but turned out to have no chapters — a
/// LibriVox catalog entry occasionally has metadata but no parseable audio
/// files. Explains the gap rather than leaving a blank area under the
/// "Chapters (0)" heading, and points at the fix (download the book,
/// which pulls chapters from the ZIP rather than the RSS feed this pane
/// streams from).
class EmptyChaptersNote extends StatelessWidget {
  const EmptyChaptersNote({super.key});

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
              "The chapter list isn't available yet. Download the book to "
              'get every chapter.',
              style:
                  AppType.body.copyWith(color: c.textSecondary, height: 1.45),
            ),
          ),
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

/// Phone-only sticky footer replacing the old top-centre close X (already
/// gone in favour of the sheet's drag handle — see the callers in
/// `discover_screen.dart`) with a 56px square Close plus the primary
/// download action, its size line reading from [LibriVoxService.zipSizeBytes]
/// by way of [formatZipSize].
class _DownloadFooter extends StatelessWidget {
  final bool isDownloading;
  final bool isDownloaded;
  final double downloadProgress;
  final int? zipSizeBytes;
  final VoidCallback? onDownload;
  final VoidCallback onClose;

  const _DownloadFooter({
    required this.isDownloading,
    required this.isDownloaded,
    required this.downloadProgress,
    required this.zipSizeBytes,
    required this.onDownload,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sizeLabel = formatZipSize(zipSizeBytes);

    final String title;
    String? subtitle;
    if (isDownloading) {
      title = 'Downloading…';
      subtitle = '${(downloadProgress * 100).round()}%';
    } else if (isDownloaded) {
      title = 'Downloaded to Local Storage';
    } else {
      title = 'Download audiobook';
      subtitle = sizeLabel == null ? null : 'ZIP · $sizeLabel';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, Sp.x5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                child: SizedBox(
                  width: Dim.tapComfy,
                  height: Dim.tapComfy,
                  child: OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(borderRadius: R.md),
                      side: BorderSide(color: c.border),
                      padding: EdgeInsets.zero,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: c.text, size: Dim.iconMd),
                  ),
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: SizedBox(
                  height: Dim.tapComfy,
                  child: Semantics(
                    button: true,
                    label: subtitle == null ? title : '$title, $subtitle',
                    excludeSemantics: true,
                    child: FilledButton.icon(
                      onPressed: onDownload,
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(borderRadius: R.md),
                        disabledBackgroundColor: c.accentFill,
                        disabledForegroundColor: c.textOnAccent,
                      ),
                      icon: Icon(isDownloaded
                          ? Icons.check_circle_rounded
                          : (isDownloading
                              ? Icons.downloading_rounded
                              : Icons.download_rounded)),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(
                                  color:
                                      c.textOnAccent.withValues(alpha: 0.85)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: Sp.x2),
            ClipRRect(
              borderRadius: R.pill,
              child: LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 3,
                backgroundColor: c.accent.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

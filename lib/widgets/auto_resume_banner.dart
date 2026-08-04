import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import 'glass_card.dart';

class AutoResumeBanner extends StatefulWidget {
  final AppDatabase db;
  final AudioPlaybackService audioService;

  const AutoResumeBanner({
    super.key,
    required this.db,
    required this.audioService,
  });

  @override
  State<AutoResumeBanner> createState() => _AutoResumeBannerState();
}

class _AutoResumeBannerState extends State<AutoResumeBanner> {
  UnifiedAudiobook? _resumeBook;
  PlaybackProgressData? _progress;
  bool _isLoading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkResumeProgress();
  }

  Future<void> _checkResumeProgress() async {
    try {
      final recentProgress = await widget.db.getMostRecentProgress();
      if (recentProgress != null && recentProgress.positionSeconds > 5) {
        final book = await widget.db.getAudiobook(recentProgress.audiobookId);
        if (mounted && book != null) {
          setState(() {
            _resumeBook = book;
            _progress = recentProgress;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('AutoResumeBanner: Error checking progress: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _dismissed || _resumeBook == null || _progress == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final chIdx = _progress!.chapterIndex;
    final chTitle = (chIdx < _resumeBook!.chapters.length)
        ? _resumeBook!.chapters[chIdx].title
        : 'Chapter ${chIdx + 1}';
    final timestampText = _formatDuration(_progress!.positionSeconds);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderColor: primary.withValues(alpha: 0.5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, color: primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'RESUME LISTENING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• $timestampText',
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _resumeBook!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    chTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('RESUME ▶',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.8)),
              onPressed: () async {
                await widget.audioService.loadBook(
                  _resumeBook!,
                  initialChapterIndex: chIdx,
                  initialPosition:
                      Duration(seconds: _progress!.positionSeconds),
                );
                setState(() => _dismissed = true);
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              tooltip: 'Dismiss',
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}

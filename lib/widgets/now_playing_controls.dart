import 'package:flutter/material.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';

class NowPlayingControls extends StatelessWidget {
  final AudioPlaybackService audioService;
  final UnifiedAudiobook book;
  final VoidCallback onAddBookmark;

  const NowPlayingControls({
    super.key,
    required this.audioService,
    required this.book,
    required this.onAddBookmark,
  });

  String _formatDuration(Duration duration) {
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Speed Selector
          PopupMenuButton<double>(
            initialValue: 1.0,
            onSelected: (speed) => audioService.setSpeed(speed),
            itemBuilder: (context) => [0.5, 0.8, 1.0, 1.25, 1.5, 2.0]
                .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: audioService.speedNotifier,
                    builder: (context, speed, child) {
                      return Text('${speed}x',
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11));
                    },
                  ),
                  Icon(Icons.arrow_drop_down, color: primary, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Sleep Timer Selector
          ValueListenableBuilder<Duration?>(
            valueListenable: audioService.sleepTimerNotifier,
            builder: (context, remainingTimer, child) {
              final isTimerActive = remainingTimer != null;
              return PopupMenuButton<int>(
                onSelected: (minutes) {
                  if (minutes == 0) {
                    audioService.cancelSleepTimer();
                  } else {
                    audioService.setSleepTimer(Duration(minutes: minutes));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0, child: Text('Turn Off Timer')),
                  const PopupMenuItem(value: 15, child: Text('15 Minutes')),
                  const PopupMenuItem(value: 30, child: Text('30 Minutes')),
                  const PopupMenuItem(value: 45, child: Text('45 Minutes')),
                  const PopupMenuItem(value: 60, child: Text('60 Minutes')),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isTimerActive
                        ? primary.withValues(alpha: 0.25)
                        : onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isTimerActive
                            ? primary
                            : onSurface.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        size: 14,
                        color: isTimerActive
                            ? primary
                            : onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTimerActive
                            ? _formatDuration(remainingTimer)
                            : 'Timer',
                        style: TextStyle(
                          color: isTimerActive
                              ? primary
                              : onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Skip Previous Chapter
          IconButton(
            onPressed: () {
              final currentIdx = audioService.chapterIndexNotifier.value;
              if (currentIdx > 0) {
                audioService.loadBook(book,
                    initialChapterIndex: currentIdx - 1);
              }
            },
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onSurface.withValues(alpha: 0.05),
                border: Border.all(color: onSurface.withValues(alpha: 0.15)),
              ),
              child:
                  Icon(Icons.skip_previous_rounded, size: 22, color: onSurface),
            ),
          ),
          const SizedBox(width: 8),
          // Replay 15s
          IconButton(
            onPressed: () => audioService.skipBackward(seconds: 15),
            icon: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onSurface.withValues(alpha: 0.05),
                border: Border.all(color: onSurface.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.replay_10_rounded, size: 24, color: onSurface),
            ),
          ),
          const SizedBox(width: 12),
          // Central Play/Pause Button
          ValueListenableBuilder<PlaybackState>(
            valueListenable: audioService.stateNotifier,
            builder: (context, state, child) {
              final isPlaying = state == PlaybackState.playing;
              return IconButton(
                onPressed: () => audioService.togglePlayPause(),
                padding: EdgeInsets.zero,
                icon: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, primary.withValues(alpha: 0.85)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: state == PlaybackState.loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Forward 15s
          IconButton(
            onPressed: () => audioService.skipForward(seconds: 15),
            icon: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onSurface.withValues(alpha: 0.05),
                border: Border.all(color: onSurface.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.forward_10_rounded, size: 24, color: onSurface),
            ),
          ),
          const SizedBox(width: 8),
          // Skip Next Chapter
          IconButton(
            onPressed: () {
              final currentIdx = audioService.chapterIndexNotifier.value;
              if (currentIdx < book.chapters.length - 1) {
                audioService.loadBook(book,
                    initialChapterIndex: currentIdx + 1);
              }
            },
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onSurface.withValues(alpha: 0.05),
                border: Border.all(color: onSurface.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.skip_next_rounded, size: 22, color: onSurface),
            ),
          ),
          const SizedBox(width: 12),
          // Save Clip Button
          IconButton(
            onPressed: onAddBookmark,
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.1),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child:
                  Icon(Icons.bookmark_add_outlined, size: 20, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}

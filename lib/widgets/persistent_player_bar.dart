import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import 'glass_card.dart';
import 'now_playing_screen.dart';

class PersistentPlayerBar extends StatelessWidget {
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const PersistentPlayerBar(
      {super.key, required this.audioService, required this.db});

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
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white),
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
          onTap: () => AulosNowPlayingScreen.openFullPage(context,
              audioService: audioService, db: db),
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
                        final currentVal = position.inSeconds
                            .toDouble()
                            .clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                activeTrackColor: theme.colorScheme.primary,
                                thumbColor: theme.colorScheme.primary,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: currentVal,
                                max: maxVal > 0 ? maxVal : 1.0,
                                onChanged: (val) {
                                  audioService
                                      .seek(Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6))),
                                  Text(_formatDuration(duration),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6))),
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
                      icon: Icon(Icons.bookmark_add_outlined,
                          color: theme.colorScheme.primary),
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
                              final chapterTitle =
                                  (index < book.chapters.length)
                                      ? book.chapters[index].title
                                      : '';
                              return Text(
                                chapterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6)),
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
                            onPressed: () =>
                                audioService.skipBackward(seconds: 15),
                          ),
                          ValueListenableBuilder<PlaybackState>(
                            valueListenable: audioService.stateNotifier,
                            builder: (context, state, child) {
                              if (state == PlaybackState.loading) {
                                return SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary),
                                );
                              }
                              final isPlaying = state == PlaybackState.playing;
                              return IconButton(
                                icon: Icon(
                                    isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 34,
                                    color: theme.colorScheme.primary),
                                onPressed: () => audioService.togglePlayPause(),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, size: 20),
                            onPressed: () =>
                                audioService.skipForward(seconds: 15),
                          ),
                          PopupMenuButton<double>(
                            icon: Icon(Icons.speed,
                                color: theme.colorScheme.primary),
                            onSelected: (speed) => audioService.setSpeed(speed),
                            itemBuilder: (context) => [
                              0.75,
                              1.0,
                              1.25,
                              1.5,
                              2.0
                            ]
                                .map((s) => PopupMenuItem(
                                    value: s, child: Text('${s}x')))
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

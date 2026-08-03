import 'package:flutter/material.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../database/app_database.dart';
import 'glass_card.dart';

class AulosNowPlayingScreen extends StatefulWidget {
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const AulosNowPlayingScreen({
    super.key,
    required this.audioService,
    required this.db,
  });

  static Future<void> openFullPage(BuildContext context, {required AudioPlaybackService audioService, required AppDatabase db}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AulosNowPlayingScreen(audioService: audioService, db: db),
      ),
    );
  }

  @override
  State<AulosNowPlayingScreen> createState() => _AulosNowPlayingScreenState();
}

class _AulosNowPlayingScreenState extends State<AulosNowPlayingScreen> {
  double _volume = 1.0;

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
        backgroundColor: const Color(0xFF14181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('SAVE AUDIO CLIP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Enter note or description for clip...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
            onPressed: () async {
              final note = noteController.text.trim();
              if (note.isNotEmpty) {
                await widget.audioService.addBookmark(note);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio clip saved!')),
                  );
                }
              }
            },
            child: const Text('SAVE CLIP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ValueListenableBuilder<UnifiedAudiobook?>(
      valueListenable: widget.audioService.currentBookNotifier,
      builder: (context, book, child) {
        if (book == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0C0E),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0A0C0E),
              title: const Text('NOW PLAYING'),
            ),
            body: const Center(child: Text('No audiobook currently playing')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0C0E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A0C0E),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'NOW PLAYING',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.bookmark_add_outlined, color: primary),
                tooltip: 'Add Bookmark / Clip',
                onPressed: () => _showAddBookmarkDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      children: [
                        // Large Center Cover Art
                        Center(
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFF14181B),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                              border: Border.all(color: primary.withValues(alpha: 0.5), width: 1.5),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.headphones_rounded, size: 90, color: primary.withValues(alpha: 0.7)),
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  right: 16,
                                  child: Text(
                                    book.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Title & Subtitle Info
                        Column(
                          children: [
                            Text(
                              book.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<int>(
                              valueListenable: widget.audioService.chapterIndexNotifier,
                              builder: (context, index, child) {
                                final chapterTitle = (index < book.chapters.length) ? book.chapters[index].title : '';
                                return Text(
                                  chapterTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, color: primary, fontWeight: FontWeight.w600),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Progress Slider & Timestamps
                        ValueListenableBuilder<Duration>(
                          valueListenable: widget.audioService.positionNotifier,
                          builder: (context, position, child) {
                            return ValueListenableBuilder<Duration>(
                              valueListenable: widget.audioService.durationNotifier,
                              builder: (context, duration, child) {
                                final maxVal = duration.inSeconds.toDouble();
                                final currentVal = position.inSeconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                        activeTrackColor: primary,
                                        thumbColor: primary,
                                        trackHeight: 4,
                                      ),
                                      child: Slider(
                                        value: currentVal,
                                        max: maxVal > 0 ? maxVal : 1.0,
                                        onChanged: (val) {
                                          widget.audioService.seek(Duration(seconds: val.toInt()));
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(_formatDuration(position), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(_formatDuration(duration), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Full Aulos Controls Suite
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Speed Selector
                              PopupMenuButton<double>(
                                initialValue: 1.0,
                                onSelected: (speed) => widget.audioService.setSpeed(speed),
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
                                        valueListenable: widget.audioService.speedNotifier,
                                        builder: (context, speed, child) {
                                          return Text('${speed}x', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 11));
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
                                valueListenable: widget.audioService.sleepTimerNotifier,
                                builder: (context, remainingTimer, child) {
                                  final isTimerActive = remainingTimer != null;
                                  return PopupMenuButton<int>(
                                    onSelected: (minutes) {
                                      if (minutes == 0) {
                                        widget.audioService.cancelSleepTimer();
                                      } else {
                                        widget.audioService.setSleepTimer(Duration(minutes: minutes));
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isTimerActive ? primary.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isTimerActive ? primary : Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bedtime_rounded,
                                            size: 14,
                                            color: isTimerActive ? primary : Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isTimerActive ? _formatDuration(remainingTimer) : 'Timer',
                                            style: TextStyle(
                                              color: isTimerActive ? primary : Colors.white70,
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
                                  final currentIdx = widget.audioService.chapterIndexNotifier.value;
                                  if (currentIdx > 0) {
                                    widget.audioService.loadBook(book, initialChapterIndex: currentIdx - 1);
                                  }
                                },
                                icon: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: const Icon(Icons.skip_previous_rounded, size: 22, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Replay 15s
                              IconButton(
                                onPressed: () => widget.audioService.skipBackward(seconds: 15),
                                icon: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: const Icon(Icons.replay_10_rounded, size: 24, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Central Glowing Aulos Play/Pause Button
                              ValueListenableBuilder<PlaybackState>(
                                valueListenable: widget.audioService.stateNotifier,
                                builder: (context, state, child) {
                                  final isPlaying = state == PlaybackState.playing;
                                  return IconButton(
                                    onPressed: () => widget.audioService.togglePlayPause(),
                                    padding: EdgeInsets.zero,
                                    icon: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [primary, primary.withValues(alpha: 0.7)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withValues(alpha: 0.45),
                                            blurRadius: 28,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: state == PlaybackState.loading
                                          ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                          : Icon(
                                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: 42,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              // Forward 15s
                              IconButton(
                                onPressed: () => widget.audioService.skipForward(seconds: 15),
                                icon: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: const Icon(Icons.forward_10_rounded, size: 24, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Skip Next Chapter
                              IconButton(
                                onPressed: () {
                                  final currentIdx = widget.audioService.chapterIndexNotifier.value;
                                  if (currentIdx < book.chapters.length - 1) {
                                    widget.audioService.loadBook(book, initialChapterIndex: currentIdx + 1);
                                  }
                                },
                                icon: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: const Icon(Icons.skip_next_rounded, size: 22, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Save Clip Button
                              IconButton(
                                onPressed: () => _showAddBookmarkDialog(context),
                                icon: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primary.withValues(alpha: 0.1),
                                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(Icons.bookmark_add_outlined, size: 20, color: primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Volume Slider
                        Row(
                          children: [
                            Icon(Icons.volume_down_rounded, size: 18, color: Colors.grey[400]),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: primary,
                                  thumbColor: primary,
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: _volume,
                                  onChanged: (val) {
                                    setState(() => _volume = val);
                                  },
                                ),
                              ),
                            ),
                            Icon(Icons.volume_up_rounded, size: 18, color: Colors.grey[400]),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Chapters Section Header & Chapter List
                        Text(
                          'CHAPTERS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...book.chapters.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ch = entry.value;
                          return ValueListenableBuilder<int>(
                            valueListenable: widget.audioService.chapterIndexNotifier,
                            builder: (context, activeIdx, child) {
                              final isPlayingChapter = activeIdx == idx;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  borderColor: isPlayingChapter ? primary : Colors.transparent,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        isPlayingChapter ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                        color: primary,
                                        size: 26,
                                      ),
                                      title: Text(
                                        ch.title,
                                        style: TextStyle(
                                          fontWeight: isPlayingChapter ? FontWeight.bold : FontWeight.normal,
                                          color: isPlayingChapter ? primary : Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text('${(ch.durationSeconds / 60).toStringAsFixed(1)} mins', style: const TextStyle(fontSize: 11)),
                                      onTap: () async {
                                        await widget.audioService.loadBook(book, initialChapterIndex: idx);
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

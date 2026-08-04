import 'package:flutter/material.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../database/app_database.dart';
import 'glass_card.dart';
import 'now_playing_controls.dart';

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
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'SAVE AUDIO CLIP',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: theme.colorScheme.primary,
          ),
        ),
        content: TextField(
          controller: noteController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter note or description for clip...',
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              title: const Text('NOW PLAYING'),
            ),
            body: const Center(child: Text('No audiobook currently playing')),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 24, color: theme.colorScheme.onSurface),
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
                        Center(
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: theme.colorScheme.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.25),
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
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            Text(
                              book.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
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
                                          Text(_formatDuration(position), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                          Text(_formatDuration(duration), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
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
                        NowPlayingControls(
                          audioService: widget.audioService,
                          book: book,
                          onAddBookmark: () => _showAddBookmarkDialog(context),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.volume_down_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                            Icon(Icons.volume_up_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ],
                        ),
                        const SizedBox(height: 28),
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
                                          color: isPlayingChapter ? primary : theme.colorScheme.onSurface,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${(ch.durationSeconds / 60).toStringAsFixed(1)} mins',
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                      ),
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

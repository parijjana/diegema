import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/audio_playback_service.dart';

class BookmarksDrawer extends StatelessWidget {
  final String audiobookId;
  final AppDatabase db;
  final AudioPlaybackService audioService;

  const BookmarksDrawer({
    super.key,
    required this.audiobookId,
    required this.db,
    required this.audioService,
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
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.bookmark, color: Colors.amber),
                  const SizedBox(width: 12),
                  Text(
                    'Audiobook Bookmarks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Bookmark>>(
                future: db.getBookmarks(audiobookId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bookmarks = snapshot.data ?? [];
                  if (bookmarks.isEmpty) {
                    return const Center(
                      child: Text(
                        'No bookmarks added yet.\nTap the bookmark icon in the player bar!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bm = bookmarks[index];
                      final dur = Duration(seconds: bm.positionSeconds);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withValues(alpha: 0.15),
                          child: Text(
                            'Ch ${bm.chapterIndex + 1}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(bm.note,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'Timestamp: ${_formatDuration(dur)}',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing:
                            const Icon(Icons.play_arrow, color: Colors.amber),
                        onTap: () async {
                          Navigator.pop(context);
                          final book = audioService.currentBookNotifier.value;
                          if (book != null) {
                            await audioService.loadBook(
                              book,
                              initialChapterIndex: bm.chapterIndex,
                              initialPosition: dur,
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import 'glass_card.dart';
import 'librivox_volunteer_banner.dart';
import 'local_audiobook_importer.dart';

class LibraryView extends StatefulWidget {
  final AppDatabase db;
  final AudioPlaybackService audioService;
  final VoidCallback onGoToDiscover;

  const LibraryView({
    super.key,
    required this.db,
    required this.audioService,
    required this.onGoToDiscover,
  });

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  List<UnifiedAudiobook> _libraryBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir =
          Directory(p.join(appDir.path, 'unamedaudiobookplayer', 'downloads'));

      if (await downloadsDir.exists()) {
        final List<FileSystemEntity> entities =
            await downloadsDir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final folderName = p.basename(entity.path);
            final mp3Files = entity
                .listSync()
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp3'))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));

            if (mp3Files.isNotEmpty) {
              final bookId = 'local_${folderName.hashCode.abs()}';
              final existing = await widget.db.getAudiobook(bookId);
              if (existing == null) {
                final chapters = mp3Files.asMap().entries.map((e) {
                  final idx = e.key;
                  final file = e.value;
                  final name = p.basename(file.path).replaceAll('.mp3', '');
                  return AudiobookChapter(
                    id: '${bookId}_ch_$idx',
                    title: name,
                    audioPathOrUrl: file.path,
                    durationSeconds: 0,
                    isStream: false,
                  );
                }).toList();

                final book = UnifiedAudiobook(
                  id: bookId,
                  title: folderName.replaceAll('_', ' '),
                  author: 'Downloaded Audiobook',
                  description: 'Downloaded to local storage.',
                  source: 'Local Storage',
                  chapters: chapters,
                  isDownloaded: true,
                );
                await widget.db.saveAudiobook(book);
              }
            }
          }
        }
      }

      final books = await widget.db.getAllAudiobooks();
      if (mounted) {
        setState(() {
          _libraryBooks = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error scanning library: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showImportOptions() {
    LocalAudiobookImporter.showOptionsModal(context, widget.db, _loadLibrary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    if (_libraryBooks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.collections_bookmark_rounded,
                    size: 48, color: primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'YOUR LIBRARY IS EMPTY',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Import local audiobooks or download from Discover.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('IMPORT LOCAL BOOK',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.0)),
                    onPressed: _showImportOptions,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 18),
                    label: const Text('DISCOVER',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.0)),
                    onPressed: widget.onGoToDiscover,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const LibriVoxVolunteerBanner(),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR LIBRARY (${_libraryBooks.length})'.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: primary,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary.withValues(alpha: 0.15),
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('IMPORT BOOK',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1.0)),
                    onPressed: _showImportOptions,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadLibrary,
                    tooltip: 'Refresh Library',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: LibriVoxVolunteerBanner(),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: _libraryBooks.length,
            itemBuilder: (context, index) {
              final book = _libraryBooks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.book_rounded, color: primary, size: 24),
                    ),
                    title: Text(
                      book.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${book.author} • ${book.chapters.length} chapters (${book.source ?? 'Local'})',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.play_circle_fill,
                          color: primary, size: 36),
                      onPressed: () async {
                        await widget.audioService.loadBook(book);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

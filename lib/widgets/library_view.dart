import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import 'glass_card.dart';

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
      // 1. Scan filesystem for downloaded audiobooks in local storage
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'unamedaudiobookplayer', 'downloads'));

      if (await downloadsDir.exists()) {
        final List<FileSystemEntity> entities = await downloadsDir.list().toList();
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

      // 2. Fetch all books from SQLite database
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

  Future<void> _launchVolunteerUrl() async {
    final uri = Uri.parse('https://librivox.org/pages/volunteer-for-librivox/');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching volunteer URL: $e');
    }
  }

  Future<void> _importLocalFolder() async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Audiobook Directory',
      );

      if (selectedDirectory == null) return;

      final folderDir = Directory(selectedDirectory);
      final folderName = p.basename(selectedDirectory);

      final files = await folderDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((f) {
            final ext = p.extension(f.path).toLowerCase();
            return ['.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg'].contains(ext);
          })
          .toList();

      files.sort((a, b) => a.path.compareTo(b.path));

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No audio files (.mp3, .m4a, etc.) found in selected folder.')),
          );
        }
        return;
      }

      final bookId = 'imported_folder_${selectedDirectory.hashCode.abs()}';
      final chapters = files.asMap().entries.map((entry) {
        final idx = entry.key;
        final file = entry.value;
        final title = p.basenameWithoutExtension(file.path);
        return AudiobookChapter(
          id: '${bookId}_ch_$idx',
          title: title,
          audioPathOrUrl: file.path,
          durationSeconds: 0,
          isStream: false,
        );
      }).toList();

      final book = UnifiedAudiobook(
        id: bookId,
        title: folderName.replaceAll('_', ' '),
        author: 'Local Audiobook',
        description: 'Imported from folder: $selectedDirectory',
        source: 'Local Folder',
        chapters: chapters,
        isDownloaded: true,
      );

      await widget.db.saveAudiobook(book);
      await _loadLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${book.title}" (${chapters.length} chapters)!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder import failed: $e')),
        );
      }
    }
  }

  Future<void> _importLocalFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg'],
        dialogTitle: 'Select Audio Files for Audiobook',
      );

      if (result == null || result.files.isEmpty) return;

      final List<String> paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList()
        ..sort();

      if (paths.isEmpty) return;

      final firstFile = paths.first;
      final parentFolder = p.basename(p.dirname(firstFile));
      final defaultTitle = parentFolder.isNotEmpty && parentFolder != '.' ? parentFolder : 'Imported Audiobook';

      final bookId = 'imported_files_${paths.join().hashCode.abs()}';
      final chapters = paths.asMap().entries.map((entry) {
        final idx = entry.key;
        final path = entry.value;
        final title = p.basenameWithoutExtension(path);
        return AudiobookChapter(
          id: '${bookId}_ch_$idx',
          title: title,
          audioPathOrUrl: path,
          durationSeconds: 0,
          isStream: false,
        );
      }).toList();

      final book = UnifiedAudiobook(
        id: bookId,
        title: defaultTitle.replaceAll('_', ' '),
        author: 'Local Files',
        description: 'Imported ${paths.length} local audio files.',
        source: 'Local Files',
        chapters: chapters,
        isDownloaded: true,
      );

      await widget.db.saveAudiobook(book);
      await _loadLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${book.title}" (${chapters.length} files)!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Files import failed: $e')),
        );
      }
    }
  }

  void _showImportOptionsModal() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IMPORT LOCAL AUDIOBOOK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.folder_open_rounded, color: primary),
              title: const Text('Import Audiobook Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Select a directory containing MP3, M4A, or FLAC chapters', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _importLocalFolder();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.audio_file_rounded, color: primary),
              title: const Text('Import Audio Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Select individual audio files to group into an audiobook', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _importLocalFiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerBanner(ThemeData theme) {
    final primary = theme.colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: primary.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VOLUNTEER FOR LIBRIVOX',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
                ),
                const SizedBox(height: 3),
                Text(
                  'Donate your voice or proof-listen to help bring public domain books to life.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _launchVolunteerUrl,
            child: Text(
              'JOIN →',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
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
                child: Icon(Icons.collections_bookmark_rounded, size: 48, color: primary),
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
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('IMPORT LOCAL BOOK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                    onPressed: _showImportOptionsModal,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 18),
                    label: const Text('DISCOVER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                    onPressed: widget.onGoToDiscover,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildVolunteerBanner(theme),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('IMPORT BOOK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0)),
                    onPressed: _showImportOptionsModal,
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
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildVolunteerBanner(theme),
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
                        color: const Color(0xFF14181B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.book_rounded, color: primary, size: 24),
                    ),
                    title: Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${book.author} • ${book.chapters.length} chapters (${book.source ?? 'Local'})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.play_circle_fill, color: primary, size: 36),
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';

class LocalAudiobookImporter {
  static Future<void> importFolder(BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
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
        if (context.mounted) {
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

      await db.saveAudiobook(book);
      onSuccess();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${book.title}" (${chapters.length} chapters)!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder import failed: $e')),
        );
      }
    }
  }

  static Future<void> importFiles(BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
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

      await db.saveAudiobook(book);
      onSuccess();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${book.title}" (${paths.length} files)!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Files import failed: $e')),
        );
      }
    }
  }

  static void showOptionsModal(BuildContext context, AppDatabase db, VoidCallback onSuccess) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
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
                importFolder(context, db, onSuccess);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.audio_file_rounded, color: primary),
              title: const Text('Import Audio Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Select individual audio files to group into an audiobook', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                importFiles(context, db, onSuccess);
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';

Future<void> importFolder(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
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
    }).toList();

    files.sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No audio files (.mp3, .m4a, etc.) found in selected folder.')),
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
        SnackBar(
            content: Text(
                'Imported "${book.title}" (${chapters.length} chapters)!')),
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

Future<void> importFiles(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
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
    final defaultTitle = parentFolder.isNotEmpty && parentFolder != '.'
        ? parentFolder
        : 'Imported Audiobook';

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
        SnackBar(
            content:
                Text('Imported "${book.title}" (${paths.length} files)!')),
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

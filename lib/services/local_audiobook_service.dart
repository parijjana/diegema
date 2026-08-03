import 'dart:io';
import 'package:path/path.dart' as p;
import '../domain/models/audiobook.dart';

class LocalAudiobookService {
  /// Scans a local directory recursively for audiobooks (.m4b, .mp3, .flac, .aac)
  Future<List<UnifiedAudiobook>> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final Map<String, List<File>> audiobooksByFolder = {};

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (['.m4b', '.mp3', '.flac', '.aac', '.m4a'].contains(ext)) {
          final parentDir = entity.parent.path;
          audiobooksByFolder.putIfAbsent(parentDir, () => []).add(entity);
        }
      }
    }

    final List<UnifiedAudiobook> audiobooks = [];

    for (final entry in audiobooksByFolder.entries) {
      final folderPath = entry.key;
      final files = entry.value;
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      final List<AudiobookChapter> chapters = [];
      String bookTitle = p.basename(folderPath);
      String author = 'Local Library';

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        String chapterTitle = p.basenameWithoutExtension(file.path);

        chapters.add(AudiobookChapter(
          id: '${file.path}_$i',
          title: chapterTitle,
          audioPathOrUrl: file.path,
          durationSeconds: 0,
          isStream: false,
        ));
      }

      audiobooks.add(UnifiedAudiobook(
        id: folderPath,
        title: bookTitle,
        author: author,
        description: 'Local audiobook folder: $folderPath',
        source: 'Local',
        chapters: chapters,
        isDownloaded: true,
      ));
    }

    return audiobooks;
  }
}

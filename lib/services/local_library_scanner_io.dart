import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';

/// Scans `<app documents>/unamedaudiobookplayer/downloads` (the directory
/// `BookDetailPane`'s ZIP downloader writes into) and registers any
/// not-yet-known book folders in [db].
Future<void> scanDownloadedLibrary(AppDatabase db) async {
  final appDir = await getApplicationDocumentsDirectory();
  final downloadsDir =
      Directory(p.join(appDir.path, 'unamedaudiobookplayer', 'downloads'));

  if (!await downloadsDir.exists()) return;

  final List<FileSystemEntity> entities = await downloadsDir.list().toList();
  for (final entity in entities) {
    if (entity is! Directory) continue;

    final folderName = p.basename(entity.path);
    final mp3Files = entity
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mp3'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (mp3Files.isEmpty) continue;

    final bookId = 'local_${folderName.hashCode.abs()}';
    final existing = await db.getAudiobook(bookId);
    if (existing != null) continue;

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
    await db.saveAudiobook(book);
  }
}

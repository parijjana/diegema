import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/downloads_location_io.dart';
import 'package:diegema/services/librivox_downloader_io.dart';
import 'package:diegema/services/redownload_io.dart';

List<int> _zip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach(
      (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)));
  return ZipEncoder().encode(archive);
}

void main() {
  late AppDatabase db;
  late Directory root;
  late DownloadsLocation location;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('redownload');
    location = DownloadsLocation(
        documentsRoot: () async => root.path,
        visibleRoot: () async => p.join(root.path, 'Audiobooks', 'Diegema'));
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  UnifiedAudiobook gone() => UnifiedAudiobook(
        id: 'tenn_librivox',
        title: '3 Science Fiction Stories',
        author: 'William Tenn',
        description: '',
        source: 'Downloaded',
        origin: BookIdentity.originLibrivox,
        isDownloaded: true,
        chapters: [
          for (var i = 0; i < 2; i++)
            AudiobookChapter(
                id: 'ch$i',
                title: 'Story ${i + 1}',
                audioPathOrUrl: '/nowhere/0$i.mp3',
                durationSeconds: 100),
        ],
      );

  test('a missing downloaded file is unreadable; streams and imports are not '
      'offered a re-download', () async {
    expect(await downloadedChapterReadable(gone(), 0), isFalse);
    expect(canRedownload(gone()), isTrue);
    final local = UnifiedAudiobook(
        id: '${BookIdentity.localIdPrefix}x',
        title: 't',
        author: 'a',
        description: '',
        source: 'Library folder',
        origin: BookIdentity.originLocal,
        isDownloaded: true,
        chapters: const []);
    expect(canRedownload(local), isFalse);
  });

  test('re-download keeps id, titles, progress; uses the pre-built ZIP and '
      'falls back to compress on 404', () async {
    await db.saveAudiobook(gone());
    await db.saveProgress(
        audiobookId: 'tenn_librivox', chapterIndex: 1, positionSeconds: 42);
    final urls = <String>[];
    final body = _zip({'01.mp3': [1, 2], '02.mp3': [3]});
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      return request.url.path.contains('/download/')
          ? http.Response('', 404)
          : http.Response.bytes(body, 200);
    });

    final fresh = await redownloadBook(db, gone(),
        downloader: LibriVoxStreamAndDownloader(client: client),
        location: location);

    expect(urls.first, contains('/download/tenn_librivox/'));
    expect(urls.last, contains('/compress/tenn_librivox/'));
    expect(fresh.chapters.map((c) => c.title), ['Story 1', 'Story 2']);
    expect(fresh.chapters.first.audioPathOrUrl,
        startsWith(p.join(root.path, 'Audiobooks', 'Diegema')));
    expect(await downloadedChapterReadable(fresh, 1), isTrue);
    final saved = (await db.getAudiobook('tenn_librivox'))!;
    expect(saved.chapters.first.audioPathOrUrl,
        fresh.chapters.first.audioPathOrUrl);
    expect((await db.getProgress('tenn_librivox'))!.positionSeconds, 42);
  });
}

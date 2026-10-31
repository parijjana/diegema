import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/find_cover_service.dart';
import 'package:diegema/services/cover_lookup_service.dart';
import 'package:diegema/services/local_cover_backfill_service.dart';

import '../support/mp4_builder.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'local_cover_backfill_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> writeFixture(String name, List<int> bytes) async {
    final path = p.join(tempDir.path, name);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> saveLocalBook({
    required String id,
    required String title,
    required String author,
    required String origin,
    required List<String> filePaths,
  }) async {
    await db.saveAudiobook(
      UnifiedAudiobook(
        id: id,
        title: title,
        author: author,
        description: '',
        origin: origin,
        chapters: [
          for (int i = 0; i < filePaths.length; i++)
            AudiobookChapter(
              id: '${id}_ch_$i',
              title: 'Chapter $i',
              audioPathOrUrl: filePaths[i],
              durationSeconds: 0,
            ),
        ],
      ),
    );
  }

  test('finds embedded cover art for a local book with no cover', () async {
    final jpeg = syntheticJpegBytes();
    final filePath = await writeFixture(
      'book.m4b',
      buildM4bWithMetadata(album: 'Found Title', coverBytes: jpeg),
    );
    await saveLocalBook(
      id: 'local_1',
      title: 'Untitled Folder',
      author: 'Local Audiobook',
      origin: 'local',
      filePaths: [filePath],
    );

    final service = LocalCoverBackfillService(db: db);
    await service.run();

    final updated = await db.getAudiobook('local_1');
    expect(updated!.coverArtUrlOrPath, isNotNull);
    expect(File(updated.coverArtUrlOrPath!).readAsBytesSync(), equals(jpeg));
  });

  test('replaces a placeholder title and author from embedded tags, '
      'even when the book was already attempted', () async {
    final filePath = await writeFixture(
      'odyssey.m4b',
      buildM4bWithMetadata(
        album: 'The Odyssey for Boys and Girls',
        artist: 'Alfred John Church',
        coverBytes: syntheticJpegBytes(),
      ),
    );
    await saveLocalBook(
      id: 'local_tags',
      title: 'Odyssey',
      author: 'Local Files',
      origin: 'local',
      filePaths: [filePath],
    );

    final service = LocalCoverBackfillService(db: db);
    await service.run();

    final updated = await db.getAudiobook('local_tags');
    expect(updated!.title, 'The Odyssey for Boys and Girls');
    expect(updated.author, 'Alfred John Church');
    expect(updated.coverArtUrlOrPath, isNotNull);
  });

  test('makes NO network call for a local book with no art (S-05)', () async {
    final filePath = await writeFixture('book.mp3', [0xFF, 0xFB, 0, 0]);
    await saveLocalBook(
      id: 'local_2',
      title: 'A Private Recording',
      author: 'Local Audiobook',
      origin: 'local',
      filePaths: [filePath],
    );

    await HttpOverrides.runZoned(
      () => LocalCoverBackfillService(db: db).run(),
      createHttpClient: (_) => throw StateError('network used'),
    );

    final updated = await db.getAudiobook('local_2');
    expect(updated!.coverArtUrlOrPath, isNull);
  });

  test('backfill and import sources do not reference the lookup service', () {
    for (final f in [
      'lib/services/local_cover_backfill_service_io.dart',
      'lib/services/local_audiobook_import_io.dart',
      'lib/services/local_library_scanner_io.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('CoverLookupService'), isFalse, reason: f);
      expect(src.contains('cover_lookup_service'), isFalse, reason: f);
    }
  });

  test('findCoverOnRequest looks up and saves for a local book', () async {
    await saveLocalBook(
      id: 'local_5',
      title: 'The Odyssey for Boys and Girls',
      author: 'Local Audiobook',
      origin: 'local',
      filePaths: const [],
    );
    final book = (await db.getAudiobook('local_5'))!;
    final url = await findCoverOnRequest(
      db,
      book,
      lookupService: CoverLookupService(
        client: MockClient(
          (request) async => request.url.host == 'archive.org'
              ? http.Response(
                  '{"response":{"docs":[{"identifier":"odyssey_id","title":"The Odyssey for Boys and Girls"}]}}',
                  200,
                )
              : http.Response('{"docs":[]}', 200),
        ),
      ),
    );
    expect(url, 'https://archive.org/services/img/odyssey_id');
    expect((await db.getAudiobook('local_5'))!.coverArtUrlOrPath, url);
  });

  test('findCoverOnRequest ignores LibriVox books', () async {
    await saveLocalBook(
      id: 'lv_2',
      title: 'A LibriVox Book',
      author: 'Someone',
      origin: 'librivox',
      filePaths: const [],
    );
    final book = (await db.getAudiobook('lv_2'))!;
    var called = false;
    final url = await findCoverOnRequest(
      db,
      book,
      lookupService: CoverLookupService(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      ),
    );
    expect(url, isNull);
    expect(called, isFalse);
  });

  test('skips a book that already has a cover', () async {
    final filePath = await writeFixture('book.mp3', [0]);
    await saveLocalBook(
      id: 'local_3',
      title: 'Already Has Art',
      author: 'Local Audiobook',
      origin: 'local',
      filePaths: [filePath],
    );
    await db.setCoverUrl('local_3', 'https://example.com/existing.jpg');
    await LocalCoverBackfillService(db: db).run();
    final updated = await db.getAudiobook('local_3');
    expect(
      updated!.coverArtUrlOrPath,
      equals('https://example.com/existing.jpg'),
    );
  });
}

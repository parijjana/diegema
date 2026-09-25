import 'dart:convert';
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
import 'package:diegema/services/backfill_attempt_store.dart';
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
    tempDir =
        await Directory.systemTemp.createTemp('local_cover_backfill_test_');
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
    await db.saveAudiobook(UnifiedAudiobook(
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
    ));
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

    final service = LocalCoverBackfillService(
      db: db,
      store: const BackfillAttemptStore(overrides: {}),
      lookupService: CoverLookupService(
        client: MockClient((_) async => http.Response('', 500)),
      ),
    );
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
          coverBytes: syntheticJpegBytes()),
    );
    await saveLocalBook(
      id: 'local_tags',
      title: 'Odyssey',
      author: 'Local Files',
      origin: 'local',
      filePaths: [filePath],
    );

    final service = LocalCoverBackfillService(
      db: db,
      // Attempted a minute ago: only the online step is rationed.
      store: BackfillAttemptStore(overrides: {
        'local_cover_backfill.attempted.v1': jsonEncode({
          'local_tags': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        }),
      }),
      lookupService: CoverLookupService(
        client: MockClient((_) async => http.Response('', 500)),
      ),
    );
    await service.run();

    final updated = await db.getAudiobook('local_tags');
    expect(updated!.title, 'The Odyssey for Boys and Girls');
    expect(updated.author, 'Alfred John Church');
    expect(updated.coverArtUrlOrPath, isNotNull);
  });

  test('falls back to online lookup when no embedded/folder art exists',
      () async {
    final filePath = await writeFixture('book.mp3', [0xFF, 0xFB, 0, 0]);
    await saveLocalBook(
      id: 'local_2',
      title: 'The Odyssey for Boys and Girls',
      author: 'Local Audiobook',
      origin: 'local',
      filePaths: [filePath],
    );

    final mockClient = MockClient((request) async {
      if (request.url.host == 'archive.org') {
        return http.Response(
          '{"response":{"docs":[{"identifier":"odyssey_id","title":"The Odyssey for Boys and Girls"}]}}',
          200,
        );
      }
      return http.Response('{"docs":[]}', 200);
    });

    final service = LocalCoverBackfillService(
      db: db,
      store: const BackfillAttemptStore(overrides: {}),
      lookupService: CoverLookupService(client: mockClient),
    );
    await service.run();

    final updated = await db.getAudiobook('local_2');
    expect(updated!.coverArtUrlOrPath,
        equals('https://archive.org/services/img/odyssey_id'));
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

    var lookupCalled = false;
    final service = LocalCoverBackfillService(
      db: db,
      store: const BackfillAttemptStore(overrides: {}),
      lookupService: CoverLookupService(
        client: MockClient((_) async {
          lookupCalled = true;
          return http.Response('{"docs":[]}', 200);
        }),
      ),
    );
    await service.run();

    expect(lookupCalled, isFalse);
    final updated = await db.getAudiobook('local_3');
    expect(updated!.coverArtUrlOrPath, equals('https://example.com/existing.jpg'));
  });

  test('skips non-local (librivox) origin books', () async {
    var lookupCalled = false;
    await saveLocalBook(
      id: 'lv_1',
      title: 'A LibriVox Book',
      author: 'Someone',
      origin: 'librivox',
      filePaths: const [],
    );

    final service = LocalCoverBackfillService(
      db: db,
      store: const BackfillAttemptStore(overrides: {}),
      lookupService: CoverLookupService(
        client: MockClient((_) async {
          lookupCalled = true;
          return http.Response('{"docs":[]}', 200);
        }),
      ),
    );
    await service.run();

    expect(lookupCalled, isFalse);
  });

  test('does not re-query a recently attempted book, but does after 30 days',
      () async {
    final filePath = await writeFixture('book.mp3', [0]);
    await saveLocalBook(
      id: 'local_4',
      title: 'No Findable Art',
      author: 'Local Audiobook',
      origin: 'local',
      filePaths: [filePath],
    );

    var callCount = 0;
    CoverLookupService lookupService() => CoverLookupService(
          client: MockClient((_) async {
            callCount++;
            return http.Response('{"docs":[]}', 200);
          }),
        );

    final overrides = <String, String>{};
    final recentAttemptTime = DateTime(2026, 1, 1);

    // First run: attempted, recorded. One full miss queries both sources
    // (archive.org, then Open Library) — 2 calls.
    await LocalCoverBackfillService(
      db: db,
      store: BackfillAttemptStore(overrides: overrides),
      lookupService: lookupService(),
      now: () => recentAttemptTime,
    ).run();
    expect(callCount, equals(2));

    // Second run, 1 day later: skipped (within the 30-day window).
    await LocalCoverBackfillService(
      db: db,
      store: BackfillAttemptStore(overrides: overrides),
      lookupService: lookupService(),
      now: () => recentAttemptTime.add(const Duration(days: 1)),
    ).run();
    expect(callCount, equals(2));

    // Third run, 31 days later: retried (2 more calls).
    await LocalCoverBackfillService(
      db: db,
      store: BackfillAttemptStore(overrides: overrides),
      lookupService: lookupService(),
      now: () => recentAttemptTime.add(const Duration(days: 31)),
    ).run();
    expect(callCount, equals(4));
  });
}

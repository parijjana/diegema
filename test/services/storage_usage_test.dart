// ignore_for_file: prefer_const_constructors
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/downloads_location.dart';
import 'package:diegema/services/search_cache_store.dart';
import 'package:diegema/services/storage_usage.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/storage_section.dart';

import '../support/test_harness.dart';

void main() {
  late Directory tmp;
  late Directory library; // a user's library folder, outside the app's own
  late AppDatabase db;
  late Map<String, String> cacheMap;
  late SearchCacheStore cache;
  late DownloadsLocation downloads;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('storage_test_docs');
    library = await Directory.systemTemp.createTemp('storage_test_lib');
    db = AppDatabase(NativeDatabase.memory());
    cacheMap = {};
    cache = SearchCacheStore(overrides: cacheMap);
    downloads = DownloadsLocation(
        documentsRoot: () async => tmp.path, visibleRoot: () async => null);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
    await library.delete(recursive: true);
  });

  Future<File> write(String path, int bytes) async {
    final f = File(path);
    await f.create(recursive: true);
    await f.writeAsBytes(List.filled(bytes, 1));
    return f;
  }

  test('measures, and clears only caches and unused covers', () async {
    final covers = p.join(tmp.path, 'diegema', 'covers');
    final used = await write(p.join(covers, 'used.jpg'), 100);
    final orphan = await write(p.join(covers, 'orphan.jpg'), 50);
    final download = await write(
        p.join(tmp.path, 'diegema', 'downloads', 'b', '1.mp3'), 1000);
    final folderFile = await write(p.join(library.path, 'Book', '1.mp3'), 10);
    final folderCover =
        await write(p.join(library.path, 'Book', 'cover.jpg'), 10);
    cacheMap['discover.search_cache.v1'] = 'x' * 30;
    await db.saveAudiobook(UnifiedAudiobook(
        id: 'b',
        title: 'B',
        author: 'A',
        description: '',
        coverArtUrlOrPath: used.path));

    final usage = await measureStorage(db,
        documentsPath: tmp.path, downloads: downloads, searchCache: cache);
    expect(usage.downloads, 1000);
    expect(usage.covers, 150);
    expect(usage.searchCache, 30);
    expect(usage.clearable, 80);

    final freed =
        await clearCaches(db, documentsPath: tmp.path, searchCache: cache);
    expect(freed, 80);
    expect(await orphan.exists(), isFalse);
    expect(cacheMap.containsKey('discover.search_cache.v1'), isFalse);
    // Kept: a book's cover, downloads, and the user's library folder.
    expect(await used.exists(), isTrue);
    expect(await download.exists(), isTrue);
    expect(await folderFile.exists(), isTrue);
    expect(await folderCover.exists(), isTrue);
  });

  testWidgets('section shows sizes, clears, and fits 2.0x text',
      (tester) async {
    var usage = StorageUsage(
        downloads: 3 * 1024 * 1024,
        covers: 2048,
        searchCache: 512,
        clearable: 512);
    await setSurface(tester, Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StorageSection(
            db: db,
            measure: () async => usage,
            clear: () async {
              usage = StorageUsage(downloads: usage.downloads);
              return 512;
            },
          ),
        ),
      ),
    ));
    await pumpFrames(tester);
    expect(find.text('3.0 MB'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'Clear caches'))
            .height,
        greaterThanOrEqualTo(48));

    await tester.tap(find.text('Clear caches'));
    await pumpFrames(tester);
    expect(find.text('Cleared 512 B.'), findsOneWidget);
    expect(find.text('0 B'), findsNWidgets(2));
    expect(find.text('3.0 MB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

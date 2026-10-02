import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/library_locations_scanner.dart';
import 'package:diegema/services/library_locations_store.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/library_folders_section.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  UnifiedAudiobook book(String id, String path, String source) =>
      UnifiedAudiobook(
        id: id,
        title: id,
        author: 'A',
        description: '',
        source: source,
        origin: BookIdentity.originLocal,
        isDownloaded: true,
        chapters: [
          AudiobookChapter(
              id: '${id}_ch_0',
              title: 'c',
              audioPathOrUrl: path,
              durationSeconds: 0,
              isStream: false),
        ],
      );

  Future<void> pump(WidgetTester tester, LibraryLocationsStore store) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
          body: ListView(
              children: [LibraryFoldersSection(db: db, store: store)])),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('says so when there are no library folders', (tester) async {
    await pump(tester,
        LibraryLocationsStore(overrides: <String, List<String>>{}..clear()));
    expect(find.text('No library folders yet.'), findsOneWidget);
  });

  testWidgets('removing a folder forgets only its books, after confirming',
      (tester) async {
    final store =
        LibraryLocationsStore(overrides: <String, List<String>>{}..clear());
    await store.add('/sdcard/Audiobooks');
    await db.saveAudiobook(
        book('mine', '/sdcard/Audiobooks/Emma/01.mp3', kLibraryLocationSource));
    await db.saveAudiobook(
        book('other', '/sdcard/Elsewhere/01.mp3', kLibraryLocationSource));
    await db.saveAudiobook(
        book('copied', '/sdcard/Audiobooks/x.mp3', 'Local Folder'));

    await pump(tester, store);
    expect(find.text('Audiobooks'), findsOneWidget);
    expect(find.text('/sdcard/Audiobooks'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Audiobooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await store.read(), ['/sdcard/Audiobooks']);

    await tester.tap(find.byTooltip('Remove Audiobooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(await store.read(), isEmpty);
    final left = (await db.getAllAudiobooks()).map((b) => b.id).toSet();
    expect(left, {'other', 'copied'});
    expect(find.text('No library folders yet.'), findsOneWidget);
  });
}

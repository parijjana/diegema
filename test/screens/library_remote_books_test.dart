// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late AudioPlaybackService audio;
  late HiddenBooksStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioPlaybackService(db: db);
    store = HiddenBooksStore(overrides: <String, List<String>>{});
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  final records = [
    rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
    rec(SyncKind.device, 'pc', 'pc', 1, {'name': 'Desk PC'}),
    rec(SyncKind.catalogue, 'lv:emma', 'mac', 2, {
      'title': 'Emma',
      'author': 'Jane Austen',
      'origin': 'librivox',
      'archiveId': 'emma_librivox'
    }),
    rec(SyncKind.catalogue, 'lv:emma', 'pc', 3, {
      'title': 'Emma',
      'author': 'Jane Austen',
      'origin': 'librivox',
      'archiveId': 'emma_librivox'
    }),
    rec(SyncKind.catalogue, 'ck:dune', 'mac', 4,
        {'title': 'Dune', 'author': 'Frank Herbert', 'origin': 'local'}),
  ];

  Widget wrap({
    FakeSyncController? sync,
    void Function(String, String)? onOpen,
    void Function(BuildContext, AppDatabase, VoidCallback)? runner,
    double textScale = 1.0,
  }) {
    final app = MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: LibraryScreen(
          db: db,
          audioService: audio,
          onGoToDiscover: () {},
          hiddenStore: store,
          onOpenInDiscover: onOpen,
          importRunner: runner,
          scanLibrary: (db) async {},
        ),
      ),
    );
    return sync == null ? app : SyncScope(controller: sync, child: app);
  }

  Future<void> pumpLibrary(WidgetTester tester, Widget w,
      {bool withBook = true}) async {
    await setSurface(tester, const Size(390, 844));
    if (withBook) {
      await tester.runAsync(() => seedBook(db, id: 'a', title: 'Alpha Book'));
    }
    await tester.pumpWidget(w);
    await pumpFrames(tester);
  }

  testWidgets('no sync scope: no section at all', (tester) async {
    await pumpLibrary(tester, wrap());
    expect(find.text('Alpha Book'), findsOneWidget);
    expect(find.text('On your other devices'), findsNothing);
  });

  testWidgets('scope with no view yet: no section', (tester) async {
    final sync = FakeSyncController(records: records)..clearView();
    await pumpLibrary(tester, wrap(sync: sync));
    expect(find.text('On your other devices'), findsNothing);
  });

  testWidgets('nothing remote: no empty section', (tester) async {
    final sync = FakeSyncController(records: [records[0], records[2]]);
    sync.keys = {'a': 'lv:emma'}; // this device already has it
    await pumpLibrary(tester, wrap(sync: sync));
    expect(find.text('On your other devices'), findsNothing);
  });

  testWidgets('lists remote-only books with device names', (tester) async {
    final sync = FakeSyncController(records: records);
    await pumpLibrary(tester, wrap(sync: sync));

    expect(find.text('On your other devices'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Jane Austen'), findsOneWidget);
    expect(find.text('On Desk PC and 1 more'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('On MacBook'), findsOneWidget);
  });

  testWidgets('a book whose key is local is not listed; hidden keys neither',
      (tester) async {
    final sync = FakeSyncController(records: records, keys: {'a': 'ck:dune'});
    await store.hide('lv:emma');
    await pumpLibrary(tester, wrap(sync: sync));
    expect(find.text('On your other devices'), findsNothing);
  });

  testWidgets('a fresh device with an empty library still lists them',
      (tester) async {
    final sync = FakeSyncController(records: records);
    await pumpLibrary(tester, wrap(sync: sync), withBook: false);
    expect(find.text('Your library is empty'), findsNothing);
    expect(find.text('On your other devices'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
  });

  testWidgets('tapping a LibriVox book opens it in Discover by archive id',
      (tester) async {
    final sync = FakeSyncController(records: records);
    String? id, query;
    await pumpLibrary(
        tester,
        wrap(
            sync: sync,
            onOpen: (i, q) {
              id = i;
              query = q;
            }));
    await tester.tap(find.text('Emma'));
    await pumpFrames(tester);
    expect(id, 'emma_librivox');
    expect(query, 'Emma Jane Austen');
  });

  testWidgets('long-press hides it by portable key', (tester) async {
    final sync = FakeSyncController(records: records);
    await pumpLibrary(tester, wrap(sync: sync));
    await tester.longPress(find.text('Emma'));
    await pumpFrames(tester);
    await tester.tap(find.text('Hide from library'));
    await pumpFrames(tester);
    expect(await store.read(), {'lv:emma'});
    expect(find.text('Emma'), findsNothing);
    expect(find.text('Dune'), findsOneWidget);
  });

  group('manual book', () {
    Future<FakeSyncController> openSheet(WidgetTester tester,
        {required String importedKey}) async {
      final sync = FakeSyncController(records: records);
      var calls = 0;
      await pumpLibrary(
          tester,
          wrap(
            sync: sync,
            runner: (ctx, db, onSuccess) {
              calls++;
              seedBook(db, id: 'imported', title: 'Dune (mine)').then((_) {
                sync.keys['imported'] = importedKey;
                onSuccess();
              });
            },
          ));
      await tester.tap(find.text('Dune'));
      await pumpFrames(tester);
      expect(
          find.text('Dune is on MacBook. Add it to this device to listen '
              'here.'),
          findsOneWidget);
      expect(calls, 0, reason: 'the sheet alone imports nothing');
      await tester.tap(find.text('Add to this device'));
      await pumpFrames(tester);
      expect(calls, 1);
      return sync;
    }

    testWidgets('same key: linked automatically', (tester) async {
      final sync = await openSheet(tester, importedKey: 'ck:dune');
      expect(find.text('Linked with MacBook'), findsOneWidget);
      expect(find.text('Different copy'), findsNothing);
      expect(sync.links, isEmpty);
      expect(sync.refreshCalls, greaterThan(0));
      // It is local now, so no longer "on another device".
      expect(find.text('On MacBook'), findsNothing);
    });

    testWidgets('different key: Keep separate leaves it unlinked',
        (tester) async {
      final sync = await openSheet(tester, importedKey: 'ck:other');
      expect(
          find.text('This looks like a different copy of Dune. Link it '
              'anyway?'),
          findsOneWidget);
      await tester.tap(find.text('Keep separate'));
      await pumpFrames(tester);
      expect(sync.links, isEmpty);
      expect(find.text('Linked with MacBook'), findsNothing);
    });

    testWidgets('different key: Link anyway links it to the remote key',
        (tester) async {
      final sync = await openSheet(tester, importedKey: 'ck:other');
      await tester.tap(find.text('Link anyway'));
      await pumpFrames(tester);
      expect(sync.links, [('imported', 'ck:dune')]);
      expect(find.text('Linked with MacBook'), findsOneWidget);
    });
  });

  testWidgets('no overflow at 2.0 text scale, phone width', (tester) async {
    final sync = FakeSyncController(records: records);
    await pumpLibrary(tester, wrap(sync: sync, textScale: 2.0));
    await tester.scrollUntilVisible(find.text('Dune'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}

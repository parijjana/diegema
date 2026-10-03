// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/library_book_detail_overlay.dart';
import 'package:diegema/widgets/library_tiles.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/test_harness.dart';

/// The Library's tile (grid) layout and the setting that switches to it.
void main() {
  late AppDatabase db;
  late AudioPlaybackService audio;
  late HiddenBooksStore store;
  late Map<String, Object> prefsStore;
  late AppSettings settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioPlaybackService(db: db);
    store = HiddenBooksStore(overrides: <String, List<String>>{});
    prefsStore = <String, Object>{};
    settings = AppSettings(preferences: UiPreferences(overrides: prefsStore));
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  final records = [
    rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
    rec(SyncKind.catalogue, 'ck:dune', 'mac', 4,
        {'title': 'Dune', 'author': 'Frank Herbert', 'origin': 'local'}),
  ];

  Widget wrap({double textScale = 1.0, FakeSyncController? sync}) {
    final app = SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: LibraryScreen(
            db: db,
            audioService: audio,
            onGoToDiscover: () {},
            hiddenStore: store,
            scanLibrary: (db) async {
              await seedBook(db,
                  id: 'started',
                  title: 'Started Book',
                  runtimeSeconds: 1000,
                  positionSeconds: 500);
              await seedBook(db,
                  id: 'long',
                  title: 'A Very Long Audiobook Title That Must Wrap Onto '
                      'Several Lines And Then Be Cut Off Politely');
            },
          ),
        ),
      ),
    );
    return sync == null ? app : SyncScope(controller: sync, child: app);
  }

  Future<void> pump(WidgetTester tester, Widget w,
      {Size size = const Size(390, 844)}) async {
    await setSurface(tester, size);
    await tester.pumpWidget(w);
    await pumpFrames(tester);
  }

  testWidgets(
      'defaults to the list; the header toggle switches to tiles and '
      'persists by name', (tester) async {
    await pump(tester, wrap());
    expect(find.byType(LibraryTile), findsNothing);
    expect(find.byTooltip('Show as tiles'), findsOneWidget);

    await tester.tap(find.byTooltip('Show as tiles'));
    await pumpFrames(tester);
    expect(find.byType(LibraryTile), findsWidgets);
    expect(find.byTooltip('Show as list'), findsOneWidget);
    expect(prefsStore['library.layout'], 'tiles');

    await tester.tap(find.byTooltip('Show as list'));
    await pumpFrames(tester);
    expect(find.byType(LibraryTile), findsNothing);
    expect(prefsStore['library.layout'], 'list');
  });

  test('an unknown stored value falls back to list; a known one loads',
      () async {
    final bad = AppSettings(
        preferences:
            const UiPreferences(overrides: {'library.layout': 'carousel'}));
    await bad.load();
    expect(bad.libraryLayout, LibraryLayout.list);

    final good = AppSettings(
        preferences:
            const UiPreferences(overrides: {'library.layout': 'tiles'}));
    await good.load();
    expect(good.libraryLayout, LibraryLayout.tiles);
  });

  testWidgets('tiles render title, author and progress', (tester) async {
    await settings.setLibraryLayout(LibraryLayout.tiles);
    await pump(tester, wrap());

    // In progress section + All books section.
    expect(find.text('Started Book'), findsNWidgets(2));
    expect(find.text('Author started'), findsNWidgets(2));
    expect(find.text('50% listened'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('1 chapter'), findsOneWidget); // the untouched book
    // Header and section titles are still there, full width.
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('All books'), findsOneWidget);
  });

  testWidgets('each tile is one semantics node with title, author, progress',
      (tester) async {
    await settings.setLibraryLayout(LibraryLayout.tiles);
    await pump(tester, wrap());
    final handle = tester.ensureSemantics();
    expect(
        find.bySemanticsLabel(
            'View details for Started Book, 50% complete, by Author started'),
        findsNWidgets(2));
    handle.dispose();
  });

  testWidgets('tap and long-press do what the rows do', (tester) async {
    await settings.setLibraryLayout(LibraryLayout.tiles);
    await pump(tester, wrap());

    await tester.tap(find.text('Started Book').first);
    await pumpFrames(tester);
    expect(find.byType(LibraryBookDetailOverlay), findsOneWidget);
  });

  testWidgets('long-press on a tile offers Hide from library', (tester) async {
    await settings.setLibraryLayout(LibraryLayout.tiles);
    await pump(tester, wrap());

    await tester.longPress(find.textContaining('A Very Long'));
    await pumpFrames(tester);
    await tester.tap(find.text('Hide from library'));
    await pumpFrames(tester);
    expect(await store.read(), {'long'});
    expect(find.textContaining('A Very Long'), findsNothing);
  });

  testWidgets('"On your other devices" renders as dimmed tiles',
      (tester) async {
    await settings.setLibraryLayout(LibraryLayout.tiles);
    final sync = FakeSyncController(records: records);
    await pump(tester, wrap(sync: sync), size: const Size(390, 1600));

    expect(find.text('On your other devices'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Frank Herbert'), findsOneWidget);
    expect(find.text('On MacBook'), findsOneWidget);
    expect(
        find.ancestor(
            of: find.text('Dune'), matching: find.byType(LibraryTile)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('Dune'), matching: find.byType(LibraryTile)),
            matching: find.byType(Opacity)),
        findsWidgets);
  });

  group('column count', () {
    test('phone and desktop widths', () {
      expect(libraryTileMetrics(328).columns, 2); // 360 phone minus gutters
      expect(libraryTileMetrics(358).columns, 2); // 390 phone
      expect(libraryTileMetrics(1000).columns, 6);
      for (final w in [328.0, 358.0, 700.0, 1000.0, 1400.0]) {
        final t = libraryTileMetrics(w).tileWidth;
        expect(t, inInclusiveRange(140, 190), reason: 'width $w');
      }
    });

    testWidgets('rendered rows use them', (tester) async {
      await settings.setLibraryLayout(LibraryLayout.tiles);
      await pump(tester, wrap(), size: const Size(360, 800));
      // 3 distinct tiles in the All books section + 1 in progress; two per
      // row on a phone means the first two share a top edge.
      final tops = tester
          .widgetList<LibraryTile>(find.byType(LibraryTile))
          .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
          .toList();
      expect(tops.length, 3);
      expect(tops[1], tops[2]); // the two "All books" tiles share a row
      expect(tops[0], lessThan(tops[1]));

      await pump(tester, wrap(), size: const Size(1200, 800));
      final wideTops = tester
          .widgetList<LibraryTile>(find.byType(LibraryTile))
          .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
          .toList();
      expect(wideTops[1], wideTops[2]);
    });
  });

  for (final size in const [Size(360, 800), Size(1200, 800)]) {
    testWidgets('no overflow at 2.0x text scale, ${size.width.toInt()} wide',
        (tester) async {
      await settings.setLibraryLayout(LibraryLayout.tiles);
      final sync = FakeSyncController(records: records);
      await pump(tester, wrap(textScale: 2.0, sync: sync),
          size: Size(size.width, 2400));
      expect(tester.takeException(), isNull);
      expect(find.byType(LibraryTile), findsWidgets);
    });
  }

  testWidgets('keyboard focus shows a ring on the tile', (tester) async {
    await settings.setLibraryLayout(LibraryLayout.tiles);
    await pump(tester, wrap(), size: const Size(1200, 800));
    final tile = find.byType(LibraryTile).first;
    BoxDecoration deco() => tester
        .widget<Ink>(find.descendant(of: tile, matching: find.byType(Ink)))
        .decoration! as BoxDecoration;
    expect((deco().border! as Border).top.width, 1);
    // Tab through the focus order until the first tile takes focus.
    for (var i = 0; i < 12 && (deco().border! as Border).top.width != 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect((deco().border! as Border).top.width, 2);
  });
}

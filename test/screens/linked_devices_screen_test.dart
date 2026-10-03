// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/hidden_books_screen.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

void main() {
  late FakePlaybackService audio;

  setUp(() {
    audio = FakePlaybackService();
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
  });

  final others = [
    rec(SyncKind.device, 'mac', 'mac', 1,
        {'name': 'MacBook', 'platform': 'macos'}),
    rec(SyncKind.device, 'pc', 'pc', 2, {'name': 'Desk PC'}),
    rec(SyncKind.catalogue, 'ck:x', 'phone2', 3, {'title': 'Dune'}),
  ];

  Future<void> pumpSettings(
    WidgetTester tester,
    FakeSyncController? sync, {
    double textScale = 1.0,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await setSurface(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(AudiobookApp(
      database: db,
      audioService: audio,
      sync: sync,
      libriVoxService: LibriVoxService(
        client: MockClient((r) async => http.Response('Not Found', 404)),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
      ),
      preferences: const UiPreferences(overrides: <String, Object>{}),
    ));
    await pumpFrames(tester);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Settings')));
    await pumpFrames(tester);
  }

  Future<void> openLinkedDevices(WidgetTester tester) async {
    final row = find.text('Linked devices');
    await tester.scrollUntilVisible(row, 120,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(row);
    await pumpFrames(tester);
    await tester.tap(row);
    await pumpFrames(tester);
  }

  testWidgets('without sync there is no Linked devices row', (tester) async {
    await pumpSettings(tester, null);
    await tester.scrollUntilVisible(find.text('Hidden books'), 120,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Hidden books'), findsOneWidget);
    expect(find.text('Linked devices'), findsNothing);
    await unmount(tester);
  });

  testWidgets('empty: this device and "No other devices yet."', (tester) async {
    await pumpSettings(tester, FakeSyncController());
    await openLinkedDevices(tester);

    expect(find.text('This device'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'This phone'), findsOneWidget);
    expect(find.text('Other devices'), findsOneWidget);
    expect(find.text('No other devices yet.'), findsOneWidget);
    expect(find.text('Save name'), findsNothing);
    await unmount(tester);
  });

  testWidgets('lists the other devices with name and platform', (tester) async {
    await pumpSettings(tester, FakeSyncController(records: others));
    await openLinkedDevices(tester);

    expect(find.text('No other devices yet.'), findsNothing);
    expect(find.text('MacBook'), findsOneWidget);
    expect(find.text('macOS'), findsOneWidget);
    expect(find.text('Desk PC'), findsOneWidget);
    // Seen only through its books: still listed, under a fallback name.
    expect(find.text('Device phon'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('renaming this device saves through the controller',
      (tester) async {
    final sync = FakeSyncController();
    await pumpSettings(tester, sync);
    await openLinkedDevices(tester);

    await tester.enterText(find.byType(TextField), '  Kitchen tablet ');
    await pumpFrames(tester);
    await tester.tap(find.text('Save name'));
    await pumpFrames(tester);

    expect(sync.name, 'Kitchen tablet');
    expect(find.text('Save name'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no overflow at 2.0 text scale', (tester) async {
    await pumpSettings(tester, FakeSyncController(records: others),
        textScale: 2.0);
    await openLinkedDevices(tester);
    await tester.enterText(find.byType(TextField), 'A much longer device name');
    await pumpFrames(tester);
    expect(find.text('Other devices'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final tap = tester.getSize(find.widgetWithText(TextButton, 'Save name'));
    expect(tap.height, greaterThanOrEqualTo(48));
    await unmount(tester);
  });

  testWidgets('Hidden books names a book hidden only by its portable key',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = HiddenBooksStore(overrides: <String, List<String>>{});
    await store.hide('ck:x');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(SyncScope(
      controller: FakeSyncController(records: others),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: HiddenBooksScreen(db: db, store: store),
      ),
    ));
    await pumpFrames(tester);

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('ck:x'), findsNothing);
    await tester.tap(find.text('Unhide'));
    await pumpFrames(tester);
    expect(await store.read(), isEmpty);
  });
}

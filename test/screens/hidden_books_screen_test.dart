// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/hidden_books_screen.dart';
import 'package:diegema/screens/settings_screen.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/theme/app_theme.dart';

import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late HiddenBooksStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = HiddenBooksStore(overrides: <String, List<String>>{});
  });

  tearDown(() => db.close());

  Widget wrap({double textScale = 1.0}) => MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: HiddenBooksScreen(db: db, store: store),
      );

  testWidgets('shows the empty state', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('No hidden books'), findsOneWidget);
    expect(find.text('Unhide'), findsNothing);
  });

  testWidgets('lists hidden books with title and author; Unhide removes one',
      (tester) async {
    await seedBook(db, id: 'a', title: 'Alpha Book');
    await seedBook(db, id: 'b', title: 'Beta Book');
    await store.hide('a');
    await store.hide('b');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('Alpha Book'), findsOneWidget);
    expect(find.text('Beta Book'), findsOneWidget);
    expect(find.text('Unhide'), findsNWidgets(2));

    await tester.tap(find.text('Unhide').first);
    await pumpFrames(tester);

    expect(await store.read(), {'b'});
    expect(find.text('Alpha Book'), findsNothing);
    expect(find.text('Beta Book'), findsOneWidget);

    await tester.tap(find.text('Unhide'));
    await pumpFrames(tester);
    expect(find.text('No hidden books'), findsOneWidget);
  });

  testWidgets('an id missing from the database is dimmed and still unhides',
      (tester) async {
    await store.hide('gone-id');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('gone-id'), findsOneWidget);
    await tester.tap(find.text('Unhide'));
    await pumpFrames(tester);

    expect(await store.read(), isEmpty);
    expect(find.text('No hidden books'), findsOneWidget);
  });

  testWidgets('no overflow at 2.0 text scale, list and empty', (tester) async {
    await seedBook(db,
        id: 'a',
        title: 'A Very Long Audiobook Title That Wraps Over Several Lines');
    await store.hide('a');
    await store.hide('some-long-portable-key-that-is-not-in-the-database');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(textScale: 2.0));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Unhide').first);
    await pumpFrames(tester);
    await tester.tap(find.text('Unhide').first);
    await pumpFrames(tester);
    expect(find.text('No hidden books'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unhide button meets the 48dp tap target', (tester) async {
    await store.hide('x');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    final size = tester.getSize(find.widgetWithText(TextButton, 'Unhide'));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('Settings has a Hidden books row that opens the screen',
      (tester) async {
    await store.hide('x');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(SettingsScope(
      settings: AppSettings(preferences: UiPreferences(overrides: {})),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SettingsScreen(db: db)),
      ),
    ));
    await pumpFrames(tester);

    final row = find.text('Hidden books');
    await tester.scrollUntilVisible(row, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(row);
    await pumpFrames(tester);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.byType(HiddenBooksScreen), findsOneWidget);
  });
}

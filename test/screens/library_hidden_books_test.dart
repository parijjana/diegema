// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/theme/app_theme.dart';

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

  Widget wrap() => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryScreen(
            db: db,
            audioService: audio,
            onGoToDiscover: () {},
            hiddenStore: store,
            scanLibrary: (db) async {
              if (await db.getAllAudiobooks().then((b) => b.isNotEmpty)) {
                return;
              }
              await seedBook(db,
                  id: 'a',
                  title: 'Alpha Book',
                  runtimeSeconds: 1000,
                  positionSeconds: 500);
              await seedBook(db, id: 'b', title: 'Beta Book');
            },
          ),
        ),
      );

  testWidgets('a hidden book is not shown, in any section', (tester) async {
    await store.hide('a');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('Alpha Book'), findsNothing);
    expect(find.text('In progress'), findsNothing);
    expect(find.text('Beta Book'), findsOneWidget);
    expect(find.text('Library (1 book)'), findsOneWidget);
  });

  testWidgets('hiding from the detail menu removes it; Undo brings it back',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    await tester.tap(find.text('Beta Book'));
    await pumpFrames(tester);
    await tester.tap(find.byTooltip('More actions'));
    await pumpFrames(tester);
    await tester.tap(find.text('Hide from library'));
    await pumpFrames(tester);

    expect(await store.read(), {'b'});
    expect(find.text('Beta Book'), findsNothing);
    expect(find.text('Hidden'), findsOneWidget);
    // Hiding is not removal: the row is still in the database.
    expect(await db.getAllAudiobooks(), hasLength(2));

    await tester.tap(find.text('Undo'));
    await pumpFrames(tester);

    expect(await store.read(), isEmpty);
    expect(find.text('Beta Book'), findsOneWidget);
  });

  testWidgets('long-press offers Hide from library', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    await tester.longPress(find.text('Beta Book'));
    await pumpFrames(tester);
    await tester.tap(find.text('Hide from library'));
    await pumpFrames(tester);

    expect(await store.read(), {'b'});
    expect(find.text('Beta Book'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('hiding every book explains where to unhide', (tester) async {
    await store.hide('a');
    await store.hide('b');
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('All your books are hidden'), findsOneWidget);
  });
}

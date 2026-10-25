// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/theme/app_theme.dart';

import '../support/test_harness.dart';

UnifiedAudiobook _book(String id, String title, String author,
        {String origin = 'librivox', bool downloaded = true}) =>
    UnifiedAudiobook(
        id: id,
        title: title,
        author: author,
        description: '',
        origin: origin,
        isDownloaded: downloaded);

void main() {
  group('applyLibraryView', () {
    final a = _book('a', 'banana', 'Zed');
    final b = _book('b', 'Apple', 'Yan', origin: 'local');
    final c = _book('c', 'Cherry', 'Xu', downloaded: false);
    final books = [a, b, c];
    final stats = {
      'a': LibraryBookStats(
          lastPlayed: DateTime(2026, 1, 1), fraction: 0.5, finished: false),
      'b': LibraryBookStats(
          lastPlayed: DateTime(2026, 2, 1), fraction: 1, finished: true),
    };
    List<String> ids(LibrarySort s, LibraryFilter f) => applyLibraryView(books,
            sort: s, filter: f, stats: stats, inProgressIds: {'a'})
        .map((x) => x.id)
        .toList();

    test('sorts', () {
      expect(ids(LibrarySort.recent, LibraryFilter.all), ['b', 'a', 'c']);
      expect(ids(LibrarySort.title, LibraryFilter.all), ['b', 'a', 'c']);
      expect(ids(LibrarySort.author, LibraryFilter.all), ['c', 'b', 'a']);
      expect(ids(LibrarySort.progress, LibraryFilter.all), ['b', 'a', 'c']);
    });

    test('filters', () {
      expect(ids(LibrarySort.recent, LibraryFilter.inProgress), ['a']);
      expect(ids(LibrarySort.recent, LibraryFilter.finished), ['b']);
      // LibriVox downloads only: local 'b' is on the device but is Local.
      expect(ids(LibrarySort.recent, LibraryFilter.downloaded), ['a']);
      expect(ids(LibrarySort.recent, LibraryFilter.local), ['b']);
    });
  });

  test('sort and filter persist by name; unknown names fall back', () async {
    final store = <String, Object>{};
    final s = AppSettings(preferences: UiPreferences(overrides: store));
    await s.setLibrarySort(LibrarySort.author);
    await s.setLibraryFilter(LibraryFilter.finished);
    expect(store['library.sort'], 'author');
    expect(store['library.filter'], 'finished');

    final bad = AppSettings(
        preferences: UiPreferences(
            overrides: {'library.sort': 'x', 'library.filter': 'y'}));
    await bad.load();
    expect(bad.librarySort, LibrarySort.recent);
    expect(bad.libraryFilter, LibraryFilter.all);
  });

  group('screen', () {
    late AppDatabase db;
    late AudioPlaybackService audio;
    late HiddenBooksStore hidden;
    late AppSettings settings;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      audio = AudioPlaybackService(db: db);
      hidden = HiddenBooksStore(overrides: <String, List<String>>{});
      settings = AppSettings(
          preferences: UiPreferences(overrides: <String, Object>{}));
    });

    tearDown(() async {
      await audio.dispose().catchError((_) {});
      await db.close();
    });

    Widget wrap({double textScale = 1.0}) => SettingsScope(
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
                hiddenStore: hidden,
                scanLibrary: (db) async {
                  await seedBook(db,
                      id: 'prog',
                      title: 'Mid Book',
                      runtimeSeconds: 1000,
                      positionSeconds: 500);
                  await seedBook(db, id: 'fresh', title: 'Fresh Book');
                  await seedBook(db, id: 'done', title: 'Done Book');
                  await db.markFinished('done', lastChapterIndex: 0);
                  await db.saveAudiobook(
                      _book('loc', 'Local Book', 'Me', origin: 'local'));
                },
              ),
            ),
          ),
        );

    Future<void> pump(WidgetTester tester, Widget w,
        {Size size = const Size(390, 844)}) async {
      await setSurface(tester, size);
      await tester.pumpWidget(w);
      await pumpFrames(tester);
    }

    Future<void> chip(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await pumpFrames(tester);
    }

    testWidgets('filters in list layout, phone', (tester) async {
      await pump(tester, wrap());
      await chip(tester, 'Finished');
      expect(find.text('Done Book'), findsOneWidget);
      expect(find.text('Fresh Book'), findsNothing);
      await chip(tester, 'Local');
      expect(find.text('Local Book'), findsOneWidget);
      expect(find.text('Done Book'), findsNothing);
      expect(settings.libraryFilter, LibraryFilter.local);
    });

    testWidgets('filters in tiles layout, wide', (tester) async {
      await settings.setLibraryLayout(LibraryLayout.tiles);
      await pump(tester, wrap(), size: const Size(1200, 800));
      await chip(tester, 'In progress');
      expect(find.text('Mid Book'), findsOneWidget);
      expect(find.text('Fresh Book'), findsNothing);
    });

    testWidgets('empty filter shows a clear state and a way out',
        (tester) async {
      await pump(tester, wrap());
      await hidden.hide('done');
      await pumpFrames(tester);
      await chip(tester, 'Finished');
      expect(find.text('No finished books'), findsOneWidget);
      // Hidden books stay hidden whatever the filter.
      expect(find.text('Done Book'), findsNothing);
      await tester.tap(find.text('Show all books'));
      await pumpFrames(tester);
      expect(settings.libraryFilter, LibraryFilter.all);
      expect(find.text('Fresh Book'), findsOneWidget);
      expect(find.text('Done Book'), findsNothing);
    });

    testWidgets('sort menu reorders and persists', (tester) async {
      await pump(tester, wrap());
      await tester.tap(find.text('Sort: Recent'));
      await pumpFrames(tester);
      await tester.tap(find.text('Title').last);
      await pumpFrames(tester);
      expect(settings.librarySort, LibrarySort.title);
      final done = tester.getTopLeft(find.text('Done Book')).dy;
      final fresh = tester.getTopLeft(find.text('Fresh Book')).dy;
      expect(done < fresh, isTrue);
    });

    testWidgets('controls are 48dp and nothing overflows at 2.0x text',
        (tester) async {
      await pump(tester, wrap(textScale: 2.0));
      expect(tester.takeException(), isNull);
      for (final f in LibraryFilter.values) {
        final h =
            tester.getSize(find.widgetWithText(ChoiceChip, f.label)).height;
        expect(h, greaterThanOrEqualTo(47.5), reason: f.label);
      }
    });
  });
}

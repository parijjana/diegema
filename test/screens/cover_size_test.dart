import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/screens/now_playing_screen.dart';
import 'package:diegema/services/ambience_service.dart';
import 'package:diegema/widgets/app_book_cover.dart';

import '../services/ambience_service_test.dart' show FakeChannel;
import '../support/fake_playback_service.dart';
import '../support/golden_fonts.dart';
import '../support/test_harness.dart';

const _sizes = <String, Size>{
  '360x800': Size(360, 800),
  '411x914': Size(411, 914),
  '430x932': Size(430, 932),
};

UnifiedAudiobook _book() => UnifiedAudiobook(
      id: 'riddle',
      title: 'Harry Potter and the Goblet of Fire',
      author: 'J. K. Rowling',
      description: 'd',
      source: 'LibriVox',
      origin: 'librivox',
      chapters: [
        for (var i = 0; i < 40; i++)
          AudiobookChapter(
            id: 'c$i',
            title: i == 0 ? 'Chapter 1: The Riddle House' : 'Chapter ${i + 1}',
            audioPathOrUrl: 'https://example.invalid/$i.mp3',
            durationSeconds: 600,
            isStream: true,
          ),
      ],
    );

void main() {
  late FakePlaybackService audio;
  setUpAll(loadGoldenFonts);
  setUp(() => audio = FakePlaybackService());
  tearDown(() async => audio.dispose().catchError((_) {}));

  group('CoverSize preference', () {
    test('defaults to large; unknown names fall back', () {
      expect(CoverSize.fromName(null), CoverSize.large);
      expect(CoverSize.fromName('huge'), CoverSize.large);
      expect(CoverSize.fromName('stamp'), CoverSize.stamp);
      expect(CoverSize.large.next, CoverSize.medium);
      expect(CoverSize.medium.next, CoverSize.stamp);
      expect(CoverSize.stamp.next, CoverSize.large);
    });

    test('persists by name and reloads', () async {
      final store = <String, Object>{};
      final a = AppSettings(preferences: UiPreferences(overrides: store));
      await a.setCoverSize(CoverSize.medium);
      expect(store['appearance.cover_size'], 'medium');
      final b = AppSettings(preferences: UiPreferences(overrides: store));
      await b.load();
      expect(b.coverSize, CoverSize.medium);
      store['appearance.cover_size'] = 'bogus';
      final c = AppSettings(preferences: UiPreferences(overrides: store));
      await c.load();
      expect(c.coverSize, CoverSize.large);
    });
  });

  test('chapter labels keep position and title apart', () {
    expect(chapterPositionLabel(0, 40), 'Chapter 1 of 40');
    expect(chapterNameOf('Chapter 1: The Riddle House'), 'The Riddle House');
    expect(chapterNameOf('Chapter 2'), isNull);
    expect(chapterNameOf('Prologue'), 'Prologue');
  });

  Future<Map<String, Object>> pump(
      WidgetTester tester, Size size, double scale, CoverSize cover) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = <String, Object>{'appearance.cover_size': cover.name};
    final ambience = AmbienceService(
      book: audio,
      preferences: const UiPreferences(overrides: <String, Object>{}),
      channelFactory: FakeChannel.new,
      fade: Duration.zero,
      useAudioSession: false,
    );
    await setSurface(tester, size);
    await tester.pumpWidget(AudiobookApp(
      initialThemeMode: ThemeMode.light,
      database: db,
      audioService: audio,
      preferences: UiPreferences(overrides: store),
      ambience: ambience,
    ));
    await pumpFrames(tester);
    final book = _book();
    await db.saveAudiobook(book);
    await audio.loadBook(book);
    await pumpFrames(tester);
    return store;
  }

  for (final cover in CoverSize.values) {
    for (final e in _sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${cover.name} fits at ${e.key} x$scale', (tester) async {
          await pump(tester, e.value, scale, cover);
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Chapter 1 of 40'), findsOneWidget);
          expect(find.textContaining('The Riddle House of'), findsNothing);
          expect(find.textContaining('The Riddle House'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('medium shows chapter details and time left', (tester) async {
    await pump(tester, _sizes['411x914']!, 1.0, CoverSize.medium);
    expect(find.byKey(const Key('chapter_position')), findsOneWidget);
    expect(find.byKey(const Key('chapter_name')), findsOneWidget);
    expect(find.byKey(const Key('chapter_left')), findsOneWidget);
    final bookLeft = tester.widget<Text>(find.byKey(const Key('book_left')));
    expect(bookLeft.data, endsWith('left in book'));
  });

  testWidgets('stamp has a small rounded cover and a reclaimed region',
      (tester) async {
    await pump(tester, _sizes['411x914']!, 1.0, CoverSize.stamp);
    expect(find.byKey(const Key('reclaimed_space')), findsOneWidget);
    final cover = tester.getSize(find.byType(AppBookCover).last);
    expect(cover.width, inInclusiveRange(56, 72));
    expect(find.byType(ClipRRect), findsWidgets);
    expect(tester.getSize(find.byKey(const Key('reclaimed_space'))).height,
        greaterThan(100));
  });

  testWidgets('large has no reclaimed region', (tester) async {
    await pump(tester, _sizes['411x914']!, 1.0, CoverSize.large);
    expect(find.byKey(const Key('reclaimed_space')), findsNothing);
  });

  testWidgets('long-press on the cover cycles and persists', (tester) async {
    final store = await pump(tester, _sizes['411x914']!, 1.0, CoverSize.large);
    for (final expected in ['medium', 'stamp', 'large']) {
      await tester.longPress(find.byType(AppBookCover).last);
      await pumpFrames(tester);
      expect(store['appearance.cover_size'], expected);
      expect(find.text('Cover size: '
          '${CoverSize.fromName(expected).label}'), findsOneWidget);
    }
  });
}

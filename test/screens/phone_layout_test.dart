import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/ambience_service.dart';

import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/screens/discover_screen.dart';
import 'package:diegema/services/artwork_enrichment_service.dart';
import 'package:diegema/services/librivox_downloader.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/librivox_book_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../services/ambience_service_test.dart' show FakeChannel;
import '../support/fake_playback_service.dart';
import '../support/golden_fonts.dart';
import '../support/test_harness.dart';

/// Regression tests for the phone layout bugs the v1 store screenshots
/// exposed. Sizes: 360x800 (narrowest supported), 411x914 (Play 1080x2400)
/// and 430x932 (iPhone 1290x2796).
const phoneSizes = <String, Size>{
  '360x800': Size(360, 800),
  '411x914': Size(411, 914),
  '430x932': Size(430, 932),
};

void main() {
  late FakePlaybackService audio;
  // Real Inter, not the test font whose glyphs are all one em wide.
  setUpAll(loadGoldenFonts);
  setUp(() => audio = FakePlaybackService());
  tearDown(() async => audio.dispose().catchError((_) {}));

  Future<AppDatabase> pumpApp(WidgetTester tester, Size size, double scale,
      {Map<String, Object> prefs = const <String, Object>{}}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
      preferences: UiPreferences(overrides: prefs),
      ambience: ambience,
    ));
    await pumpFrames(tester);
    return db;
  }

  group('bottom nav labels', () {
    for (final e in phoneSizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('never wrap at ${e.key} x$scale', (tester) async {
          await pumpApp(tester, e.value, scale);
          expect(tester.takeException(), isNull);
          final bar = find.byType(NavigationBar);
          final texts = find.descendant(of: bar, matching: find.byType(Text));
          for (final t in texts.evaluate()) {
            // Hidden labels stay in the tree at opacity 0; they are not
            // visible, so they cannot be a visible wrap.
            final fade = find.ancestor(
                of: find.byWidget(t.widget),
                matching: find.byType(FadeTransition));
            if (fade
                .evaluate()
                .any((e) => (e.widget as FadeTransition).opacity.value == 0)) {
              continue;
            }
            final ro = t.renderObject! as RenderParagraph;
            expect(ro.didExceedMaxLines, isFalse);
            // One line: height under 1.6 line-heights of the scaled font.
            final size = (ro.text.style?.fontSize ?? 12) * scale;
            expect(ro.size.height, lessThan(size * 1.6),
                reason: '"${(t.widget as Text).data}" wrapped');
          }
          if (scale == 1.0) {
            // Not simply hidden: at normal text size the labels show.
            final lib =
                find.descendant(of: bar, matching: find.text('Library'));
            expect(lib, findsOneWidget);
            final fade =
                find.ancestor(of: lib, matching: find.byType(FadeTransition));
            expect(
                fade.evaluate().every(
                    (e) => (e.widget as FadeTransition).opacity.value > 0),
                isTrue);
          }
          // Tiles stay reachable at 48dp whatever the labels do.
          final dests = find.descendant(
              of: bar, matching: find.byType(NavigationDestination));
          expect(dests, findsNWidgets(5));
          for (final d in dests.evaluate()) {
            final r = tester.getRect(find.byWidget(d.widget));
            expect(r.width, greaterThanOrEqualTo(48));
            expect(r.height, greaterThanOrEqualTo(48));
          }
          await unmount(tester);
        });
      }
    }
  });

  group('Now Playing action row', () {
    for (final style in ['tiles', 'round', 'bar']) {
      for (final e in phoneSizes.entries) {
        for (final scale in [1.0, 1.3, 2.0]) {
          testWidgets('all four read in full: $style ${e.key} x$scale',
              (tester) async {
            final db = await pumpApp(tester, e.value, scale,
                prefs: {'now_playing.controls_style': style});
            final book = await seedBook(db, id: 'z', title: 'Persuasion');
            await audio.loadBook(book);
            await pumpFrames(tester);
            expect(tester.takeException(), isNull);

            // The row's labels: stable words in every style.
            final labels = [
              'Up next',
              style == 'tiles' ? 'Speed' : '1.0x',
              'Sleep',
              'Marks',
            ];
            final slots = <Rect>[];
            for (final label in labels) {
              final f = find.text(label);
              expect(f, findsOneWidget, reason: label);
              final ro = tester.renderObject<RenderParagraph>(f);
              expect(ro.didExceedMaxLines, isFalse,
                  reason: '"$label" is cut off');
              // No word broken across lines: the box is at least as wide
              // as the longest word.
              expect(
                  ro.size.width + 0.5,
                  greaterThanOrEqualTo(
                      ro.getMinIntrinsicWidth(double.infinity)),
                  reason: '"$label" is narrower than its longest word');
              final slot = find.ancestor(of: f, matching: find.byType(InkWell));
              final r = tester.getRect(slot.first);
              expect(r.width, greaterThanOrEqualTo(48));
              expect(r.height, greaterThanOrEqualTo(48));
              final t = tester.getRect(f);
              expect(t.left, greaterThanOrEqualTo(r.left - 0.5),
                  reason: '"$label" spills left of its button');
              expect(t.right, lessThanOrEqualTo(r.right + 0.5),
                  reason: '"$label" spills right of its button');
              expect(t.bottom, lessThanOrEqualTo(r.bottom + 0.5),
                  reason: '"$label" spills below its button');
              slots.add(r);
            }
            for (var i = 0; i < slots.length; i++) {
              for (var j = i + 1; j < slots.length; j++) {
                expect(slots[i].overlaps(slots[j]), isFalse,
                    reason: 'buttons $i and $j overlap');
              }
            }
            await unmount(tester);
          });
        }
      }
    }
  });

  Future<void> openLibrary(WidgetTester tester, Size size, double scale,
      {required String layout, int books = 6}) async {
    final db =
        await pumpApp(tester, size, scale, prefs: {'library.layout': layout});
    for (var i = 0; i < books; i++) {
      await seedBook(db, id: 'b$i', title: 'Book number $i');
    }
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.byTooltip('Library')));
    await pumpFrames(tester);
  }

  group('Library', () {
    for (final layout in ['list', 'tiles']) {
      for (final e in phoneSizes.entries) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('Import button covers no book: $layout ${e.key} x$scale',
              (tester) async {
            await openLibrary(tester, e.value, scale, layout: layout);
            expect(tester.takeException(), isNull);
            final fab = tester.getRect(find
                .ancestor(
                    of: find.text('Import a book'),
                    matching: find.byType(InkWell))
                .first);
            expect(fab.height, greaterThanOrEqualTo(48));
            final list = tester.getRect(find.byType(CustomScrollView).first);
            expect(list.overlaps(fab), isFalse,
                reason: 'the button sits over the scrolling list');
            void expectClear(String when) {
              for (final t in find.textContaining('Book number').evaluate()) {
                // Only the part inside the list is painted.
                final r =
                    tester.getRect(find.byWidget(t.widget)).intersect(list);
                // Only what is on screen counts.
                if (r.isEmpty) continue;
                expect(r.overlaps(fab), isFalse,
                    reason: '${(t.widget as Text).data} is under the button '
                        '$when');
              }
            }

            expectClear('at the top');
            await tester.drag(
                find.byType(CustomScrollView).first, const Offset(0, -3000));
            await pumpFrames(tester, frames: 3);
            expectClear('at the end');
            await unmount(tester);
          });
        }
      }
    }

    for (final e in phoneSizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('filter chips scroll to the last one: ${e.key} x$scale',
            (tester) async {
          await openLibrary(tester, e.value, scale, layout: 'list');
          expect(tester.takeException(), isNull);
          final last = find.widgetWithText(ChoiceChip, 'Local');
          final bar = find.ancestor(
              of: last, matching: find.byType(SingleChildScrollView));
          expect(bar, findsOneWidget);
          final scrollable = tester.state<ScrollableState>(
              find.descendant(of: bar, matching: find.byType(Scrollable)));
          expect(scrollable.position.axis, Axis.horizontal);
          // The row is wider than the screen, so it must scroll, and it
          // says so with a fade over the clipped edge.
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
          expect(find.ancestor(of: bar, matching: find.byType(ShaderMask)),
              findsOneWidget);
          await tester.drag(bar, const Offset(-2000, 0));
          await pumpFrames(tester, frames: 3);
          final r = tester.getRect(last);
          expect(r.right, lessThanOrEqualTo(e.value.width));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.height, greaterThanOrEqualTo(48 - 8)); // chip + padded tap
          await tester.tap(last);
          await pumpFrames(tester);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('Discover', () {
    LibriVoxBook book(int i) => LibriVoxBook(
          id: 'book_$i',
          title: 'Tale number $i',
          description: 'A novel.',
          totalTimeSecs: 3000,
          authors: [
            LibriVoxAuthor(id: '1', firstName: 'A', lastName: 'Author')
          ],
          urlRss: 'https://example.invalid/rss/$i',
          urlZipFile: 'https://example.invalid/zip/$i',
          language: 'English',
          narrators: const [],
        );

    for (final e in phoneSizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'search results end clear of the search bar: '
            '${e.key} x$scale', (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final client = MockClient((r) async => http.Response('', 404));
          final service = _Paged(40, book);
          await setSurface(tester, e.value);
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: DiscoverScreen(
                db: db,
                audioService: audio,
                libriVoxService: service,
                artworkService: ArtworkEnrichmentService(client: client),
                downloader: LibriVoxStreamAndDownloader(client: client),
              ),
            ),
          ));
          await pumpFrames(tester);
          await tester.enterText(find.byType(TextField), 'tales');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await pumpFrames(tester);
          expect(tester.takeException(), isNull);

          final field = tester.getRect(find.byType(TextField));
          final list = tester.getRect(find.byType(CustomScrollView));
          // The field has its own strip: it never overlaps the list at all,
          // so nothing is under it at the top either.
          expect(list.overlaps(field), isFalse,
              reason: 'the search field floats over the results');

          await tester.drag(
              find.byType(CustomScrollView), const Offset(0, -9000));
          await pumpFrames(tester, frames: 3);

          // Everything still painted in the list stays above the field.
          for (final el in find.byType(LibriVoxBookItem).evaluate()) {
            final r = tester.getRect(find.byWidget(el.widget)).intersect(list);
            if (r.isEmpty) continue;
            expect(r.overlaps(field), isFalse,
                reason: 'a cover sits under the search field at the end');
          }
          // "Load more" is on screen, clear of the field, and tappable.
          final more = find.text('Load more');
          expect(more, findsOneWidget);
          final m = tester.getRect(more);
          expect(m.bottom, lessThanOrEqualTo(field.top));
          expect(m.top, greaterThanOrEqualTo(list.top));
          await tester.tap(more);
          await pumpFrames(tester);
          expect(service.calls, 2);
          await unmount(tester);
        });
      }
    }
  });
}

class _Paged extends LibriVoxService {
  final int total;
  final LibriVoxBook Function(int) make;
  int calls = 0;
  _Paged(this.total, this.make)
      : super(
            rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero));

  @override
  Future<List<LibriVoxBook>> searchBooks(String term,
      {int limit = 10, int offset = 0}) async {
    if (term != 'tales') return const [];
    calls++;
    return [
      for (var i = offset; i < offset + limit && i < total; i++) make(i),
    ];
  }
}

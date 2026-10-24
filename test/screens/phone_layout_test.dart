import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/ambience_service.dart';

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

  Future<void> pumpApp(WidgetTester tester, Size size, double scale) async {
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
      preferences: const UiPreferences(overrides: <String, Object>{}),
      ambience: ambience,
    ));
    await pumpFrames(tester);
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
            if (fade.evaluate().any(
                (e) => (e.widget as FadeTransition).opacity.value == 0)) {
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
            final lib = find.descendant(of: bar, matching: find.text('Library'));
            expect(lib, findsOneWidget);
            final fade = find.ancestor(
                of: lib, matching: find.byType(FadeTransition));
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
}

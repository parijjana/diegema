import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/player_controls_style.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/mini_player_bar.dart';
import 'package:diegema/widgets/player_transport.dart';
import 'package:diegema/widgets/skip_interval_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

final _book = UnifiedAudiobook(
  id: 'a',
  title: 'Emma',
  author: 'Jane Austen',
  description: '',
  source: 'LibriVox',
  origin: 'librivox',
  chapters: [
    for (var i = 0; i < 3; i++)
      AudiobookChapter(
        id: 'a-c$i',
        title: 'Chapter ${i + 1}',
        audioPathOrUrl: 'https://example.invalid/a$i.mp3',
        durationSeconds: 1800,
        isStream: true,
      ),
  ],
);

void main() {
  late FakePlaybackService audio;

  setUp(() => audio = FakePlaybackService());
  tearDown(() async => audio.dispose().catchError((_) {}));

  Future<AppSettings> pump(
    WidgetTester tester, {
    required double width,
    required double textScale,
    required Widget Function() child,
    PlayerControlsStyle style = PlayerControlsStyle.round,
    int back = 30,
    int forward = 10,
  }) async {
    await setSurface(tester, Size(width, 800));
    final store = <String, Object>{};
    final settings = AppSettings(preferences: UiPreferences(overrides: store));
    await settings.setSkipBackSeconds(back);
    await settings.setSkipForwardSeconds(forward);
    await settings.setTransportStyle(style);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: w!,
      ),
      home: SettingsScope(
        settings: settings,
        child: Scaffold(body: Center(child: child())),
      ),
    ));
    await tester.pump();
    return settings;
  }

  /// Every skip control in the tree: its arrow and its number must be
  /// separate, non-overlapping boxes, and the whole control at least 48dp.
  void expectBesideNotInside(WidgetTester tester, int count) {
    final icons = find.byType(SkipIntervalIcon);
    expect(icons, findsNWidgets(count));
    for (final el in icons.evaluate()) {
      final w = el.widget as SkipIntervalIcon;
      final arrow = find.descendant(
          of: find.byWidget(w),
          matching: find.byIcon(SkipIntervalIcon.iconFor(w.direction)));
      final number = find.descendant(
          of: find.byWidget(w), matching: find.text('${w.seconds}'));
      final a = tester.getRect(arrow);
      final n = tester.getRect(number);
      expect(a.overlaps(n), isFalse,
          reason: 'number $n collides with arrow $a');
      expect((a.center.dx - n.center.dx).abs(), lessThan(1.0),
          reason: 'number is centred under the arrow');
      final style = tester.widget<Text>(number).style!;
      expect(style.fontSize, greaterThanOrEqualTo(13));
    }
  }

  void expectTargets48(WidgetTester tester) {
    for (final label in ['Skip back 30 seconds', 'Skip forward 10 seconds']) {
      final box = tester.getRect(find.bySemanticsLabel(label).first);
      expect(box.width, greaterThanOrEqualTo(48), reason: label);
      expect(box.height, greaterThanOrEqualTo(48), reason: label);
    }
  }

  for (final width in [360.0, 411.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final style in PlayerControlsStyle.values) {
        testWidgets(
            'transport ${style.name} at ${width.toInt()}dp, text $scale: '
            'different back/forward numbers, no overflow, no collision',
            (tester) async {
          await pump(tester,
              width: width,
              textScale: scale,
              style: style,
              child: () => PlayerTransport(audioService: audio, book: _book));
          expect(tester.takeException(), isNull);
          expect(find.text('30'), findsOneWidget);
          expect(find.text('10'), findsOneWidget);
          expect(find.bySemanticsLabel('Skip back 30 seconds'), findsOneWidget);
          expect(
              find.bySemanticsLabel('Skip forward 10 seconds'), findsOneWidget);
          expectBesideNotInside(tester, 2);
          expectTargets48(tester);
          final all = tester.getRect(find.byType(PlayerTransport));
          expect(all.left, greaterThanOrEqualTo(0));
          expect(all.right, lessThanOrEqualTo(width));
          await unmount(tester);
        });
      }

      testWidgets('mini player at ${width.toInt()}dp, text $scale: no overflow',
          (tester) async {
        audio.currentBookNotifier.value = _book;
        await pump(tester,
            width: width,
            textScale: scale,
            child: () =>
                MiniPlayerBar(audioService: audio, onOpenPlayer: () {}));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  }

  // The mini player only shows skips from 560dp up (phones keep the row for
  // the title); check the controls where they are visible.
  for (final width in [600.0, 840.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'mini player skips at ${width.toInt()}dp, text $scale: '
          'own numbers, 48dp targets, no collision', (tester) async {
        audio.currentBookNotifier.value = _book;
        await pump(tester,
            width: width,
            textScale: scale,
            child: () =>
                MiniPlayerBar(audioService: audio, onOpenPlayer: () {}));
        expect(tester.takeException(), isNull);
        expect(find.text('30'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        expectBesideNotInside(tester, 2);
        expectTargets48(tester);
        await unmount(tester);
      });
    }
  }

  testWidgets('tapping each button skips by its own interval', (tester) async {
    await pump(tester,
        width: 390,
        textScale: 1.0,
        child: () => PlayerTransport(audioService: audio, book: _book));
    await tester.tap(find.bySemanticsLabel('Skip back 30 seconds'));
    await tester.tap(find.bySemanticsLabel('Skip forward 10 seconds'));
    expect(audio.lastSkipBack, 30);
    expect(audio.lastSkipForward, 10);
    await unmount(tester);
  });
}

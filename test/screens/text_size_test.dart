// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/network/rate_limit_dispatcher.dart';
import 'package:diegema/core/text_size.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/librivox_service.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

void main() {
  group('AppTextScaler', () {
    const system = TextScaler.noScaling;

    test('multiplies, but never below 13px', () {
      final small = AppTextScaler(system, TextSizeChoice.small.factor);
      expect(small.scale(16), closeTo(14.4, 0.001));
      expect(small.scale(13), 13);
      expect(small.scale(11), 11); // already below the floor: unchanged
    });

    test('is capped at 2x nominal', () {
      final larger = AppTextScaler(TextScaler.linear(1.8), 1.3);
      expect(larger.scale(16), closeTo(32, 0.001));
    });

    test('never lowers a system scale above the cap', () {
      final big = AppTextScaler(TextScaler.linear(2.5), 1.3);
      expect(big.scale(10), greaterThanOrEqualTo(25));
    });
  });

  test('stored by name; unknown falls back to system', () async {
    final store = <String, Object>{};
    final s = AppSettings(preferences: UiPreferences(overrides: store));
    await s.setTextSize(TextSizeChoice.larger);
    expect(store['appearance.text_size'], 'larger');
    final bad = AppSettings(
        preferences:
            UiPreferences(overrides: {'appearance.text_size': 'huge'}));
    await bad.load();
    expect(bad.textSize, TextSizeChoice.system);
  });

  late FakePlaybackService audio;
  setUp(() => audio = FakePlaybackService());
  tearDown(() => audio.dispose().catchError((_) {}));

  Future<double> scaledSixteen(WidgetTester tester, String? stored,
      {double system = 1.0}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tester.platformDispatcher.textScaleFactorTestValue = system;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(AudiobookApp(
      database: db,
      audioService: audio,
      libriVoxService: LibriVoxService(
        client: MockClient((r) async => http.Response('{"books": []}', 200)),
        rateLimiter: RateLimitDispatcher(cooldownOverride: Duration.zero),
      ),
      preferences: UiPreferences(overrides: <String, Object>{
        if (stored != null) 'appearance.text_size': stored,
      }),
    ));
    await pumpFrames(tester);
    final context = tester.element(find.byType(Scaffold).first);
    return MediaQuery.textScalerOf(context).scale(16);
  }

  testWidgets('system leaves the scale alone', (tester) async {
    expect(await scaledSixteen(tester, null), 16);
  });

  testWidgets('large multiplies the system scale', (tester) async {
    expect(await scaledSixteen(tester, 'large'), closeTo(18.4, 0.01));
  });

  testWidgets('larger on top of a big system scale is clamped to 2x',
      (tester) async {
    expect(
        await scaledSixteen(tester, 'larger', system: 1.8), closeTo(32, 0.01));
    expect(tester.takeException(), isNull);
  });
}

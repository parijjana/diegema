import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/librivox_service.dart';

import 'support/test_harness.dart';

void main() {
  /// Never touches the network: intercepts every host the app talks to and
  /// returns empty-but-valid payloads, so the widget tests are
  /// deterministic and work with no network access.
  MockClient buildMockClient() => MockClient((request) async {
        if (request.url.host == 'librivox.org') {
          return http.Response('{"books": []}', 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.host == 'archive.org') {
          return http.Response('{"response": {"docs": []}}', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

  Widget buildApp(AppDatabase db) => AudiobookApp(
        database: db,
        libriVoxService: LibriVoxService(client: buildMockClient()),
        preferences: const UiPreferences(overrides: <String, Object>{}),
      );

  testWidgets('lands on Now Playing and offers all three destinations',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await setSurface(tester, const Size(390, 844));

    await tester.pumpWidget(buildApp(db));
    await pumpFrames(tester);

    // Nav destinations. "Now playing" appears twice at phone width — the
    // screen heading and the nav label — so it is matched loosely.
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Discover'), findsWidgets);
    expect(find.textContaining('Now playing'), findsWidgets);

    // Now Playing is the landing screen, in its idle empty state.
    expect(find.text('Nothing in progress'), findsOneWidget);

    // The retired all-caps labels are gone for good.
    expect(find.text('AULOS'), findsNothing);
    expect(find.text('LIBRARY'), findsNothing);
    expect(find.text('DISCOVER'), findsNothing);

    await unmount(tester);
  });

  testWidgets('bottom navigation switches screens', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await setSurface(tester, const Size(390, 844));

    await tester.pumpWidget(buildApp(db));
    await pumpFrames(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Library'),
    ));
    await pumpFrames(tester);

    // Left Now Playing, arrived at Library. The download scan no longer
    // explodes under the test binding (it resolves no documents root and
    // skips), so the body settles on the honest empty state.
    expect(find.text('Nothing in progress'), findsNothing);
    expect(find.byTooltip('Refresh library'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.byTooltip('Import a book'), findsOneWidget);

    await unmount(tester);
  });

  // Navigation is at the bottom at every width as of 08-14. Both earlier
  // arrangements are asserted absent, not just the one this replaced: the
  // side NavigationRail (rejected 08-12) and the wide-only top tab bar that
  // replaced it. Crossing the breakpoint used to move the nav *and* the mini
  // player at once, which is what read as the app changing shape.
  for (final entry in {
    'phone 390x844': const Size(390, 844),
    'desktop 1440x900': const Size(1440, 900),
  }.entries) {
    testWidgets('navigation is a bottom bar on ${entry.key}', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await setSurface(tester, entry.value);

      await tester.pumpWidget(buildApp(db));
      await pumpFrames(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byKey(const ValueKey('top-tab-bar')), findsNothing);

      await unmount(tester);
    });
  }
}

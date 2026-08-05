import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unamedaudiobookplayer/app.dart';
import 'package:unamedaudiobookplayer/core/ui_preferences.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/services/librivox_service.dart';

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

  testWidgets('wide layout uses a side rail, not a bottom bar',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await setSurface(tester, const Size(1440, 900));

    await tester.pumpWidget(buildApp(db));
    await pumpFrames(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await unmount(tester);
  });
}

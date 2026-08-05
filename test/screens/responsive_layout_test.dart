import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unamedaudiobookplayer/app.dart';
import 'package:unamedaudiobookplayer/core/ui_preferences.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/services/librivox_service.dart';

import '../support/test_harness.dart';

/// Overflow guard.
///
/// Raising the type floor from 10px to 13px and retiring the letter-spaced
/// all-caps labels makes every horizontal row tighter than it used to be,
/// and a `RenderFlex overflowed` error can be invisible in a screenshot
/// (the content is simply clipped) while still throwing. A sibling project
/// had a store submission blocked by exactly this class of bug, so each
/// supported width is asserted here rather than eyeballed.
///
/// 360×800 is the narrowest width worth supporting (Galaxy S series);
/// 430×932 is the wide-phone end (iPhone Plus/Max); 1440×900 is desktop.
void main() {
  const sizes = <String, Size>{
    'android narrow 360x800': Size(360, 800),
    'iphone 390x844': Size(390, 844),
    'iphone max 430x932': Size(430, 932),
    'desktop 1440x900': Size(1440, 900),
  };

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

  for (final entry in sizes.entries) {
    for (final dark in [false, true]) {
      final themeName = dark ? 'dark' : 'light';
      testWidgets('${entry.key} / $themeName lays out with no overflow',
          (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        // Long titles and author names are the realistic worst case for a
        // horizontal row, so the seeded data uses them deliberately.
        await seedBook(db,
            id: 'a',
            title: 'The Extraordinarily Long Title of a Victorian Novel, '
                'Volume the Second',
            positionSeconds: 600);
        await seedBook(db, id: 'b', title: 'Middlemarch', positionSeconds: 900);
        await seedBook(db, id: 'c', title: 'Persuasion', positionSeconds: 400);
        await db.pinBook('c');
        await seedBook(db, id: 'd', title: 'A Pinned Book Not In Progress');
        await db.pinBook('d');

        await setSurface(tester, entry.value);

        await tester.pumpWidget(AudiobookApp(
          initialDarkMode: dark,
          database: db,
          libriVoxService: LibriVoxService(client: buildMockClient()),
          preferences: const UiPreferences(overrides: <String, Object>{}),
        ));
        await pumpFrames(tester);

        // Any RenderFlex overflow surfaces here as a thrown FlutterError.
        expect(tester.takeException(), isNull,
            reason: 'Now Playing overflowed at ${entry.key}');

        // Walk all three screens at this width.
        final navFinder = find.byType(NavigationBar).evaluate().isNotEmpty
            ? find.byType(NavigationBar)
            : find.byType(NavigationRail);

        for (final label in ['Library', 'Discover', 'Now playing']) {
          await tester.tap(find.descendant(
            of: navFinder,
            matching: find.text(label),
          ));
          await pumpFrames(tester);
          if (label == 'Discover') await drainRateLimiter(tester);
          expect(tester.takeException(), isNull,
              reason: '$label overflowed at ${entry.key}');
        }

        await unmount(tester);
      });
    }
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unamedaudiobookplayer/app.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/services/librivox_service.dart';

void main() {
  testWidgets('AudiobookApp renders main header and navigation tabs', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Never touches the network: intercepts every host the app talks to
    // (librivox.org and archive.org) and returns empty-but-valid payloads,
    // so the widget test is deterministic and works with no network access.
    final mockClient = MockClient((request) async {
      if (request.url.host == 'librivox.org') {
        return http.Response('{"books": []}', 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.host == 'archive.org') {
        return http.Response(
          '{"response": {"docs": []}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    await tester.pumpWidget(AudiobookApp(
      database: db,
      libriVoxService: LibriVoxService(client: mockClient),
    ));
    // Bounded pumps rather than pumpAndSettle: some chrome in this app
    // (e.g. a spinner) animates indefinitely while loading, which would
    // make pumpAndSettle hang forever waiting for animations to stop.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('AULOS'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('DISCOVER'), findsOneWidget);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unamedaudiobookplayer/database/app_database.dart';
import 'package:unamedaudiobookplayer/screens/library_screen.dart';
import 'package:unamedaudiobookplayer/services/audio_playback_service.dart';
import 'package:unamedaudiobookplayer/theme/app_theme.dart';

import '../support/test_harness.dart';

void main() {
  late AppDatabase db;
  late AudioPlaybackService audio;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioPlaybackService(db: db);
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget wrap({LibraryScanner? scanLibrary}) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryScreen(
            db: db,
            audioService: audio,
            onGoToDiscover: () {},
            scanLibrary: scanLibrary,
          ),
        ),
      );

  testWidgets('shows the empty state when the scan finds nothing',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: (_) async {}));
    await pumpFrames(tester);

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('lists whatever the scan registered', (tester) async {
    var scans = 0;
    Future<void> scan(AppDatabase db) async {
      scans++;
      await seedBook(db, id: 'scanned', title: 'Scanned From Disk');
    }

    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(scanLibrary: scan));
    await pumpFrames(tester);

    expect(scans, 1);
    expect(find.text('Scanned From Disk'), findsOneWidget);
    expect(find.text('Library (1 book)'), findsOneWidget);
  });

  testWidgets('a failing scan surfaces the error state, not a silent empty',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester
        .pumpWidget(wrap(scanLibrary: (_) async => throw StateError('disk')));
    await pumpFrames(tester);

    expect(find.text('Could not read your library'), findsOneWidget);
  });

  testWidgets('the default scanner is a no-op without path_provider',
      (tester) async {
    // The real default used to throw MissingPluginException under the test
    // binding and print "LibraryScreen: scan failed" on every run.
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await pumpFrames(tester);

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Could not read your library'), findsNothing);
  });
}

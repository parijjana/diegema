import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/app.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// Cold-start restore (`AppShell._maybeRestoreLastPlayed`): Now Playing
/// should open straight into the paused player when the database already
/// has an eligible in-progress book, and keep showing its idle
/// "Continue listening"/empty state otherwise.
///
/// A [FakePlaybackService] is required rather than the real
/// `AudioPlaybackService` for the seeded-progress case — restoring calls
/// `loadBook` unprompted on the very first frame, and the real service's
/// `AudioPlayer` reaches for a platform channel the moment that happens,
/// which throws under `flutter_test` (see the identical reasoning in
/// `now_playing_screen_test.dart`).
void main() {
  late AppDatabase db;
  late FakePlaybackService audio;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = FakePlaybackService();
  });

  tearDown(() async {
    // Cancels the service's periodic progress-save timer; without this the
    // test binding fails with "A Timer is still pending".
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  Widget buildApp() => AudiobookApp(
        database: db,
        audioService: audio,
        preferences: const UiPreferences(overrides: <String, Object>{}),
      );

  testWidgets(
      'opens straight into the paused player when a book is in progress',
      (tester) async {
    await setSurface(tester, const Size(390, 844));

    final book = await seedBook(
      db,
      id: 'in-progress',
      title: 'The Restored Book',
      runtimeSeconds: 3600,
      positionSeconds: 600,
    );

    await tester.pumpWidget(buildApp());
    await pumpFrames(tester);

    // The player view replaced the idle list...
    expect(find.text('Nothing in progress'), findsNothing);
    expect(find.text(book.title), findsWidgets);
    // ...loaded via `loadBook(..., autoPlay: false)`, not autoplaying.
    expect(audio.loadCalls, 1);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);

    await unmount(tester);
  });

  testWidgets('keeps the idle list when nothing is eligible to resume',
      (tester) async {
    await setSurface(tester, const Size(390, 844));

    await tester.pumpWidget(buildApp());
    await pumpFrames(tester);

    expect(find.text('Nothing in progress'), findsOneWidget);
    expect(audio.loadCalls, 0);

    await unmount(tester);
  });
}

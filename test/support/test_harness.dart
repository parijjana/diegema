import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';

/// Sets the test surface to a real device size in logical pixels and
/// restores it afterwards.
Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Bounded pumps rather than `pumpAndSettle`: some chrome in this app (a
/// spinner, the Now Playing cross-fade) can animate while loading, which
/// would make `pumpAndSettle` wait forever.
///
/// The `runAsync` step is load-bearing. Every screen here loads through
/// drift, whose futures complete on the *real* event loop; under the test
/// binding's fake async they would never resolve and every screen would sit
/// forever in its loading state.
Future<void> pumpFrames(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(step);
  }
}

/// Discover's shelf load runs eight category queries through
/// [RateLimitDispatcher], which spaces them a second apart, so the screen
/// keeps a chain of pending timers alive for several seconds of fake time.
/// Anything that visits Discover must drain them or the binding fails the
/// test with "A Timer is still pending".
Future<void> drainRateLimiter(WidgetTester tester) =>
    pumpFrames(tester, frames: 16, step: const Duration(seconds: 1));

/// Tears the tree down inside the test body so `State.dispose` actually
/// runs. `AudioPlaybackService` owns a 5-second periodic progress-save
/// timer that is only cancelled on dispose; without this the binding fails
/// every test with "A Timer is still pending".
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
}

/// Seeds [db] with a book, one chapter of [runtimeSeconds], and a progress
/// row at [positionSeconds] — enough for `getContinueListening` to consider
/// it in progress when the position clears the 30s floor.
/// [updatedAt] controls [AppDatabase.getMostRecentProgress]'s ordering when
/// a test seeds more than one progress row and cares which one is "most
/// recent" (Task 3's restore-on-idle reads this — see
/// `now_playing_screen.dart`'s `_maybeRestoreLastPlayed`). Left `null`
/// (the default) uses `DateTime.now()`, which is fine for single-progress
/// tests but ties easily when several rows are seeded back-to-back in the
/// same test.
Future<UnifiedAudiobook> seedBook(
  AppDatabase db, {
  required String id,
  String? title,
  int runtimeSeconds = 3600,
  int? positionSeconds,
  DateTime? updatedAt,
}) async {
  final book = UnifiedAudiobook(
    id: id,
    title: title ?? 'Book $id',
    author: 'Author $id',
    description: 'Description for $id',
    source: 'LibriVox',
    origin: 'librivox',
    chapters: [
      AudiobookChapter(
        id: '$id-c0',
        title: 'Chapter 1',
        audioPathOrUrl: 'https://example.invalid/$id.mp3',
        durationSeconds: runtimeSeconds,
        isStream: true,
      ),
    ],
  );
  await db.saveAudiobook(book);
  if (positionSeconds != null) {
    await db.saveProgress(
      audiobookId: id,
      chapterIndex: 0,
      positionSeconds: positionSeconds,
      updatedAt: updatedAt,
    );
  }
  return book;
}

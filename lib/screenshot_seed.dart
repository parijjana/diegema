// Description: In-memory state for the store screenshot harness.
//
// Imported ONLY by `lib/screenshot_main.dart`. The shipped app never sees this
// file, and nothing here is reachable from `lib/main.dart`.
//
// This is deliberately much smaller than the store-launch-kit scaffold it came
// from, because Diegema already owns two things the scaffold expects you to
// fabricate:
//
//   * `assets/demo/catalog.json` — 18 real LibriVox books with real titles,
//     authors, descriptions and chapter lists, whose cover art is licence-cleared
//     (`assets/demo/covers/CREDITS.md`). The scaffold's GOTCHA 6 says "seed
//     realistic domain content, never lorem ipsum"; the honest way to satisfy
//     that here is to use the catalogue the app itself ships rather than invent
//     a parallel one.
//   * `core/demo_deeplink.dart` — an existing, tested way to enter a specific
//     app state through the app's own code paths. The harness drives scenes with
//     it instead of poking private state.
//
// So all this file supplies is (1) a database that lives in memory rather than
// in the macOS sandbox container, and (2) a playback service that reports a
// fixed position instead of decoding audio.

import 'package:drift/native.dart';

import 'core/demo_mode.dart';
import 'database/app_database.dart';
import 'domain/models/audiobook.dart';
import 'services/audio_playback_service.dart';
import 'services/demo_catalog.dart';

/// The book the hero shot shows mid-listen. Pinned by id rather than picked
/// dynamically ("first playable with enough chapters") so that reordering the
/// catalogue can never silently change what the marketing shots depict.
const String kHeroBookId = 'frankenstein_cs_librivox';

/// Chapter 3 of 8, part-way through. Deliberately not chapter 1 at 0:00 — the
/// point of the shot is a library in use, and the "Up next" list only has
/// anything to show when there is a next.
const int kHeroChapterIndex = 2;
/// Must stay inside chapter 3's 410 s, or the scrubber pins at 100%.
const int kHeroPositionSeconds = 187;

/// Two more books carrying progress, so "Continue listening" is populated
/// rather than a single-item row. Ordered by [DateTime] below so the shelf's
/// most-recent-first ordering is deterministic.
const Map<String, int> kSecondaryProgress = {
  'pride_and_prejudice_librivox': 1180,
  'call_of_the_wild': 337,
};

/// A drift database held entirely in memory.
///
/// The real [AppDatabase] opens a file under `path_provider`'s application
/// support directory, which on a sandboxed macOS build lives inside the app's
/// container. Two reasons not to use it here: capture would inherit whatever
/// happened to be in the developer's own library (exactly the mix-up that
/// produced a coverless screenshot on 08-14), and each run would mutate state
/// the next run reads. In memory, every run starts from the same catalogue.
Future<AppDatabase> buildScreenshotDatabase() async {
  final db = AppDatabase(NativeDatabase.memory());
  final catalog = await DemoCatalog.load();

  for (final entry in catalog) {
    await db.saveAudiobook(_toUnified(entry));
  }

  // Most recent last: `getMostRecentProgress` orders on `updatedAt`, and the
  // hero book must win that ordering or Now Playing restores a different book
  // than the one the shot is named after.
  final now = DateTime.now();
  var age = kSecondaryProgress.length + 1;
  for (final e in kSecondaryProgress.entries) {
    await db.saveProgress(
      audiobookId: e.key,
      chapterIndex: 1,
      positionSeconds: e.value,
      updatedAt: now.subtract(Duration(hours: age--)),
    );
  }
  await db.saveProgress(
    audiobookId: kHeroBookId,
    chapterIndex: kHeroChapterIndex,
    positionSeconds: kHeroPositionSeconds,
    updatedAt: now,
  );

  return db;
}

/// Catalogue entry -> the domain model the library and player read.
///
/// Chapter URLs are built the same way the demo build builds them, so nothing
/// here depends on a code path the app does not otherwise use. They are never
/// fetched: [ScreenshotPlaybackService] overrides every method that would.
UnifiedAudiobook _toUnified(DemoBookEntry entry) {
  return UnifiedAudiobook(
    id: entry.id,
    title: entry.title,
    author: entry.author,
    description: entry.description,
    coverArtUrlOrPath: entry.coverUrl,
    source: 'LibriVox',
    origin: 'librivox',
    narrators: entry.narrators,
    isDownloaded: true,
    chapters: [
      for (var i = 0; i < entry.chapters.length; i++)
        AudiobookChapter(
          id: '${entry.id}-c$i',
          title: entry.chapters[i].title,
          audioPathOrUrl: '$kDemoAudioBase${entry.chapters[i].filename}',
          durationSeconds: entry.chapters[i].durationSeconds,
          isStream: true,
        ),
    ],
  );
}

/// A playback service that reports a fixed, believable position and touches no
/// audio.
///
/// Same shape as `test/support/fake_playback_service.dart` and for the same
/// reason — [AudioPlaybackService] is a concrete class the screens depend on
/// directly, so the only way to substitute it is to subclass and override every
/// method that reaches `just_audio`. It is duplicated rather than imported
/// because `test/` is not on `lib/`'s import path.
///
/// Determinism is the point. A real player would give a position that moves
/// between the iPhone shot and the iPad shot, so the same scene would show two
/// different times and the gallery would look assembled rather than captured.
class ScreenshotPlaybackService extends AudioPlaybackService {
  ScreenshotPlaybackService();

  @override
  Future<void> loadBook(
    UnifiedAudiobook book, {
    int? initialChapterIndex,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    final chapterIndex = initialChapterIndex ?? kHeroChapterIndex;
    currentBookNotifier.value = book;
    chapterIndexNotifier.value = chapterIndex;
    positionNotifier.value =
        initialPosition ?? const Duration(seconds: kHeroPositionSeconds);
    durationNotifier.value = Duration(
      seconds: chapterIndex < book.chapters.length
          ? book.chapters[chapterIndex].durationSeconds
          : 0,
    );
    // Shown mid-playback rather than paused: a pause glyph reads as "stopped"
    // in a still image, and the transport is the subject of the hero shot.
    stateNotifier.value = PlaybackState.playing;
  }

  @override
  Future<void> play() async => stateNotifier.value = PlaybackState.playing;

  @override
  Future<void> pause() async => stateNotifier.value = PlaybackState.paused;

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> seek(Duration position) async =>
      positionNotifier.value = position;

  @override
  Future<void> skipForward({int seconds = 15}) async {}

  @override
  Future<void> skipBackward({int seconds = 15}) async {}

  @override
  Future<void> nextChapter() async {}

  @override
  Future<void> previousChapter() async {}

  @override
  Future<void> setSpeed(double speed) async => speedNotifier.value = speed;
}

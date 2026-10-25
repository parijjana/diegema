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
import 'package:flutter/foundation.dart';

import 'core/demo_mode.dart';
import 'database/app_database.dart';
import 'domain/models/audiobook.dart';
import 'services/ambience_service.dart';
import 'services/audio_playback_service.dart';
import 'services/demo_catalog.dart';
import 'services/sync/sync_controller.dart';
import 'sync/hlc.dart';
import 'sync/sync_record.dart';
import 'sync/sync_view.dart';

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

/// Catalogue entries the store art must never show.
const Set<String> kExcludedFromStoreArt = {'gettysburg_address_librivox'};

class _SeedBookmark {
  final int chapter;
  final int seconds;
  final String note;
  const _SeedBookmark(this.chapter, this.seconds, this.note);
}

const List<_SeedBookmark> _heroBookmarks = [
  _SeedBookmark(0, 95, 'Walton, writing home from the ice'),
  _SeedBookmark(1, 142, 'Victor: "I beheld the wretch"'),
  _SeedBookmark(2, 118, 'The creature wakes - reread this'),
  _SeedBookmark(2, 187, 'Where I stopped last night'),
];

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
    // Never shown in store art: its LibriVox cover is a photograph of the
    // battlefield dead. Left out of the library, and no scene lists it
    // (Discover is driven through a category that does not contain it).
    if (kExcludedFromStoreArt.contains(entry.id)) continue;
    await db.saveAudiobook(_toUnified(entry));
  }

  // Bookmarks on the hero book, so the Bookmarks sheet is a lived-in one.
  // Chapter indices are 0-based and positions sit inside each chapter.
  var n = 0;
  for (final b in _heroBookmarks) {
    await db.addBookmark(
      id: 'store-shot-bookmark-${n++}',
      audiobookId: kHeroBookId,
      chapterIndex: b.chapter,
      positionSeconds: b.seconds,
      note: b.note,
    );
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
    bool resume = false,
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

// ---------------------------------------------------------------------------
// Ambience

/// A channel that makes no sound: the mixer UI and the Now Playing pill read
/// [AmbienceService.state], never the channel.
class _SilentChannel implements AmbienceChannel {
  @override
  Future<void> load(String asset) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

/// An [AmbienceService] that starts in a fixed, seeded state instead of
/// restoring one from preferences, and plays through [_SilentChannel]s.
class ScreenshotAmbienceService extends AmbienceService {
  final AmbienceState _seed;

  // ignore: use_super_parameters
  ScreenshotAmbienceService({
    required AudioPlaybackService book,
    required AmbienceState seed,
  })  : _seed = seed,
        super(
          book: book,
          channelFactory: _SilentChannel.new,
          useAudioSession: false,
          fade: Duration.zero,
        );

  @override
  Future<void> init() async {
    state.value = _seed;
  }
}

/// Mix for the Now Playing hero: a stormy night to go with Frankenstein.
const AmbienceState kStormMix = AmbienceState(
  mix: {'thunderstorm': 0.7, 'rain': 0.5, 'fireplace': 0.35},
  master: 0.6,
  on: true,
  saved: [
    SavedAmbienceMix('Storm night', {
      'thunderstorm': 0.7,
      'rain': 0.5,
      'fireplace': 0.35,
    }),
    SavedAmbienceMix('By the fire', {'fireplace': 0.8, 'wind': 0.25}),
    SavedAmbienceMix('Tavern evening', {'tavern_crowd': 0.6, 'fireplace': 0.4}),
  ],
);

/// Mix for the Ambience screen: the Places sounds, battle and swords included.
const AmbienceState kBattleMix = AmbienceState(
  mix: {'battle': 0.65, 'sword_fight': 0.5, 'horses': 0.4, 'wind': 0.3},
  master: 0.6,
  on: true,
  saved: [
    SavedAmbienceMix('Storm night', {
      'thunderstorm': 0.7,
      'rain': 0.5,
      'fireplace': 0.35,
    }),
    SavedAmbienceMix('Field of battle', {
      'battle': 0.65,
      'sword_fight': 0.5,
      'horses': 0.4,
      'wind': 0.3,
    }),
    SavedAmbienceMix('Tavern evening', {'tavern_crowd': 0.6, 'fireplace': 0.4}),
  ],
);

// ---------------------------------------------------------------------------
// Linked-device sync

/// A [SyncController] that reports a linked group of three devices and does
/// nothing else. Only `status`, `view`, `lastSync`, `deviceName` and
/// `canScan` are read by Settings -> Linked devices.
class ScreenshotSyncController implements SyncController {
  ScreenshotSyncController({required this.thisDevice, this.canScan = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    SyncRecord device(String id, String name, String platform) => SyncRecord(
          kind: SyncKind.device,
          key: id,
          hlc: Hlc(now, 0, id),
          payload: {'name': name, 'platform': platform},
        );
    view = ValueNotifier(
      SyncView('this-device', [
        device('kitchen-ipad', 'Kitchen iPad', 'ios'),
        device('study-mac', 'Study Mac', 'macos'),
        device('windows-pc', 'Windows PC', 'windows'),
      ]),
    );
    lastSync = ValueNotifier(
      LastSync(DateTime.now().subtract(const Duration(minutes: 3)), 3),
    );
  }

  final String thisDevice;

  @override
  late final ValueNotifier<SyncView?> view;
  @override
  late final ValueNotifier<LastSync?> lastSync;

  @override
  final bool canScan;
  @override
  Future<SyncStatus> status() async => SyncStatus.linked;
  @override
  Future<bool> isLinked() async => true;
  @override
  Future<String> deviceName() async => thisDevice;
  @override
  Future<void> setDeviceName(String name) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> foreground() async {}
  @override
  Future<void> background() async {}
  @override
  Future<int> syncNow() async => 3;
  @override
  Future<LinkOffer> createLinkOffer() =>
      Future.error(UnsupportedError('screenshot sync'));
  @override
  Future<JoinOutcome> joinWithCode(String code, {bool replaceGroup = false}) =>
      Future.error(UnsupportedError('screenshot sync'));
  @override
  Future<void> forgetDevice(String deviceId) async {}
  @override
  Future<void> unlink() async {}
  @override
  Future<void> resetKeys() async {}
  @override
  Future<Map<String, String>> portableKeys() async => const {};
  @override
  Future<void> linkBook(String bookId, String key) async {}
  @override
  Future<SyncFileExport> exportSyncFile() =>
      Future.error(UnsupportedError('screenshot sync'));
  @override
  Future<int> importSyncFile(List<int> bytes) async => 0;
}

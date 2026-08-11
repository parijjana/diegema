import 'package:flutter/foundation.dart' show debugPrint;

import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'demo_catalog.dart';
import 'demo_downloader.dart';

/// DEMO_MODE-only startup seed.
///
/// Two things the canned web demo needs so it never lands on an empty
/// screen:
///
/// - **Task 5**: the two playable demo titles — The Gettysburg Address and
///   Sonnet 23 — show up in the Library screen as though the user already
///   owns them. In demo terms they are owned: their audio ships with the
///   build and plays. The 16 browse-only titles are never touched here —
///   they stay Discover-only, marked "Preview only".
/// - **Task 4**: The Gettysburg Address (161s total) gets ~30% saved
///   progress (48s), so Now Playing opens on a populated player instead of
///   the empty state. Sonnet 23 is left with no progress.
///
/// Re-seeds on every launch rather than persisting an "already seeded"
/// flag: the web demo's [AppDatabase] is an in-memory store (see
/// `database/app_database_web.dart`) that starts empty on every page load
/// regardless, so there is nothing to preserve across a reload and
/// reseeding is simpler than tracking whether it already ran.
///
/// Only ever called from `main()`, and only when `kDemoMode` is true (see
/// `core/demo_mode.dart`) — a real, non-demo [AppDatabase] must never see
/// synthetic data.
Future<void> seedDemoLibrary(AppDatabase db) async {
  final List<DemoBookEntry> entries;
  try {
    entries = await DemoCatalog.load();
  } catch (e) {
    debugPrint('seedDemoLibrary: could not load the demo catalog: $e');
    return;
  }

  final playable = entries.where((e) => e.playable).toList();
  if (playable.isEmpty) return;

  final downloader = DemoDownloader();
  for (final entry in playable) {
    try {
      final book =
          await downloader.parseStreamableBook(entry.toLibriVoxBook());
      // The demo's audio ships with the build and plays — as good as
      // "downloaded" in demo terms, so it belongs in Library.
      final owned = UnifiedAudiobook(
        id: book.id,
        title: book.title,
        author: book.author,
        description: book.description,
        coverArtUrlOrPath: book.coverArtUrlOrPath,
        source: book.source,
        origin: book.origin,
        narrators: book.narrators,
        chapters: book.chapters,
        isDownloaded: true,
      );
      await db.saveAudiobook(owned);
    } catch (e) {
      // A missing/broken catalog entry must never crash demo startup.
      debugPrint('seedDemoLibrary: could not seed ${entry.id}: $e');
    }
  }

  // ~30% of 161s. See Task 4 — The Gettysburg Address specifically, not
  // "whichever book loads first": the owner named it explicitly so the
  // demo's progress bar always looks the same on every launch.
  const gettysburgId = 'gettysburg_address_librivox';
  if (playable.any((e) => e.id == gettysburgId)) {
    try {
      await db.saveProgress(
        audiobookId: gettysburgId,
        chapterIndex: 0,
        positionSeconds: 48,
      );
    } catch (e) {
      debugPrint('seedDemoLibrary: could not seed progress: $e');
    }
  }
}

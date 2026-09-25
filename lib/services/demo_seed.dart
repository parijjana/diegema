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
/// - **Task 5**: every playable demo title shows up in the Library screen as
///   though the user already owns it. In demo terms they are owned: their
///   audio ships with the build and plays. The browse-only titles are never
///   touched here — they stay Discover-only, marked "Preview only".
/// - **Task 4**: one of them carries saved progress so the
///   continue-listening surfaces are never empty. Which book, and why that
///   one, is explained at the call below.
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
      final book = await downloader.parseStreamableBook(entry.toLibriVoxBook());
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

  // One named book carries saved progress, not "whichever loads first", so
  // the demo's continue-listening row looks identical on every launch.
  //
  // This was The Gettysburg Address, then Frankenstein, and is now Sonnet 23.
  //
  // It left Gettysburg because the seeded book is what Library's "In progress"
  // row shows, so it lands in most screenshots — and Gettysburg's cover is a
  // battlefield photograph of corpses, which is topically accurate and a poor
  // advertisement.
  //
  // It left Frankenstein because the three multi-chapter titles went back to
  // preview-only: their audio is 191MB of the 193MB total, and the demo is
  // served out of a public git repo where that would live in the history
  // forever. Only Gettysburg and Sonnet 23 ship audio now, so those are the
  // only two ids this can be — the guard below would otherwise silently seed
  // nothing and leave the demo's landing screen empty.
  //
  // Sonnet 23 has one chapter, so "Up next" renders a list of one. That was
  // the original objection to a one-chapter subject, and it is accepted here:
  // "Up next" needed a real chapter list for the STORE SCREENSHOTS, which
  // have been captured. Nothing else depended on it.
  const inProgressId = 'sonnet_23_librivox';
  if (playable.any((e) => e.id == inProgressId)) {
    try {
      await db.saveProgress(
        audiobookId: inProgressId,
        chapterIndex: 0,
        positionSeconds: 31,
      );
    } catch (e) {
      debugPrint('seedDemoLibrary: could not seed progress: $e');
    }
  }
}

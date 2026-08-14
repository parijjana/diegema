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

  // One named book carries saved progress, not "whichever loads first", so
  // the demo's continue-listening row looks identical on every launch.
  //
  // This was The Gettysburg Address until 2026-08-14. It moved because the
  // seeded book is what Library's "In progress" row shows, so it lands in
  // most screenshots — and Gettysburg's cover is a battlefield photograph
  // of corpses, which is topically accurate and a poor advertisement. It
  // also had exactly one chapter, so it could never show the chapter list
  // that "Up next" exists for.
  //
  // Frankenstein is a third of the way into its third chapter (of eight):
  // far enough in to read as a book genuinely in progress rather than one
  // just opened.
  const inProgressId = 'frankenstein_cs_librivox';
  if (playable.any((e) => e.id == inProgressId)) {
    try {
      await db.saveProgress(
        audiobookId: inProgressId,
        chapterIndex: 2,
        positionSeconds: 123,
      );
    } catch (e) {
      debugPrint('seedDemoLibrary: could not seed progress: $e');
    }
  }
}

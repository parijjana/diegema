import '../core/demo_mode.dart';
import '../domain/models/audiobook.dart';
import '../domain/models/librivox_book.dart';
import 'demo_catalog.dart';
import 'librivox_downloader.dart';

/// Stub [LibriVoxStreamAndDownloader] for the canned web demo. Resolves a
/// book's chapter list from the bundled catalog instead of fetching a RSS
/// feed, and points each chapter's stream URL at `kDemoAudioBase` (see
/// `core/demo_mode.dart`) rather than a live LibriVox/archive.org URL —
/// the demo only ships audio for the couple of books explicitly marked
/// playable in catalog.json.
///
/// ZIP download is always unsupported here: the demo is explicitly
/// streaming-only (rework_plan.md), and `BookDetailPane` hides the
/// download button whenever `kDemoMode` is true, so this is a defensive
/// throw rather than a reachable path.
class DemoDownloader extends LibriVoxStreamAndDownloader {
  @override
  Future<UnifiedAudiobook> parseStreamableBook(LibriVoxBook book) async {
    final entries = await DemoCatalog.load();
    DemoBookEntry? entry;
    for (final e in entries) {
      if (e.id == book.id) {
        entry = e;
        break;
      }
    }

    if (entry == null) {
      return UnifiedAudiobook(
        id: book.id,
        title: book.title,
        author: book.authorNames,
        description: book.description,
        source: 'Demo',
        narrators: book.narrators,
        chapters: const [],
        isDownloaded: false,
      );
    }

    final chapters = entry.chapters.asMap().entries.map((e) {
      final idx = e.key;
      final ch = e.value;
      return AudiobookChapter(
        id: '${book.id}_demo_$idx',
        title: ch.title,
        audioPathOrUrl: '$kDemoAudioBase${ch.filename}',
        durationSeconds: ch.durationSeconds,
        isStream: true,
      );
    }).toList();

    return UnifiedAudiobook(
      id: book.id,
      title: book.title,
      author: book.authorNames,
      description: book.description,
      source: 'LibriVox (Demo)',
      narrators: book.narrators,
      chapters: chapters,
      isDownloaded: false,
    );
  }

  @override
  Future<List<String>> downloadAndExtractZip(
    LibriVoxBook book, {
    required String saveDirectoryPath,
    void Function(double progress)? onProgress,
  }) async {
    throw UnsupportedError(
      'Full-book download is not available in the web demo — it is '
      'streaming-only.',
    );
  }
}

import '../domain/models/audiobook.dart' as domain;

/// Web implementation of [AppDatabase]: an in-memory store with no
/// dependency on drift, sqlite3, or any wasm worker (see rework_plan.md —
/// "Skip drift on web. Do not stand up the sqlite3 WASM worker for a demo;
/// keep playback progress in memory + localStorage."). This backs the
/// canned web demo only; nothing here persists across a page reload.
///
/// Its public surface intentionally mirrors `app_database_io.dart` (the
/// real drift-backed implementation) method-for-method, so every widget
/// that takes an `AppDatabase` works unmodified on both platforms. There
/// is no migration concern here — an in-memory store has no schema
/// version to upgrade — so this file only needs to track the *current*
/// shape of a book/bookmark row, not its history.
class AppDatabase {
  final Map<String, domain.UnifiedAudiobook> _audiobooks = {};
  final Map<String, PlaybackProgressData> _progress = {};
  final List<Bookmark> _bookmarks = [];

  /// Mirrors `Audiobooks.isPinned` / `pinOrder`.
  final Map<String, int> _pinOrder = {};

  /// Mirrors `Audiobooks.hiddenFromContinue`.
  final Set<String> _hiddenFromContinue = {};

  /// Mirrors `Audiobooks.userCoverPath`.
  final Map<String, String> _userCoverPaths = {};

  static const int maxPinnedBooks = 5;
  static const int continueListeningMinPositionSeconds = 30;
  static const double continueListeningMaxProgressFraction = 0.95;

  AppDatabase();

  Future<void> saveAudiobook(domain.UnifiedAudiobook book) async {
    _audiobooks[book.id] = book;
  }

  Future<domain.UnifiedAudiobook?> getAudiobook(String id) async {
    final book = _audiobooks[id];
    if (book == null) return null;
    final userCover = _userCoverPaths[id];
    if (userCover == null) return book;
    return domain.UnifiedAudiobook(
      id: book.id,
      title: book.title,
      author: book.author,
      description: book.description,
      coverArtUrlOrPath: userCover,
      source: book.source,
      origin: book.origin,
      narrators: book.narrators,
      chapters: book.chapters,
      isDownloaded: book.isDownloaded,
    );
  }

  Future<List<domain.UnifiedAudiobook>> getAllAudiobooks() async {
    return _audiobooks.values.toList();
  }

  Future<void> saveProgress({
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    DateTime? updatedAt,
  }) async {
    _progress[audiobookId] = PlaybackProgressData(
      audiobookId: audiobookId,
      chapterIndex: chapterIndex,
      positionSeconds: positionSeconds,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Future<PlaybackProgressData?> getProgress(String audiobookId) async {
    return _progress[audiobookId];
  }

  Future<PlaybackProgressData?> getMostRecentProgress() async {
    if (_progress.isEmpty) return null;
    final values = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values.first;
  }

  /// See `AppDatabase.getContinueListening` in `app_database_io.dart` for
  /// the full rationale (identical rule set, applied in-memory here).
  Future<List<domain.UnifiedAudiobook>> getContinueListening({
    int limit = 5,
  }) async {
    final entries = _progress.values
        .where((p) => p.positionSeconds > continueListeningMinPositionSeconds)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final List<domain.UnifiedAudiobook> results = [];
    for (final progress in entries) {
      if (results.length >= limit) break;
      if (_hiddenFromContinue.contains(progress.audiobookId)) continue;

      final book = _audiobooks[progress.audiobookId];
      if (book == null) continue;

      final totalRuntime =
          book.chapters.fold<int>(0, (sum, c) => sum + c.durationSeconds);
      if (totalRuntime > 0) {
        final threshold = totalRuntime * continueListeningMaxProgressFraction;
        if (progress.positionSeconds >= threshold) continue;
      }

      final resolved = await getAudiobook(progress.audiobookId);
      if (resolved != null) results.add(resolved);
    }
    return results;
  }

  Future<void> pinBook(String audiobookId) async {
    if (!_audiobooks.containsKey(audiobookId)) return;
    if (_pinOrder.containsKey(audiobookId)) return;
    if (_pinOrder.length >= maxPinnedBooks) {
      throw const PinLimitExceededException(maxPinnedBooks);
    }
    final nextOrder =
        _pinOrder.values.fold<int>(-1, (m, v) => v > m ? v : m) + 1;
    _pinOrder[audiobookId] = nextOrder;
  }

  Future<PinResult> tryPinBook(String audiobookId) async {
    if (!_audiobooks.containsKey(audiobookId)) return PinResult.notFound;
    if (_pinOrder.containsKey(audiobookId)) return PinResult.alreadyPinned;
    try {
      await pinBook(audiobookId);
      return PinResult.pinned;
    } on PinLimitExceededException {
      return PinResult.limitExceeded;
    }
  }

  Future<void> unpinBook(String audiobookId) async {
    _pinOrder.remove(audiobookId);
  }

  Future<List<domain.UnifiedAudiobook>> getPinnedBooks() async {
    final ids = _pinOrder.keys.toList()
      ..sort((a, b) => _pinOrder[a]!.compareTo(_pinOrder[b]!));
    final List<domain.UnifiedAudiobook> results = [];
    for (final id in ids) {
      final book = await getAudiobook(id);
      if (book != null) results.add(book);
    }
    return results;
  }

  Future<void> hideFromContinue(String audiobookId) async {
    _hiddenFromContinue.add(audiobookId);
  }

  Future<void> unhideFromContinue(String audiobookId) async {
    _hiddenFromContinue.remove(audiobookId);
  }

  Future<void> setUserCover(String audiobookId, String coverPath) async {
    _userCoverPaths[audiobookId] = coverPath;
  }

  Future<void> clearUserCover(String audiobookId) async {
    _userCoverPaths.remove(audiobookId);
  }

  /// Mirrors `app_database_io.dart`'s `setCoverUrl` — see its doc comment.
  Future<void> setCoverUrl(String audiobookId, String coverUrl) async {
    final book = _audiobooks[audiobookId];
    if (book == null) return;
    _audiobooks[audiobookId] = domain.UnifiedAudiobook(
      id: book.id,
      title: book.title,
      author: book.author,
      description: book.description,
      coverArtUrlOrPath: coverUrl,
      source: book.source,
      origin: book.origin,
      narrators: book.narrators,
      chapters: book.chapters,
      isDownloaded: book.isDownloaded,
    );
  }

  Future<void> addBookmark({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    required String note,
    int? endPositionSeconds,
    String title = '',
  }) async {
    _bookmarks.removeWhere((b) => b.id == id);
    _bookmarks.add(Bookmark(
      id: id,
      audiobookId: audiobookId,
      chapterIndex: chapterIndex,
      positionSeconds: positionSeconds,
      endPositionSeconds: endPositionSeconds,
      title: title,
      note: note,
      createdAt: DateTime.now(),
    ));
  }

  Future<List<Bookmark>> getBookmarks(String audiobookId) async {
    final matches = _bookmarks
        .where((b) => b.audiobookId == audiobookId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  Future<List<Bookmark>> getClips(String audiobookId) async {
    final all = await getBookmarks(audiobookId);
    return all.where((b) => b.endPositionSeconds != null).toList();
  }

  Future<void> updateBookmark({
    required String id,
    String? note,
    String? title,
    int? positionSeconds,
    int? endPositionSeconds,
  }) async {
    final index = _bookmarks.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final existing = _bookmarks[index];
    _bookmarks[index] = Bookmark(
      id: existing.id,
      audiobookId: existing.audiobookId,
      chapterIndex: existing.chapterIndex,
      positionSeconds: positionSeconds ?? existing.positionSeconds,
      endPositionSeconds: endPositionSeconds ?? existing.endPositionSeconds,
      title: title ?? existing.title,
      note: note ?? existing.note,
      createdAt: existing.createdAt,
    );
  }

  Future<void> deleteBookmark(String id) async {
    _bookmarks.removeWhere((b) => b.id == id);
  }

  Future<void> deleteAudiobook(String id) async {
    _audiobooks.remove(id);
  }

  /// Mirrors `app_database_io.dart`'s `updateChapterAudioPath` — see its
  /// doc comment. Local import doesn't exist on web (see
  /// `services/local_audiobook_import_web.dart`), so nothing ever calls
  /// this in practice; it exists only so both platforms expose the same
  /// `AppDatabase` surface.
  Future<void> updateChapterAudioPath(
      String chapterId, String newAudioPathOrUrl) async {
    for (final entry in _audiobooks.entries) {
      final book = entry.value;
      final chapterIndex = book.chapters.indexWhere((c) => c.id == chapterId);
      if (chapterIndex == -1) continue;
      final oldChapter = book.chapters[chapterIndex];
      final newChapters = List<domain.AudiobookChapter>.from(book.chapters);
      newChapters[chapterIndex] = domain.AudiobookChapter(
        id: oldChapter.id,
        title: oldChapter.title,
        audioPathOrUrl: newAudioPathOrUrl,
        durationSeconds: oldChapter.durationSeconds,
        isStream: oldChapter.isStream,
        startMs: oldChapter.startMs,
        endMs: oldChapter.endMs,
      );
      _audiobooks[entry.key] = domain.UnifiedAudiobook(
        id: book.id,
        title: book.title,
        author: book.author,
        description: book.description,
        coverArtUrlOrPath: book.coverArtUrlOrPath,
        source: book.source,
        origin: book.origin,
        narrators: book.narrators,
        chapters: newChapters,
        isDownloaded: book.isDownloaded,
      );
      return;
    }
  }

  Future<void> close() async {}
}

/// Thrown by [AppDatabase.pinBook] when 5 books are already pinned.
/// Mirrors `app_database_io.dart`'s exception of the same name.
class PinLimitExceededException implements Exception {
  final int limit;
  const PinLimitExceededException(this.limit);

  @override
  String toString() =>
      'PinLimitExceededException: cannot pin more than $limit books';
}

enum PinResult { pinned, alreadyPinned, limitExceeded, notFound }

/// Plain-Dart stand-in for drift's generated `PlaybackProgressData`.
class PlaybackProgressData {
  final String audiobookId;
  final int chapterIndex;
  final int positionSeconds;
  final DateTime updatedAt;

  const PlaybackProgressData({
    required this.audiobookId,
    required this.chapterIndex,
    required this.positionSeconds,
    required this.updatedAt,
  });
}

/// Plain-Dart stand-in for drift's generated `Bookmark`.
class Bookmark {
  final String id;
  final String audiobookId;
  final int chapterIndex;
  final int positionSeconds;
  final int? endPositionSeconds;
  final String title;
  final String note;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.audiobookId,
    required this.chapterIndex,
    required this.positionSeconds,
    this.endPositionSeconds,
    this.title = '',
    required this.note,
    required this.createdAt,
  });
}

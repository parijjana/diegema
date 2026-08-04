import '../domain/models/audiobook.dart' as domain;

/// Web implementation of [AppDatabase]: an in-memory store with no
/// dependency on drift, sqlite3, or any wasm worker (see rework_plan.md —
/// "Skip drift on web. Do not stand up the sqlite3 WASM worker for a demo;
/// keep playback progress in memory + localStorage."). This backs the
/// canned web demo only; nothing here persists across a page reload.
///
/// Its public surface intentionally mirrors `app_database_io.dart` (the
/// real drift-backed implementation) method-for-method, so every widget
/// that takes an `AppDatabase` works unmodified on both platforms.
class AppDatabase {
  final Map<String, domain.UnifiedAudiobook> _audiobooks = {};
  final Map<String, PlaybackProgressData> _progress = {};
  final List<Bookmark> _bookmarks = [];

  AppDatabase();

  Future<void> saveAudiobook(domain.UnifiedAudiobook book) async {
    _audiobooks[book.id] = book;
  }

  Future<domain.UnifiedAudiobook?> getAudiobook(String id) async {
    return _audiobooks[id];
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

  Future<void> addBookmark({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    required String note,
  }) async {
    _bookmarks.add(Bookmark(
      id: id,
      audiobookId: audiobookId,
      chapterIndex: chapterIndex,
      positionSeconds: positionSeconds,
      note: note,
      createdAt: DateTime.now(),
    ));
  }

  Future<List<Bookmark>> getBookmarks(String audiobookId) async {
    final matches =
        _bookmarks.where((b) => b.audiobookId == audiobookId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  Future<void> close() async {}
}

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
  final String note;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.audiobookId,
    required this.chapterIndex,
    required this.positionSeconds,
    required this.note,
    required this.createdAt,
  });
}

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../domain/models/audiobook.dart' as domain;

part 'app_database_io.g.dart';

class Audiobooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get description => text()();
  TextColumn get source => text().withDefault(const Constant('Local'))();
  TextColumn get coverUrl => text().nullable()();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get audiobookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get title => text()();
  TextColumn get audioPathOrUrl => text()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isStream => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PlaybackProgress extends Table {
  TextColumn get audiobookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get positionSeconds => integer()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {audiobookId};
}

class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get audiobookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get positionSeconds => integer()();
  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Audiobooks,
    Chapters,
    PlaybackProgress,
    Bookmarks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'unamedaudiobookplayer.sqlite'));
      return NativeDatabase(file);
    });
  }

  // --- Audiobook CRUD ---
  Future<void> saveAudiobook(domain.UnifiedAudiobook book) async {
    await into(audiobooks).insertOnConflictUpdate(
      AudiobooksCompanion.insert(
        id: book.id,
        title: book.title,
        author: book.author,
        description: book.description,
        source: Value(book.source ?? 'Local'),
        coverUrl: Value(book.coverArtUrlOrPath),
        isDownloaded: Value(book.isDownloaded),
      ),
    );

    // Save chapters
    for (int i = 0; i < book.chapters.length; i++) {
      final ch = book.chapters[i];
      await into(chapters).insertOnConflictUpdate(
        ChaptersCompanion.insert(
          id: ch.id,
          audiobookId: book.id,
          chapterIndex: i,
          title: ch.title,
          audioPathOrUrl: ch.audioPathOrUrl,
          durationSeconds: Value(ch.durationSeconds),
          isStream: Value(ch.isStream),
        ),
      );
    }
  }

  Future<domain.UnifiedAudiobook?> getAudiobook(String id) async {
    final bookRow = await (select(audiobooks)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    if (bookRow == null) return null;

    final chapterRows = await (select(chapters)
          ..where((c) => c.audiobookId.equals(id))
          ..orderBy([(c) => OrderingTerm(expression: c.chapterIndex)]))
        .get();

    final domainChapters = chapterRows
        .map(
          (c) => domain.AudiobookChapter(
            id: c.id,
            title: c.title,
            audioPathOrUrl: c.audioPathOrUrl,
            durationSeconds: c.durationSeconds,
            isStream: c.isStream,
          ),
        )
        .toList();

    return domain.UnifiedAudiobook(
      id: bookRow.id,
      title: bookRow.title,
      author: bookRow.author,
      description: bookRow.description,
      source: bookRow.source,
      coverArtUrlOrPath: bookRow.coverUrl,
      chapters: domainChapters,
      isDownloaded: bookRow.isDownloaded,
    );
  }

  Future<List<domain.UnifiedAudiobook>> getAllAudiobooks() async {
    final bookRows = await select(audiobooks).get();
    final List<domain.UnifiedAudiobook> results = [];
    for (final row in bookRows) {
      final fullBook = await getAudiobook(row.id);
      if (fullBook != null) results.add(fullBook);
    }
    return results;
  }

  // --- Playback Progress Persistence ---
  Future<void> saveProgress({
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    DateTime? updatedAt,
  }) async {
    await into(playbackProgress).insertOnConflictUpdate(
      PlaybackProgressCompanion.insert(
        audiobookId: audiobookId,
        chapterIndex: chapterIndex,
        positionSeconds: positionSeconds,
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<PlaybackProgressData?> getProgress(String audiobookId) async {
    return (select(playbackProgress)
          ..where((p) => p.audiobookId.equals(audiobookId)))
        .getSingleOrNull();
  }

  Future<PlaybackProgressData?> getMostRecentProgress() async {
    return (select(playbackProgress)
          ..orderBy([
            (p) =>
                OrderingTerm(expression: p.updatedAt, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  // --- Bookmarks ---
  Future<void> addBookmark({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    required String note,
  }) async {
    await into(bookmarks).insertOnConflictUpdate(
      BookmarksCompanion.insert(
        id: id,
        audiobookId: audiobookId,
        chapterIndex: chapterIndex,
        positionSeconds: positionSeconds,
        note: note,
      ),
    );
  }

  Future<List<Bookmark>> getBookmarks(String audiobookId) async {
    return (select(bookmarks)
          ..where((b) => b.audiobookId.equals(audiobookId))
          ..orderBy([
            (b) =>
                OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }
}

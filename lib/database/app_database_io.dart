import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/utils/book_identity.dart';
import '../domain/models/audiobook.dart' as domain;

part 'app_database_io.g.dart';

class Audiobooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get description => text()();
  TextColumn get source => text().withDefault(const Constant('Local'))();

  /// Where the book came from: `'librivox'` or `'local'`. See
  /// `core/utils/book_identity.dart`. Added in schema v2; defaults to
  /// `'local'` for both fresh installs and the v1->v2 backfill of rows
  /// whose true origin cannot be inferred.
  TextColumn get origin =>
      text().withDefault(const Constant(BookIdentity.originLocal))();

  TextColumn get coverUrl => text().nullable()();

  /// User-supplied cover art path (schema v2). Takes precedence over
  /// [coverUrl] / the procedural cover whenever set — see
  /// `ui_redesign_plan.md` Screen 2. Nothing writes this column yet; the
  /// column and DAO methods exist ahead of the UI that sets it.
  TextColumn get userCoverPath => text().nullable()();

  BoolColumn get isDownloaded => boolean().withDefault(const Constant(true))();

  /// Pinned to the "Now Playing" default screen (schema v2). Max 5,
  /// enforced in [AppDatabase.pinBook] — never silently evicted.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Stable sort key among pinned books, ascending. `null` when not
  /// pinned. Not a dense 0..4 sequence — gaps are fine, only relative
  /// order matters — so unpinning never has to renumber siblings.
  IntColumn get pinOrder => integer().nullable()();

  /// Dismissed from the "continue listening" surface (schema v2). Does
  /// NOT delete the book or its [PlaybackProgress] row; it only affects
  /// [AppDatabase.getContinueListening]'s WHERE clause.
  BoolColumn get hiddenFromContinue =>
      boolean().withDefault(const Constant(false))();

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

  /// Offsets in milliseconds into [audioPathOrUrl] (schema v3), for a
  /// chapter that is a marker inside a shared M4B file rather than its own
  /// file. `null` means "the whole file" — see
  /// `domain/models/audiobook.dart`'s `AudiobookChapter.startMs`/`endMs`.
  IntColumn get startMs => integer().nullable()();
  IntColumn get endMs => integer().nullable()();

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

/// Bookmarks and audio clips share one table (Aulos port — see
/// `design_features/bookmarks_system.md` and `ui_redesign_plan.md`'s
/// "Bookmarks & audio clips" section). A row with `endPositionSeconds ==
/// null` is a plain point bookmark; a row with it set is a bounded clip
/// (`positionSeconds` = start, `endPositionSeconds` = end).
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get audiobookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get positionSeconds => integer()();

  /// Clip end, in seconds. `null` means this row is a point bookmark, not
  /// a clip (schema v2).
  IntColumn get endPositionSeconds => integer().nullable()();

  /// Short user-given name, distinct from the free-text [note] (schema
  /// v2). Defaults to `''` so existing/legacy rows never have a null
  /// title to render.
  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Thrown by [AppDatabase.pinBook] when the caller tries to pin a 6th
/// book. The UI is expected to catch this and show a message — pinning
/// never silently evicts an existing pin (ui_redesign_plan.md: "reject
/// with a message, or evict the oldest" was decided as reject).
class PinLimitExceededException implements Exception {
  final int limit;
  const PinLimitExceededException(this.limit);

  @override
  String toString() =>
      'PinLimitExceededException: cannot pin more than $limit books';
}

/// Result of a pin attempt, so callers that prefer a typed result over a
/// try/catch can use [AppDatabase.tryPinBook] instead.
enum PinResult { pinned, alreadyPinned, limitExceeded, notFound }

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

  /// Maximum number of books that may be pinned to the "Now Playing"
  /// default screen at once (ui_redesign_plan.md Screen 1).
  static const int maxPinnedBooks = 5;

  /// A book counts as "in progress" (continue-listening eligible) once
  /// its saved position passes this many seconds — filters out a book
  /// opened by accident or sampled for a few seconds.
  static const int continueListeningMinPositionSeconds = 30;

  /// `PlaybackProgress.positionSeconds` value meaning "the listener marked
  /// this book finished". A real position is never negative, so the existing
  /// row carries the flag without a schema change, and [getContinueListening]
  /// (`positionSeconds > continueListeningMinPositionSeconds`) already
  /// excludes it.
  static const int finishedPositionSeconds = -1;

  /// ...and stops counting once position reaches this fraction of the
  /// book's total known runtime — filters out books that are
  /// effectively finished. See [getContinueListening] for how this is
  /// applied when the runtime is unknown (0), which is common for local
  /// content whose chapter durations were never probed.
  static const double continueListeningMaxProgressFraction = 0.95;

  static const int _schemaVersion = 3;

  @override
  int get schemaVersion => _schemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Each block is also gated on `to` (not just `from`) so that
          // `SchemaVerifier.migrateAndValidate(db, N)` — which spoofs the
          // *target* version to validate an intermediate step in isolation
          // (see test/database/migration_test.dart) — only ever applies the
          // migrations up to that spoofed target, not every block written
          // since.
          if (from < 2 && to >= 2) {
            await m.addColumn(audiobooks, audiobooks.origin);
            await m.addColumn(audiobooks, audiobooks.userCoverPath);
            await m.addColumn(audiobooks, audiobooks.isPinned);
            await m.addColumn(audiobooks, audiobooks.pinOrder);
            await m.addColumn(audiobooks, audiobooks.hiddenFromContinue);
            await m.addColumn(bookmarks, bookmarks.endPositionSeconds);
            await m.addColumn(bookmarks, bookmarks.title);

            // No real users exist yet (see rework_plan.md), so this is a
            // clean deterministic re-key rather than a data-preserving
            // migration in the strictest sense — but it is written to
            // behave correctly on a populated DB from here on, since the
            // next release onward that will matter. It must not throw on
            // an empty or partially-populated DB (no chapters for a
            // legacy row, no audiobooks at all, etc).
            await _rekeyLegacyLocalIds();
            await _backfillOrigin();
          }
          if (from < 3 && to >= 3) {
            // M4B chapter markers (schema v3) — see
            // `core/utils/mp4_chapters.dart`. Existing chapter rows are
            // untouched: null start/end continues to mean "the whole
            // file", exactly as it did before this column existed.
            await m.addColumn(chapters, chapters.startMs);
            await m.addColumn(chapters, chapters.endMs);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // `validateDatabaseSchema` (drift_dev's schema verifier) is
          // deliberately NOT called here: it lives in `drift_dev`, a
          // dev_dependency not shipped in release builds, and it exists
          // to be driven from migration *tests* against a captured
          // schema snapshot (see drift_schemas/ and
          // test/database/migration_test.dart), not from production
          // startup code. `beforeOpen` only needs the pragma above.
        },
      );

  /// Rewrites any pre-v2 `hashCode`-derived local ids
  /// (`local_<hash>`, `imported_folder_<hash>`, `imported_files_<hash>`)
  /// to the new sha256-of-path scheme (see `core/utils/book_identity.dart`).
  ///
  /// The original absolute path is not stored anywhere for these legacy
  /// rows — only the hash was ever persisted — so it cannot be recovered
  /// from the id itself. What *is* recoverable is each chapter's
  /// `audioPathOrUrl`, which is a real filesystem path. The new id is
  /// derived from the first chapter's path, which is exactly what
  /// [BookIdentity.localIdForPath] would have produced had the current
  /// scheme been used at import time for a single-folder import.
  ///
  /// A legacy row with zero chapters (a partially-populated DB, or one
  /// where import failed after the book row was written) has nothing to
  /// derive a stable id from; it is left as-is rather than crashing the
  /// migration.
  Future<void> _rekeyLegacyLocalIds() async {
    final allBooks = await select(audiobooks).get();
    for (final book in allBooks) {
      if (!BookIdentity.isLegacyLocalId(book.id)) continue;

      final chapterRows = await (select(chapters)
            ..where((c) => c.audiobookId.equals(book.id))
            ..orderBy([(c) => OrderingTerm(expression: c.chapterIndex)]))
          .get();
      if (chapterRows.isEmpty) continue;

      final newId =
          BookIdentity.localIdForPath(chapterRows.first.audioPathOrUrl);
      if (newId == book.id) continue;

      final oldId = book.id;
      await transaction(() async {
        await (update(audiobooks)..where((a) => a.id.equals(oldId)))
            .write(AudiobooksCompanion(id: Value(newId)));
        await (update(chapters)..where((c) => c.audiobookId.equals(oldId)))
            .write(ChaptersCompanion(audiobookId: Value(newId)));
        await (update(playbackProgress)
              ..where((p) => p.audiobookId.equals(oldId)))
            .write(PlaybackProgressCompanion(audiobookId: Value(newId)));
        await (update(bookmarks)..where((b) => b.audiobookId.equals(oldId)))
            .write(BookmarksCompanion(audiobookId: Value(newId)));
      });
    }
  }

  /// Backfills [Audiobooks.origin] for rows written before the column
  /// existed, from the free-text `source` label they were saved with.
  /// Heuristic, not authoritative — acceptable because, as of this
  /// migration landing, no real users exist to have accumulated
  /// ambiguous rows. Every row written going forward sets `origin`
  /// explicitly at the call site (see `core/utils/book_identity.dart`
  /// usages).
  Future<void> _backfillOrigin() async {
    final allBooks = await select(audiobooks).get();
    for (final book in allBooks) {
      final sourceLower = (book.source).toLowerCase();
      final looksLikeLibrivox =
          sourceLower.contains('librivox') || sourceLower.contains('download');
      final origin = looksLikeLibrivox
          ? BookIdentity.originLibrivox
          : BookIdentity.originLocal;
      await (update(audiobooks)..where((a) => a.id.equals(book.id)))
          .write(AudiobooksCompanion(origin: Value(origin)));
    }
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final file = await _databaseFile();
      await backupBeforeMigration(file);
      return NativeDatabase(file);
    });
  }

  static Future<File> _databaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'diegema.sqlite'));
  }

  /// The schema version stored in [file], read from the SQLite header
  /// (`user_version`, 4 bytes big-endian at offset 60) without opening it.
  /// Null when there is no database yet or the file isn't one.
  static Future<int?> storedSchemaVersion(File file) async {
    if (!await file.exists()) return null;
    final raf = await file.open();
    try {
      final header = await raf.read(64);
      if (header.length < 64 ||
          String.fromCharCodes(header.sublist(0, 15)) != 'SQLite format 3') {
        return null;
      }
      return ByteData.sublistView(header).getUint32(60);
    } finally {
      await raf.close();
    }
  }

  /// Whether the library on disk was written by a newer Diegema than this
  /// one. Opening it would let this build "upgrade" a schema it doesn't
  /// know, so `main` refuses and asks for an update instead.
  static Future<bool> isLibraryFromNewerVersion() async {
    try {
      final stored = await storedSchemaVersion(await _databaseFile());
      return stored != null && stored > _schemaVersion;
    } catch (_) {
      // Can't tell: open as usual rather than lock the user out.
      return false;
    }
  }

  /// Copies [file] to `<file>.v<N>.bak` before this build migrates it from
  /// schema N, so a migration that goes wrong can be undone by hand.
  static Future<void> backupBeforeMigration(File file) async {
    final stored = await storedSchemaVersion(file);
    if (stored == null || stored == 0 || stored >= _schemaVersion) return;
    await file.copy('${file.path}.v$stored.bak');
  }

  // --- Audiobook CRUD ---
  Future<void> saveAudiobook(domain.UnifiedAudiobook book) =>
      transaction(() => _saveAudiobook(book));

  Future<void> _saveAudiobook(domain.UnifiedAudiobook book) async {
    await into(audiobooks).insertOnConflictUpdate(
      AudiobooksCompanion.insert(
        id: book.id,
        title: book.title,
        author: book.author,
        description: book.description,
        source: Value(book.source ?? 'Local'),
        origin: Value(book.origin),
        coverUrl: Value(book.coverArtUrlOrPath),
        isDownloaded: Value(book.isDownloaded),
      ),
    );

    // Drop chapters the new copy no longer has, or streaming then
    // downloading a book (`<id>_stream_N` vs `<id>_local_N`) leaves both
    // sets under one book. A save with no chapters keeps the old ones: that
    // is a metadata-only save or a failed fetch, not a book with none.
    if (book.chapters.isNotEmpty) {
      final keep = book.chapters.map((c) => c.id).toList();
      await (delete(chapters)
            ..where((c) => c.audiobookId.equals(book.id) & c.id.isNotIn(keep)))
          .go();
    }

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
          startMs: Value(ch.startMs),
          endMs: Value(ch.endMs),
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
            startMs: c.startMs,
            endMs: c.endMs,
          ),
        )
        .toList();

    return domain.UnifiedAudiobook(
      id: bookRow.id,
      title: bookRow.title,
      author: bookRow.author,
      description: bookRow.description,
      source: bookRow.source,
      origin: bookRow.origin,
      coverArtUrlOrPath: bookRow.userCoverPath ?? bookRow.coverUrl,
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

  /// Marks [audiobookId] finished: its progress row is kept, pointing at
  /// the last chapter, with [kFinishedPositionSeconds] as the position — see
  /// [finishedPositionSeconds] for why this needs no schema change. The next real
  /// [saveProgress] (i.e. the listener playing it again) replaces the marker.
  Future<void> markFinished(String audiobookId,
      {required int lastChapterIndex}) {
    return saveProgress(
      audiobookId: audiobookId,
      chapterIndex: lastChapterIndex,
      positionSeconds: finishedPositionSeconds,
    );
  }

  /// Forgets the saved position for [audiobookId]; the book stays in the
  /// library and starts from the beginning next time.
  Future<void> resetProgress(String audiobookId) async {
    await (delete(playbackProgress)
          ..where((p) => p.audiobookId.equals(audiobookId)))
        .go();
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

  /// Sum of all known chapter durations for [audiobookId] — the book's
  /// "total known runtime". `0` when nothing is known yet (common for
  /// local content: the local scanner/importer never probes real audio
  /// duration, so every local chapter's `durationSeconds` is `0` — see
  /// rework_plan.md item 14). Callers must not divide by this without
  /// checking for zero; see [getContinueListening].
  Future<int> _totalKnownRuntimeSeconds(String audiobookId) async {
    final durationSum = chapters.durationSeconds.sum();
    final query = selectOnly(chapters)
      ..addColumns([durationSum])
      ..where(chapters.audiobookId.equals(audiobookId));
    final row = await query.getSingleOrNull();
    return row?.read(durationSum) ?? 0;
  }

  /// Books with an in-progress [PlaybackProgress] row, most-recently
  /// updated first, for the "Now Playing" idle-state shortlist
  /// (ui_redesign_plan.md Screen 1).
  ///
  /// "In progress" means:
  /// - `positionSeconds > continueListeningMinPositionSeconds` (not just
  ///   sampled for a few seconds), AND
  /// - `hiddenFromContinue == false` (dismissed books never resurface
  ///   here — but their progress row and the book itself are untouched;
  ///   see [hideFromContinue]), AND
  /// - the book is not "effectively finished": `positionSeconds <
  ///   totalKnownRuntime * continueListeningMaxProgressFraction`.
  ///
  /// **Unknown-runtime rule**: when a book's total known runtime is `0`
  /// (all local chapters have `durationSeconds == 0` — nothing has been
  /// probed), the 95%-complete check is skipped entirely rather than
  /// dividing by zero or treating `0 as 95% of 0` (which would wrongly
  /// exclude every local book the instant it has *any* progress, since
  /// `position < 0` is never true). The book stays eligible for
  /// continue-listening for as long as it has an in-progress row; only
  /// the explicit dismiss action removes it. This is deliberately
  /// permissive — a false "still in progress" for an unprobed local book
  /// is a much smaller annoyance than a book disappearing from the list
  /// the moment it is opened.
  Future<List<domain.UnifiedAudiobook>> getContinueListening({
    int limit = 5,
  }) async {
    final progressQuery = select(playbackProgress)
      ..where((p) => p.positionSeconds
          .isBiggerThanValue(continueListeningMinPositionSeconds))
      ..orderBy([
        (p) => OrderingTerm(expression: p.updatedAt, mode: OrderingMode.desc)
      ]);
    final progressRows = await progressQuery.get();

    final List<domain.UnifiedAudiobook> results = [];
    for (final progress in progressRows) {
      if (results.length >= limit) break;

      final bookRow = await (select(audiobooks)
            ..where((a) => a.id.equals(progress.audiobookId)))
          .getSingleOrNull();
      if (bookRow == null) continue;
      if (bookRow.hiddenFromContinue) continue;

      final totalRuntime =
          await _totalKnownRuntimeSeconds(progress.audiobookId);
      if (totalRuntime > 0) {
        final threshold = totalRuntime * continueListeningMaxProgressFraction;
        if (progress.positionSeconds >= threshold) continue;
      }
      // totalRuntime == 0: unknown runtime, see doc comment above — the
      // book stays eligible.

      final book = await getAudiobook(progress.audiobookId);
      if (book != null) results.add(book);
    }
    return results;
  }

  // --- Pinning ---

  /// Pins [audiobookId] to the "Now Playing" default screen. Throws
  /// [PinLimitExceededException] when [maxPinnedBooks] are already
  /// pinned — pinning never silently evicts an existing pin. No-op (does
  /// not throw) if the book is already pinned. Assigns the next
  /// `pinOrder` so newly pinned books sort last.
  Future<void> pinBook(String audiobookId) async {
    final book = await (select(audiobooks)
          ..where((a) => a.id.equals(audiobookId)))
        .getSingleOrNull();
    if (book == null) return;
    if (book.isPinned) return;

    final pinnedCount = await _pinnedCount();
    if (pinnedCount >= maxPinnedBooks) {
      throw const PinLimitExceededException(maxPinnedBooks);
    }

    final nextOrder = await _nextPinOrder();
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId))).write(
      AudiobooksCompanion(
        isPinned: const Value(true),
        pinOrder: Value(nextOrder),
      ),
    );
  }

  /// Same as [pinBook] but returns a [PinResult] instead of throwing, for
  /// callers that prefer to branch on a value.
  Future<PinResult> tryPinBook(String audiobookId) async {
    final book = await (select(audiobooks)
          ..where((a) => a.id.equals(audiobookId)))
        .getSingleOrNull();
    if (book == null) return PinResult.notFound;
    if (book.isPinned) return PinResult.alreadyPinned;

    try {
      await pinBook(audiobookId);
      return PinResult.pinned;
    } on PinLimitExceededException {
      return PinResult.limitExceeded;
    }
  }

  Future<void> unpinBook(String audiobookId) async {
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId))).write(
      const AudiobooksCompanion(
        isPinned: Value(false),
        pinOrder: Value(null),
      ),
    );
  }

  /// Pinned books in stable, user-meaningful order (ascending `pinOrder`
  /// — the order they were pinned in).
  Future<List<domain.UnifiedAudiobook>> getPinnedBooks() async {
    final rows = await (select(audiobooks)
          ..where((a) => a.isPinned.equals(true))
          ..orderBy([(a) => OrderingTerm(expression: a.pinOrder)]))
        .get();
    final List<domain.UnifiedAudiobook> results = [];
    for (final row in rows) {
      final book = await getAudiobook(row.id);
      if (book != null) results.add(book);
    }
    return results;
  }

  Future<int> _pinnedCount() async {
    final countExp = audiobooks.id.count();
    final query = selectOnly(audiobooks)
      ..addColumns([countExp])
      ..where(audiobooks.isPinned.equals(true));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> _nextPinOrder() async {
    final maxExp = audiobooks.pinOrder.max();
    final query = selectOnly(audiobooks)..addColumns([maxExp]);
    final row = await query.getSingle();
    final currentMax = row.read(maxExp);
    return (currentMax ?? -1) + 1;
  }

  // --- Hidden-from-continue ---

  /// Hides [audiobookId] from [getContinueListening]. Does NOT delete the
  /// book or its [PlaybackProgress] row — only affects that one surface.
  Future<void> hideFromContinue(String audiobookId) async {
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId)))
        .write(const AudiobooksCompanion(hiddenFromContinue: Value(true)));
  }

  Future<void> unhideFromContinue(String audiobookId) async {
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId)))
        .write(const AudiobooksCompanion(hiddenFromContinue: Value(false)));
  }

  // --- User-supplied cover art ---

  /// Sets a user-supplied cover for [audiobookId]. Takes precedence over
  /// the network/procedural cover wherever a cover is resolved — see
  /// [getAudiobook], which returns `userCoverPath ?? coverUrl`.
  Future<void> setUserCover(String audiobookId, String coverPath) async {
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId)))
        .write(AudiobooksCompanion(userCoverPath: Value(coverPath)));
  }

  Future<void> clearUserCover(String audiobookId) async {
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId)))
        .write(const AudiobooksCompanion(userCoverPath: Value(null)));
  }

  /// Sets the auto-found cover URL for [audiobookId] — the post-save online
  /// lookup (step 3 of the local-import cover pipeline, see
  /// `services/cover_lookup_service.dart`) and the once-per-launch backfill
  /// both write here, never to [userCoverPath]. [getAudiobook] still
  /// prefers `userCoverPath` over this whenever both are set.
  Future<void> setCoverUrl(String audiobookId, String coverUrl) async {
    await (update(audiobooks)..where((a) => a.id.equals(audiobookId)))
        .write(AudiobooksCompanion(coverUrl: Value(coverUrl)));
  }

  // --- Bookmarks / audio clips ---

  /// Creates a bookmark or clip. A `null` [endPositionSeconds] (the
  /// default) is a point bookmark; passing a value makes it a bounded
  /// clip (Aulos port — see `design_features/bookmarks_system.md`).
  Future<void> addBookmark({
    required String id,
    required String audiobookId,
    required int chapterIndex,
    required int positionSeconds,
    required String note,
    int? endPositionSeconds,
    String title = '',
  }) async {
    await into(bookmarks).insertOnConflictUpdate(
      BookmarksCompanion.insert(
        id: id,
        audiobookId: audiobookId,
        chapterIndex: chapterIndex,
        positionSeconds: positionSeconds,
        endPositionSeconds: Value(endPositionSeconds),
        title: Value(title),
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

  /// Clips are bookmarks with a non-null [Bookmarks.endPositionSeconds].
  /// Convenience filter over [getBookmarks] for the future saved-clips
  /// view (ui_redesign_plan.md's "Book view").
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
    await (update(bookmarks)..where((b) => b.id.equals(id))).write(
      BookmarksCompanion(
        note: note != null ? Value(note) : const Value.absent(),
        title: title != null ? Value(title) : const Value.absent(),
        positionSeconds: positionSeconds != null
            ? Value(positionSeconds)
            : const Value.absent(),
        endPositionSeconds: endPositionSeconds != null
            ? Value(endPositionSeconds)
            : const Value.absent(),
      ),
    );
  }

  Future<void> deleteBookmark(String id) async {
    await (delete(bookmarks)..where((b) => b.id.equals(id))).go();
  }

  // --- Chapters ---

  /// Rewrites one chapter's [Chapters.audioPathOrUrl] in place, by chapter
  /// id — used by `local_import_migration_service_io.dart` to point an
  /// already-imported chapter at its newly-copied, durable file without
  /// touching the chapter's id, `startMs`/`endMs` offsets, or anything
  /// else (progress and bookmarks are keyed off the book/chapter index,
  /// not the path, so neither needs updating here).
  Future<void> updateChapterAudioPath(
      String chapterId, String newAudioPathOrUrl) async {
    await (update(chapters)..where((c) => c.id.equals(chapterId))).write(
      ChaptersCompanion(audioPathOrUrl: Value(newAudioPathOrUrl)),
    );
  }

  /// Removes a book row and its chapters. Progress and bookmarks are left
  /// alone; callers only delete rows that have none.
  Future<void> deleteAudiobook(String id) async {
    await transaction(() async {
      await (delete(chapters)..where((c) => c.audiobookId.equals(id))).go();
      await (delete(audiobooks)..where((a) => a.id.equals(id))).go();
    });
  }

  /// Removes a book completely: its row, chapters, saved progress and
  /// bookmarks. Used by "Remove from library"; [deleteAudiobook] keeps
  /// progress/bookmarks and stays for its folder-removal callers.
  Future<void> deleteAudiobookAndUserData(String id) async {
    await transaction(() async {
      await (delete(playbackProgress)..where((r) => r.audiobookId.equals(id)))
          .go();
      await (delete(bookmarks)..where((b) => b.audiobookId.equals(id))).go();
      await (delete(chapters)..where((c) => c.audiobookId.equals(id))).go();
      await (delete(audiobooks)..where((a) => a.id.equals(id))).go();
    });
  }

  /// Rewrites every stored path under [from] to sit under [to] instead, for
  /// when the app's own documents folder moves. iOS does that on an app
  /// update or reinstall (a new container UUID), and the database holds
  /// absolute paths to downloads, copied imports and saved covers.
  ///
  /// Books found by scanning the downloads folder are keyed by a hash of
  /// that folder's absolute path ([BookIdentity.localIdForPath]); left alone
  /// they would come back from the next scan as duplicates under a new id,
  /// so they are re-keyed too, carrying their progress and bookmarks. Other
  /// ids are never derived again and stay as they are.
  ///
  /// Returns how many books had a path rewritten.
  Future<int> rebaseAppPaths(String from, String to) async {
    final oldRoot = p.normalize(from);
    final newRoot = p.normalize(to);
    if (oldRoot == newRoot) return 0;

    String? moved(String? path) => path != null && p.isWithin(oldRoot, path)
        ? p.join(newRoot, p.relative(path, from: oldRoot))
        : null;

    var touched = 0;
    await transaction(() async {
      for (final book in await select(audiobooks).get()) {
        final chapterRows = await (select(chapters)
              ..where((c) => c.audiobookId.equals(book.id))
              ..orderBy([(c) => OrderingTerm(expression: c.chapterIndex)]))
            .get();
        var changed = false;
        for (final ch in chapterRows) {
          final next = moved(ch.audioPathOrUrl);
          if (next == null) continue;
          changed = true;
          await (update(chapters)..where((c) => c.id.equals(ch.id)))
              .write(ChaptersCompanion(audioPathOrUrl: Value(next)));
        }
        final cover = moved(book.coverUrl);
        final userCover = moved(book.userCoverPath);
        if (cover != null || userCover != null) {
          changed = true;
          await (update(audiobooks)..where((a) => a.id.equals(book.id)))
              .write(AudiobooksCompanion(
            coverUrl: cover == null ? const Value.absent() : Value(cover),
            userCoverPath:
                userCover == null ? const Value.absent() : Value(userCover),
          ));
        }
        if (!changed) continue;
        touched++;

        if (chapterRows.isEmpty) continue;
        final oldFolder = p.dirname(chapterRows.first.audioPathOrUrl);
        final newFolder = moved(oldFolder);
        if (newFolder == null ||
            book.id != BookIdentity.localIdForPath(oldFolder)) {
          continue;
        }
        final oldId = book.id;
        final newId = BookIdentity.localIdForPath(newFolder);
        await (update(audiobooks)..where((a) => a.id.equals(oldId)))
            .write(AudiobooksCompanion(id: Value(newId)));
        await (update(chapters)..where((c) => c.audiobookId.equals(oldId)))
            .write(ChaptersCompanion(audiobookId: Value(newId)));
        await (update(playbackProgress)
              ..where((r) => r.audiobookId.equals(oldId)))
            .write(PlaybackProgressCompanion(audiobookId: Value(newId)));
        await (update(bookmarks)..where((b) => b.audiobookId.equals(oldId)))
            .write(BookmarksCompanion(audiobookId: Value(newId)));
      }
    });
    return touched;
  }
}

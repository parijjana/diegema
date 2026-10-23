// Migration tests for AppDatabase, using drift's SchemaVerifier against
// the schema snapshots captured in drift_schemas/ (dumped via
// `dart run drift_dev schema dump` / `schema generate` — see the
// migration-tooling section of rework_plan.md and MigrationStrategy in
// lib/database/app_database_io.dart).
//
// These tests run against no network access, matching this project's
// test-suite convention (see test/widget_test.dart).
//
// ignore_for_file: prefer_single_quotes
// (raw SQL literals below are full of single quotes; double-quoting the
// Dart string around them keeps every INSERT readable instead of
// escaping each one)
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database_io.dart';

import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('AppDatabase schema migrations', () {
    test('all schema versions have a valid schema', () async {
      for (final version in GeneratedHelper.versions) {
        final schema = await verifier.schemaAt(version);
        final database = AppDatabase(schema.newConnection());
        await database.close();
        schema.rawDatabase.close();
      }
    });

    test(
        'upgrade from v1 to v2 preserves existing rows and '
        'backfills the new columns', () async {
      // Start a real v1 database and seed it exactly the way the
      // pre-migration app would have: a "legacy" locally-imported book
      // using the old hashCode-derived id scheme, a LibriVox-sourced
      // book, its chapters, playback progress, and a bookmark. None of
      // the v2-only columns (origin, isPinned, pinOrder,
      // hiddenFromContinue, userCoverPath, endPositionSeconds, title)
      // exist yet at this point.
      final v1Schema = await verifier.schemaAt(1);
      final rawDb = v1Schema.rawDatabase;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      rawDb.execute(
        "INSERT INTO audiobooks (id, title, author, description, source, "
        "cover_url, is_downloaded, created_at) VALUES "
        "('local_123456', 'Legacy Local Book', 'Local Author', "
        "'A locally imported book with a hashCode-derived id', "
        "'Local Folder', NULL, 1, $now)",
      );
      rawDb.execute(
        "INSERT INTO chapters (id, audiobook_id, chapter_index, title, "
        "audio_path_or_url, duration_seconds, is_stream) VALUES "
        "('local_123456_ch_0', 'local_123456', 0, 'Chapter One', "
        "'/Users/test/Audiobooks/Legacy Book/Chapter One.mp3', 1800, 0)",
      );
      rawDb.execute(
        "INSERT INTO audiobooks (id, title, author, description, source, "
        "cover_url, is_downloaded, created_at) VALUES "
        "('frankenstein_1205_librivox', 'Frankenstein', 'Mary Shelley', "
        "'A LibriVox recording', 'LibriVox', "
        "'https://archive.org/services/img/frankenstein_1205_librivox', 0, "
        "$now)",
      );
      rawDb.execute(
        "INSERT INTO playback_progress (audiobook_id, chapter_index, "
        "position_seconds, updated_at) VALUES "
        "('local_123456', 0, 145, $now)",
      );
      rawDb.execute(
        "INSERT INTO bookmarks (id, audiobook_id, chapter_index, "
        "position_seconds, note, created_at) VALUES "
        "('bm_1', 'local_123456', 0, 300, 'Interesting bit', $now)",
      );

      // Now open the *real* AppDatabase (schemaVersion 2) against that
      // same underlying data, which runs the real MigrationStrategy.
      final migratedDb = AppDatabase(v1Schema.newConnection());
      await verifier.migrateAndValidate(migratedDb, 2);

      // 1. Existing rows are preserved, not dropped.
      final allBooks = await migratedDb.getAllAudiobooks();
      expect(allBooks.length, equals(2));

      final bookmarks = await migratedDb.getBookmarks('local_123456');
      // 2. The legacy hashCode-derived id was re-keyed to the new
      // sha256-of-path scheme, and every dependent row (chapters,
      // progress, bookmarks) followed it — nothing is left pointing at
      // the old id.
      final legacyStillPresent = await migratedDb.getAudiobook('local_123456');
      expect(legacyStillPresent, isNull,
          reason: 'legacy hashCode-derived id should have been rewritten');
      expect(bookmarks, isEmpty,
          reason: 'bookmarks should have followed the re-key, none left '
              'under the old id');

      final rekeyedBook = allBooks.firstWhere(
        (b) => b.title == 'Legacy Local Book',
      );
      expect(rekeyedBook.id, isNot(equals('local_123456')));
      expect(rekeyedBook.id, startsWith('local_'));
      expect(rekeyedBook.chapters.length, equals(1));

      final rekeyedProgress = await migratedDb.getProgress(rekeyedBook.id);
      expect(rekeyedProgress, isNotNull);
      expect(rekeyedProgress!.positionSeconds, equals(145));

      final rekeyedBookmarks = await migratedDb.getBookmarks(rekeyedBook.id);
      expect(rekeyedBookmarks.length, equals(1));
      expect(rekeyedBookmarks.first.note, equals('Interesting bit'));
      // New bookmark columns backfill to their documented defaults.
      expect(rekeyedBookmarks.first.endPositionSeconds, isNull);
      expect(rekeyedBookmarks.first.title, equals(''));

      // 3. origin was backfilled sensibly from the old `source` label.
      expect(rekeyedBook.origin, equals('local'));
      final librivoxBook = allBooks.firstWhere(
        (b) => b.id == 'frankenstein_1205_librivox',
      );
      expect(librivoxBook.origin, equals('librivox'));

      // 4. New feature columns default safely for pre-existing rows.
      final pinned = await migratedDb.getPinnedBooks();
      expect(pinned, isEmpty);

      await migratedDb.close();
    });

    test('upgrade from v1 to v2 does not crash on an empty database', () async {
      final v1Schema = await verifier.schemaAt(1);
      final migratedDb = AppDatabase(v1Schema.newConnection());
      await verifier.migrateAndValidate(migratedDb, 2);

      final allBooks = await migratedDb.getAllAudiobooks();
      expect(allBooks, isEmpty);
      await migratedDb.close();
    });

    test(
        'upgrade from v1 to v2 does not crash on a legacy book with no '
        'chapters (partially-populated DB)', () async {
      final v1Schema = await verifier.schemaAt(1);
      final rawDb = v1Schema.rawDatabase;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      rawDb.execute(
        "INSERT INTO audiobooks (id, title, author, description, source, "
        "cover_url, is_downloaded, created_at) VALUES "
        "('imported_folder_987654', 'Orphaned Import', 'Local Author', "
        "'Import that never got chapters written', 'Local Folder', NULL, 1, "
        "$now)",
      );

      final migratedDb = AppDatabase(v1Schema.newConnection());
      // Must not throw even though there is no chapter to derive a new
      // id from.
      await verifier.migrateAndValidate(migratedDb, 2);

      final allBooks = await migratedDb.getAllAudiobooks();
      expect(allBooks.length, equals(1));
      // Left as-is: nothing to re-key from.
      expect(allBooks.first.id, equals('imported_folder_987654'));
      expect(allBooks.first.origin, equals('local'));

      await migratedDb.close();
    });

    test(
        'upgrade from v2 to v3 preserves existing chapters and backfills '
        'null start/end (M4B chapter markers)', () async {
      // A v2 database has no start_ms/end_ms columns at all — every
      // existing chapter row predates M4B chapter-marker support and must
      // keep meaning "the whole file" after the upgrade.
      final v2Schema = await verifier.schemaAt(2);
      final rawDb = v2Schema.rawDatabase;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      rawDb.execute(
        "INSERT INTO audiobooks (id, title, author, description, source, "
        "origin, cover_url, user_cover_path, is_downloaded, is_pinned, "
        "pin_order, hidden_from_continue, created_at) VALUES "
        "('local_abcdef', 'A Local Book', 'Local Author', "
        "'A pre-M4B-support local book', 'Local Folder', 'local', NULL, "
        "NULL, 1, 0, NULL, 0, $now)",
      );
      rawDb.execute(
        "INSERT INTO chapters (id, audiobook_id, chapter_index, title, "
        "audio_path_or_url, duration_seconds, is_stream) VALUES "
        "('local_abcdef_ch_0', 'local_abcdef', 0, 'Chapter One', "
        "'/Users/test/Audiobooks/A Local Book/Chapter One.mp3', 1800, 0)",
      );

      final migratedDb = AppDatabase(v2Schema.newConnection());
      await verifier.migrateAndValidate(migratedDb, 3);

      final book = await migratedDb.getAudiobook('local_abcdef');
      expect(book, isNotNull);
      expect(book!.chapters.length, equals(1));
      expect(book.chapters.first.startMs, isNull);
      expect(book.chapters.first.endMs, isNull);
      expect(book.chapters.first.durationSeconds, equals(1800));

      await migratedDb.close();
    });

    test('upgrade from v2 to v3 does not crash on an empty database', () async {
      final v2Schema = await verifier.schemaAt(2);
      final migratedDb = AppDatabase(v2Schema.newConnection());
      await verifier.migrateAndValidate(migratedDb, 3);

      final allBooks = await migratedDb.getAllAudiobooks();
      expect(allBooks, isEmpty);
      await migratedDb.close();
    });

    test(
        'upgrade from v3 to v4 keeps books and adds an empty sync table and '
        'a null portable key', () async {
      final v3Schema = await verifier.schemaAt(3);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      v3Schema.rawDatabase.execute(
        "INSERT INTO audiobooks (id, title, author, description, source, "
        "origin, cover_url, user_cover_path, is_downloaded, is_pinned, "
        "pin_order, hidden_from_continue, created_at) VALUES "
        "('emma_librivox', 'Emma', 'Jane Austen', '', 'LibriVox', "
        "'librivox', NULL, NULL, 1, 0, NULL, 0, $now)",
      );

      final migratedDb = AppDatabase(v3Schema.newConnection());
      await verifier.migrateAndValidate(migratedDb, 4);

      expect((await migratedDb.getAudiobook('emma_librivox'))!.title, 'Emma');
      final row = await (migratedDb.select(migratedDb.audiobooks)).getSingle();
      expect(row.portableKey, isNull);
      expect(await migratedDb.select(migratedDb.syncRecords).get(), isEmpty);
      await migratedDb.close();
    });
  });
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../sync/hlc.dart';
import '../sync/sync_record.dart';
import '../sync/sync_store.dart';
import 'app_database_io.dart';

/// [SyncStore] over the app database's `sync_records` table.
class DriftSyncStore implements SyncStore {
  final AppDatabase db;

  DriftSyncStore(this.db);

  SyncRecord _fromRow(SyncRecordRow row) => SyncRecord(
        kind: SyncKind.values.byName(row.kind),
        key: row.key,
        hlc: Hlc.decode(row.hlc),
        payload: (jsonDecode(row.payload) as Map).cast<String, Object?>(),
        deleted: row.deleted,
      );

  @override
  Future<SyncRecord?> get(String slot) async {
    final row = await (db.select(db.syncRecords)
          ..where((t) => t.slot.equals(slot)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> putAll(List<SyncRecord> records) => db.batch((b) {
        for (final r in records) {
          b.insert(
            db.syncRecords,
            SyncRecordsCompanion.insert(
              slot: r.slot,
              kind: r.kind.name,
              key: r.key,
              deviceId: r.deviceId,
              hlc: r.hlc.encode(),
              payload: Value(jsonEncode(r.payload)),
              deleted: Value(r.deleted),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

  @override
  Future<VersionVector> vector() async {
    final newest = db.syncRecords.hlc.max();
    final rows = await (db.selectOnly(db.syncRecords)
          ..addColumns([db.syncRecords.deviceId, newest])
          ..groupBy([db.syncRecords.deviceId]))
        .get();
    return {
      for (final row in rows)
        row.read(db.syncRecords.deviceId)!: Hlc.decode(row.read(newest)!),
    };
  }

  @override
  Future<List<SyncRecord>> newerThan(VersionVector vector) async {
    final query = db.select(db.syncRecords)
      ..where((t) {
        Expression<bool> known = const Constant(false);
        for (final e in vector.entries) {
          known = known |
              (t.deviceId.equals(e.key) &
                  t.hlc.isBiggerThanValue(e.value.encode()));
        }
        return known | t.deviceId.isNotIn(vector.keys);
      })
      ..orderBy([(t) => OrderingTerm.asc(t.hlc)]);
    return (await query.get()).map(_fromRow).toList();
  }

  @override
  Future<List<SyncRecord>> all() async =>
      (await db.select(db.syncRecords).get()).map(_fromRow).toList();
}

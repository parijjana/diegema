import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database_io.dart';
import 'package:diegema/database/drift_sync_store.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_store.dart';

SyncRecord rec(SyncKind kind, String key, Hlc hlc,
        {Map<String, Object?> payload = const {}, bool deleted = false}) =>
    SyncRecord(
        kind: kind, key: key, hlc: hlc, payload: payload, deleted: deleted);

void main() {
  late AppDatabase db;
  late DriftSyncStore drift;
  late InMemorySyncStore memory;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    drift = DriftSyncStore(db);
    memory = InMemorySyncStore();
  });
  tearDown(() => db.close());

  Future<void> both(List<SyncRecord> records) async {
    await mergeInto(drift, records);
    await mergeInto(memory, records);
  }

  Set<String> enc(List<SyncRecord> rs) => {for (final r in rs) r.encode()};

  test('behaves exactly like the in-memory store', () async {
    await both([
      rec(SyncKind.catalogue, 'lv:emma', const Hlc(10, 0, 'mac'),
          payload: {'title': 'Emma', 'chapters': 55}),
      rec(SyncKind.position, 'lv:emma', const Hlc(11, 0, 'mac'),
          payload: {'chapter': 3, 'ms': 1200}),
      rec(SyncKind.position, 'lv:emma', const Hlc(9, 4, 'phone')),
      rec(SyncKind.bookmark, 'bm-1', const Hlc(12, 0, 'phone'), deleted: true),
    ]);
    // An older record for an existing slot must not replace it.
    await both([rec(SyncKind.position, 'lv:emma', const Hlc(5, 0, 'mac'))]);

    expect(enc(await drift.all()), enc(await memory.all()));
    expect(await drift.vector(), await memory.vector());
    for (final v in <VersionVector>[
      {},
      {'mac': const Hlc(10, 0, 'mac')},
      {'mac': const Hlc(11, 0, 'mac'), 'phone': const Hlc(1, 0, 'phone')},
      {'mac': const Hlc(99, 0, 'mac'), 'phone': const Hlc(99, 0, 'phone')},
    ]) {
      expect(enc(await drift.newerThan(v)), enc(await memory.newerThan(v)),
          reason: '$v');
    }
    expect((await drift.get('position|lv:emma|mac'))!.payload,
        {'chapter': 3, 'ms': 1200});
  });

  test('keepOnly drops other devices\' records, both stores', () async {
    await both([
      rec(SyncKind.position, 'lv:emma', const Hlc(11, 0, 'mac')),
      rec(SyncKind.position, 'lv:emma', const Hlc(9, 4, 'phone')),
      rec(SyncKind.device, 'phone', const Hlc(9, 5, 'phone')),
    ]);
    await drift.keepOnly('phone');
    await memory.keepOnly('phone');
    expect(enc(await drift.all()), enc(await memory.all()));
    expect({for (final r in await drift.all()) r.deviceId}, {'phone'});
  });
}

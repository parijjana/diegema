import 'hlc.dart';
import 'sync_record.dart';

/// For each device, the newest stamp held from it. Two devices swap these
/// and send each other whatever is newer than the other's entry.
typedef VersionVector = Map<String, Hlc>;

/// Where records live: only the latest record per [SyncRecord.slot] is
/// kept, so there is no log to compact. Implemented over the app database
/// (`DriftSyncStore`) and in memory for tests and the CLI.
abstract class SyncStore {
  Future<SyncRecord?> get(String slot);

  /// Writes several records in one transaction.
  Future<void> putAll(List<SyncRecord> records);

  Future<VersionVector> vector();

  /// Every record whose stamp is newer than [vector]'s entry for its device
  /// (all of them for a device [vector] doesn't know).
  Future<List<SyncRecord>> newerThan(VersionVector vector);

  Future<List<SyncRecord>> all();
}

/// Applies [incoming]: a record replaces the one in its slot only when its
/// stamp is newer, so applying the same batch twice, or batches out of
/// order, ends in the same state. Returns the records that changed
/// something.
Future<List<SyncRecord>> mergeInto(
    SyncStore store, Iterable<SyncRecord> incoming) async {
  final winners = <String, SyncRecord>{};
  for (final record in incoming) {
    final seen = winners[record.slot] ?? await store.get(record.slot);
    if (seen == null || record.hlc > seen.hlc) winners[record.slot] = record;
  }
  final changed = winners.values.toList();
  if (changed.isNotEmpty) await store.putAll(changed);
  return changed;
}

class InMemorySyncStore implements SyncStore {
  final Map<String, SyncRecord> _slots = {};

  @override
  Future<SyncRecord?> get(String slot) async => _slots[slot];

  @override
  Future<void> putAll(List<SyncRecord> records) async {
    for (final r in records) {
      _slots[r.slot] = r;
    }
  }

  @override
  Future<VersionVector> vector() async {
    final v = <String, Hlc>{};
    for (final r in _slots.values) {
      final held = v[r.deviceId];
      if (held == null || r.hlc > held) v[r.deviceId] = r.hlc;
    }
    return v;
  }

  @override
  Future<List<SyncRecord>> newerThan(VersionVector vector) async => [
        for (final r in _slots.values)
          if (vector[r.deviceId] == null || r.hlc > vector[r.deviceId]!) r,
      ]..sort((a, b) => a.hlc.compareTo(b.hlc));

  @override
  Future<List<SyncRecord>> all() async => _slots.values.toList();
}

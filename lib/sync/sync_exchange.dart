import 'hlc.dart';
import 'sync_record.dart';
import 'sync_store.dart';

/// One sync between two devices, independent of how bytes travel. Three
/// messages: the initiator sends its vector; the responder answers with
/// what the initiator lacks plus its own vector; the initiator applies that
/// and sends back what the responder lacks. An interrupted exchange loses
/// nothing — merging is idempotent, and the next one resends.
class SyncMessage {
  final VersionVector? vector;
  final List<SyncRecord> records;

  const SyncMessage({this.vector, this.records = const []});

  Map<String, Object?> toJson() => {
        if (vector != null)
          'vector': {for (final e in vector!.entries) e.key: e.value.encode()},
        'records': [for (final r in records) r.toJson()],
      };

  static SyncMessage fromJson(Map<String, Object?> json) {
    final v = json['vector'] as Map?;
    return SyncMessage(
      vector: v == null
          ? null
          : {
              for (final e in v.entries)
                e.key as String: Hlc.decode(e.value as String),
            },
      records: [
        for (final r in (json['records'] as List? ?? const []))
          SyncRecord.fromJson((r as Map).cast<String, Object?>()),
      ],
    );
  }
}

class SyncPeer {
  final SyncStore store;

  /// Called with every record that changed this device's store, so the
  /// clock can move past them and the UI can refresh.
  final void Function(List<SyncRecord> changed)? onChanged;

  SyncPeer(this.store, {this.onChanged});

  /// Initiator, message 1.
  Future<SyncMessage> hello() async =>
      SyncMessage(vector: await store.vector());

  /// Responder: answers message 1 with message 2.
  Future<SyncMessage> answer(SyncMessage hello) async => SyncMessage(
        vector: await store.vector(),
        records: await store.newerThan(hello.vector ?? const {}),
      );

  /// Initiator: applies message 2, returns message 3.
  Future<SyncMessage> complete(SyncMessage answer) async {
    await _apply(answer.records);
    // Built after applying, so nothing just received is echoed back.
    return SyncMessage(
        records: await store.newerThan(answer.vector ?? const {}));
  }

  /// Responder: applies message 3.
  Future<void> finish(SyncMessage last) => _apply(last.records);

  Future<void> _apply(List<SyncRecord> records) async {
    final changed = await mergeInto(store, records);
    if (changed.isNotEmpty) onChanged?.call(changed);
  }
}

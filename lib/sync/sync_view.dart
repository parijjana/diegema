import 'sync_record.dart';

/// A linked device's position in a book.
class DevicePosition {
  final String deviceId;
  final int chapter;
  final int seconds;

  /// Wall time it was saved there (ms since epoch).
  final int atMillis;

  const DevicePosition(
      this.deviceId, this.chapter, this.seconds, this.atMillis);

  /// Whether this is further into the book than [other].
  bool isAhead(DevicePosition other) =>
      chapter > other.chapter ||
      (chapter == other.chapter && seconds > other.seconds);
}

/// A book listed by another device but not in this device's library.
class RemoteBook {
  final String key;
  final String title;
  final String author;

  /// `'librivox'` or `'local'`.
  final String origin;
  final String? archiveId;
  final int chapterCount;
  final int durationSeconds;

  /// Devices that have it.
  final Set<String> deviceIds;

  const RemoteBook({
    required this.key,
    required this.title,
    required this.author,
    required this.origin,
    required this.archiveId,
    required this.chapterCount,
    required this.durationSeconds,
    required this.deviceIds,
  });

  bool get isLibrivox => origin == 'librivox' && archiveId != null;
}

/// What the UI asks of the synced records. Pure: built from a list of
/// records and this device's id, so it is cheap to rebuild after a sync.
class SyncView {
  final String deviceId;
  final List<SyncRecord> _records;

  SyncView(this.deviceId, Iterable<SyncRecord> records)
      : _records = List.unmodifiable(records);

  Iterable<SyncRecord> _others(SyncKind kind, [String? key]) =>
      _records.where((r) =>
          r.kind == kind &&
          r.deviceId != deviceId &&
          (key == null || r.key == key));

  /// Books other devices list (not removed there) whose key is not in
  /// [localKeys], newest listing's details first-come.
  List<RemoteBook> remoteOnly(Set<String> localKeys) {
    final byKey = <String, List<SyncRecord>>{};
    for (final r in _others(SyncKind.catalogue)) {
      if (r.deleted || localKeys.contains(r.key)) continue;
      (byKey[r.key] ??= []).add(r);
    }
    final books = <RemoteBook>[];
    for (final entry in byKey.entries) {
      final newest =
          entry.value.reduce((a, b) => a.hlc > b.hlc ? a : b).payload;
      books.add(RemoteBook(
        key: entry.key,
        title: newest['title'] as String? ?? '',
        author: newest['author'] as String? ?? '',
        origin: newest['origin'] as String? ?? 'local',
        archiveId: newest['archiveId'] as String?,
        chapterCount: newest['chapters'] as int? ?? 0,
        durationSeconds: newest['seconds'] as int? ?? 0,
        deviceIds: {for (final r in entry.value) r.deviceId},
      ));
    }
    books
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return books;
  }

  /// Every other device's current position in the book [key].
  List<DevicePosition> positions(String key) => [
        for (final r in _others(SyncKind.position, key))
          if (!r.deleted)
            DevicePosition(
              r.deviceId,
              r.payload['chapter'] as int? ?? 0,
              r.payload['seconds'] as int? ?? 0,
              r.payload['at'] as int? ?? r.hlc.wallMillis,
            ),
      ]..sort((a, b) => b.atMillis.compareTo(a.atMillis));

  /// The position to offer as "Continue from (device)": the most recently
  /// saved one elsewhere, if it is newer than [localAtMillis] and at a
  /// different place than [local]. Null when there is nothing to offer.
  DevicePosition? resumeOffer(String key,
      {DevicePosition? local, int? localAtMillis}) {
    final all = positions(key);
    if (all.isEmpty) return null;
    final newest = all.first;
    if (localAtMillis != null && newest.atMillis <= localAtMillis) return null;
    if (local != null &&
        newest.chapter == local.chapter &&
        (newest.seconds - local.seconds).abs() < 15) {
      return null;
    }
    return newest;
  }

  /// Furthest any other device has got in the book [key].
  DevicePosition? furthestElsewhere(String key) {
    DevicePosition? best;
    for (final r in _others(SyncKind.furthest, key)) {
      final pos = DevicePosition(
        r.deviceId,
        r.payload['chapter'] as int? ?? 0,
        r.payload['seconds'] as int? ?? 0,
        r.hlc.wallMillis,
      );
      if (best == null || pos.isAhead(best)) best = pos;
    }
    return best;
  }

  /// Devices that marked the book [key] finished (and haven't reset it).
  Set<String> finishedOn(String key) => {
        for (final r in _others(SyncKind.finished, key))
          if (r.payload['finished'] == true) r.deviceId,
      };

  /// Name a device gave itself, or a short fallback from its id.
  String deviceName(String id) {
    for (final r in _records) {
      if (r.kind == SyncKind.device && r.key == id) {
        final name = r.payload['name'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return 'Device ${id.length > 4 ? id.substring(0, 4) : id}';
  }
}

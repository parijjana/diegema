import 'dart:convert';

import 'hlc.dart';
import 'sync_record.dart';
import 'sync_store.dart';

/// What this device knows about one of its books, read from the app's own
/// tables. The publisher turns differences from what was last published
/// into new records, so nothing in the app has to call into sync when it
/// saves progress.
class LocalBook {
  /// Portable key (`lv:…` / `ck:…`).
  final String key;
  final String title;
  final String author;

  /// `'librivox'` or `'local'`.
  final String origin;

  /// archive.org identifier for a LibriVox book, so a device without it can
  /// open its Discover page.
  final String? archiveId;
  final int chapterCount;
  final int durationSeconds;

  /// Current position, null when never played.
  final int? chapter;
  final int? positionSeconds;

  /// Wall time the position was saved (ms since epoch).
  final int? positionAtMillis;
  final bool finished;

  const LocalBook({
    required this.key,
    required this.title,
    required this.author,
    required this.origin,
    this.archiveId,
    this.chapterCount = 0,
    this.durationSeconds = 0,
    this.chapter,
    this.positionSeconds,
    this.positionAtMillis,
    this.finished = false,
  });

  Map<String, Object?> get cataloguePayload => {
        'title': title,
        'author': author,
        'origin': origin,
        if (archiveId != null) 'archiveId': archiveId,
        'chapters': chapterCount,
        'seconds': durationSeconds,
      };
}

class PublishResult {
  final List<SyncRecord> records;
  final Hlc clock;
  const PublishResult(this.records, this.clock);
}

String _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canonical(value[k])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  return jsonEncode(value);
}

bool _samePayload(Map<String, Object?> a, Map<String, Object?> b) =>
    _canonical(a) == _canonical(b);

/// Compares [books] with this device's records in [store] and writes a new
/// record for every difference: a changed catalogue entry or position, a
/// position past the furthest so far, finished/reset, and a tombstone for
/// every book no longer here. Returns the records written and the clock
/// after stamping them.
Future<PublishResult> publishLocalState({
  required SyncStore store,
  required Hlc clock,
  required List<LocalBook> books,
  required int nowMillis,
}) async {
  final me = clock.deviceId;
  final out = <SyncRecord>[];
  var c = clock;

  Future<SyncRecord?> own(SyncKind kind, String key) =>
      store.get('${kind.name}|$key|$me');
  void emit(SyncKind kind, String key, Map<String, Object?> payload,
      {bool deleted = false}) {
    c = c.tick(nowMillis);
    out.add(SyncRecord(
        kind: kind, key: key, hlc: c, payload: payload, deleted: deleted));
  }

  final here = <String>{};
  for (final book in books) {
    here.add(book.key);

    final listed = await own(SyncKind.catalogue, book.key);
    if (listed == null ||
        listed.deleted ||
        !_samePayload(listed.payload, book.cataloguePayload)) {
      emit(SyncKind.catalogue, book.key, book.cataloguePayload);
    }

    final finished = await own(SyncKind.finished, book.key);
    final wasFinished = finished?.payload['finished'] == true;
    if (book.finished != wasFinished && (book.finished || finished != null)) {
      emit(SyncKind.finished, book.key, {'finished': book.finished});
    }

    final chapter = book.chapter, seconds = book.positionSeconds;
    if (book.finished || chapter == null || seconds == null) continue;
    final position = await own(SyncKind.position, book.key);
    if (position == null ||
        position.payload['chapter'] != chapter ||
        position.payload['seconds'] != seconds) {
      emit(SyncKind.position, book.key, {
        'chapter': chapter,
        'seconds': seconds,
        'at': book.positionAtMillis ?? nowMillis,
      });
    }
    final furthest = await own(SyncKind.furthest, book.key);
    final fc = furthest?.payload['chapter'] as int?;
    final fs = furthest?.payload['seconds'] as int?;
    if (fc == null ||
        fs == null ||
        chapter > fc ||
        (chapter == fc && seconds > fs)) {
      emit(SyncKind.furthest, book.key,
          {'chapter': chapter, 'seconds': seconds});
    }
  }

  for (final r in await store.all()) {
    if (r.deviceId == me &&
        r.kind == SyncKind.catalogue &&
        !r.deleted &&
        !here.contains(r.key)) {
      emit(SyncKind.catalogue, r.key, const {}, deleted: true);
    }
  }

  if (out.isNotEmpty) await store.putAll(out);
  return PublishResult(out, c);
}

/// The clock to start from on launch: past every stamp this device holds,
/// its own and everyone else's, so a new stamp always sorts last.
Future<Hlc> resumeClock(SyncStore store, String deviceId) async {
  var c = Hlc.zero(deviceId);
  for (final stamp in (await store.vector()).values) {
    if (stamp.wallMillis > c.wallMillis ||
        (stamp.wallMillis == c.wallMillis && stamp.counter > c.counter)) {
      c = Hlc(stamp.wallMillis, stamp.counter, deviceId);
    }
  }
  return c;
}

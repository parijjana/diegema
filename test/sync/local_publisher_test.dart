import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/local_publisher.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_store.dart';

LocalBook emma({int? chapter, int? seconds, bool finished = false}) =>
    LocalBook(
      key: 'lv:emma',
      title: 'Emma',
      author: 'Jane Austen',
      origin: 'librivox',
      archiveId: 'emma_librivox',
      chapterCount: 55,
      durationSeconds: 60000,
      chapter: chapter,
      positionSeconds: seconds,
      positionAtMillis: 1000,
      finished: finished,
    );

void main() {
  late InMemorySyncStore store;
  late Hlc clock;

  setUp(() {
    store = InMemorySyncStore();
    clock = const Hlc.zero('mac');
  });

  Future<List<SyncRecord>> publish(List<LocalBook> books, int now) async {
    final r = await publishLocalState(
        store: store, clock: clock, books: books, nowMillis: now);
    clock = r.clock;
    return r.records;
  }

  Map<SyncKind, int> kinds(List<SyncRecord> rs) {
    final m = <SyncKind, int>{};
    for (final r in rs) {
      m[r.kind] = (m[r.kind] ?? 0) + 1;
    }
    return m;
  }

  test('first publish lists the book, its position and furthest', () async {
    final rs = await publish([emma(chapter: 3, seconds: 100)], 10);
    expect(kinds(rs),
        {SyncKind.catalogue: 1, SyncKind.position: 1, SyncKind.furthest: 1});
    expect(rs.first.payload['archiveId'], 'emma_librivox');
  });

  test('publishing the same state again writes nothing', () async {
    await publish([emma(chapter: 3, seconds: 100)], 10);
    expect(await publish([emma(chapter: 3, seconds: 100)], 20), isEmpty);
  });

  test('going back moves the position but not the furthest', () async {
    await publish([emma(chapter: 3, seconds: 100)], 10);
    final rs = await publish([emma(chapter: 1, seconds: 5)], 20);
    expect(kinds(rs), {SyncKind.position: 1});
    expect((await store.get('furthest|lv:emma|mac'))!.payload,
        {'chapter': 3, 'seconds': 100});
  });

  test('finished, then reset', () async {
    await publish([emma(chapter: 3, seconds: 100)], 10);
    final done = await publish([emma(finished: true)], 20);
    expect(kinds(done), {SyncKind.finished: 1});
    final reset = await publish([emma()], 30);
    expect(reset.single.payload, {'finished': false});
  });

  test('a book that never finished publishes no finished record', () async {
    final rs = await publish([emma()], 10);
    expect(kinds(rs), {SyncKind.catalogue: 1});
  });

  test('a removed book leaves a tombstone, once; re-adding lists it again',
      () async {
    await publish([emma()], 10);
    final gone = await publish([], 20);
    expect(gone.single.deleted, isTrue);
    expect(await publish([], 30), isEmpty);
    final back = await publish([emma()], 40);
    expect(back.single.deleted, isFalse);
  });

  test('other devices\' records are never touched or tombstoned', () async {
    await mergeInto(store, [
      SyncRecord(
          kind: SyncKind.catalogue,
          key: 'ck:phone-only',
          hlc: const Hlc(5, 0, 'phone'))
    ]);
    expect(await publish([], 10), isEmpty);
  });

  test('stamps sort after everything held, even from a clock far ahead',
      () async {
    await mergeInto(store, [
      SyncRecord(
          kind: SyncKind.catalogue, key: 'x', hlc: const Hlc(9999, 7, 'phone'))
    ]);
    clock = await resumeClock(store, 'mac');
    final rs = await publish([emma()], 10);
    expect(rs.single.hlc > const Hlc(9999, 7, 'phone'), isTrue);
  });
}

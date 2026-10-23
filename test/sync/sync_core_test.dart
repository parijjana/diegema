import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/sync_exchange.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_store.dart';

/// A device: its store and its clock.
class Device {
  final String id;
  final store = InMemorySyncStore();
  late Hlc clock = Hlc.zero(id);
  late final peer = SyncPeer(store, onChanged: (changed) {
    for (final r in changed) {
      clock = clock.receive(r.hlc, clock.wallMillis);
    }
  });

  Device(this.id);

  Future<SyncRecord> write(SyncKind kind, String key, int now,
      {Map<String, Object?> payload = const {}, bool deleted = false}) async {
    clock = clock.tick(now);
    final r = SyncRecord(
        kind: kind, key: key, hlc: clock, payload: payload, deleted: deleted);
    await mergeInto(store, [r]);
    return r;
  }

  Future<SyncRecord?> slot(SyncKind kind, String key, String device) =>
      store.get('${kind.name}|$key|$device');
}

/// A full exchange, every message through JSON as it would be on the wire.
Future<void> sync(Device a, Device b) async {
  SyncMessage wire(SyncMessage m) => SyncMessage.fromJson(
      (jsonDecode(jsonEncode(m.toJson())) as Map).cast<String, Object?>());
  final m1 = wire(await a.peer.hello());
  final m2 = wire(await b.peer.answer(m1));
  final m3 = wire(await a.peer.complete(m2));
  await b.peer.finish(m3);
}

Future<Set<String>> state(Device d) async =>
    {for (final r in await d.store.all()) r.encode()};

void main() {
  group('Hlc', () {
    test('ticks forward even when the wall clock stalls or goes back', () {
      var c = const Hlc.zero('a');
      final stamps = <Hlc>[];
      for (final now in [100, 100, 90, 100, 200]) {
        c = c.tick(now);
        stamps.add(c);
      }
      for (var i = 1; i < stamps.length; i++) {
        expect(stamps[i] > stamps[i - 1], isTrue, reason: '$i');
      }
      expect(stamps.last, const Hlc(200, 0, 'a'));
    });

    test(
        'after receiving a stamp from a fast clock, local stamps sort after it',
        () {
      const local = Hlc(1000, 0, 'slow');
      const remote = Hlc(5000, 3, 'fast');
      final next = local.receive(remote, 1001).tick(1002);
      expect(next > remote, isTrue);
    });

    test('encodes sortably and round-trips', () {
      const a = Hlc(99, 2, 'dev-1');
      const b = Hlc(1000, 0, 'dev-1');
      expect(Hlc.decode(a.encode()), a);
      expect(a.encode().compareTo(b.encode()) < 0, isTrue);
    });
  });

  group('merge', () {
    test('newer stamp wins its slot; replaying a batch changes nothing',
        () async {
      final store = InMemorySyncStore();
      final old = SyncRecord(
          kind: SyncKind.position,
          key: 'lv:emma',
          hlc: const Hlc(1, 0, 'a'),
          payload: {'chapter': 1});
      final newer = SyncRecord(
          kind: SyncKind.position,
          key: 'lv:emma',
          hlc: const Hlc(2, 0, 'a'),
          payload: {'chapter': 2});
      expect(await mergeInto(store, [newer, old]), [newer]);
      expect(await mergeInto(store, [old, newer]), isEmpty);
      expect((await store.get(newer.slot))!.payload['chapter'], 2);
    });

    test('each device keeps its own slot: no winner between devices', () async {
      final store = InMemorySyncStore();
      await mergeInto(store, [
        SyncRecord(
            kind: SyncKind.position, key: 'k', hlc: const Hlc(5, 0, 'a')),
        SyncRecord(
            kind: SyncKind.position, key: 'k', hlc: const Hlc(9, 0, 'b')),
      ]);
      expect(await store.all(), hasLength(2));
    });
  });

  group('exchange', () {
    test('two devices end with the same records', () async {
      final mac = Device('mac'), phone = Device('phone');
      await mac
          .write(SyncKind.catalogue, 'lv:emma', 10, payload: {'title': 'Emma'});
      await mac.write(SyncKind.position, 'lv:emma', 11,
          payload: {'chapter': 3, 'ms': 1000});
      await phone.write(SyncKind.position, 'lv:emma', 12,
          payload: {'chapter': 1, 'ms': 5});

      await sync(mac, phone);

      expect(await state(mac), await state(phone));
      expect(
          (await phone.slot(SyncKind.position, 'lv:emma', 'mac'))!
              .payload['chapter'],
          3);
      expect(
          (await mac.slot(SyncKind.position, 'lv:emma', 'phone'))!
              .payload['chapter'],
          1,
          reason: 'incoming records never touch the local slot');
    });

    test('a second exchange with nothing new sends nothing', () async {
      final mac = Device('mac'), phone = Device('phone');
      await mac.write(SyncKind.catalogue, 'k', 1);
      await sync(mac, phone);
      final m2 = await phone.peer.answer(await mac.peer.hello());
      expect(m2.records, isEmpty);
      expect((await mac.peer.complete(m2)).records, isEmpty);
    });

    test('two Macs that never meet converge through a phone (relay)', () async {
      final mac1 = Device('mac1'), mac2 = Device('mac2'), phone = Device('p');
      await mac1.write(SyncKind.catalogue, 'lv:a', 1);
      await mac2.write(SyncKind.catalogue, 'ck:b', 2);
      await sync(phone, mac1);
      await sync(phone, mac2);
      await sync(phone, mac1);
      expect(await state(mac1), await state(mac2));
      expect(await mac1.store.all(), hasLength(2));
    });

    test('an exchange cut off after message 2 loses nothing', () async {
      final mac = Device('mac'), phone = Device('phone');
      await mac.write(SyncKind.position, 'k', 1);
      await phone.write(SyncKind.position, 'k', 2);
      // Message 3 never arrives.
      await mac.peer.complete(await phone.peer.answer(await mac.peer.hello()));
      expect(await phone.store.all(), hasLength(1));
      await sync(mac, phone);
      expect(await state(mac), await state(phone));
    });

    test('a removal (tombstone) replaces the catalogue record everywhere',
        () async {
      final mac = Device('mac'), phone = Device('phone');
      await mac
          .write(SyncKind.catalogue, 'lv:emma', 1, payload: {'title': 'Emma'});
      await sync(mac, phone);
      await mac.write(SyncKind.catalogue, 'lv:emma', 2, deleted: true);
      await sync(phone, mac);
      expect((await phone.slot(SyncKind.catalogue, 'lv:emma', 'mac'))!.deleted,
          isTrue);
    });

    test(
        'a device whose clock runs hours behind still overwrites its own '
        'older records after syncing', () async {
      final fast = Device('fast'), slow = Device('slow');
      await fast.write(SyncKind.catalogue, 'x', 10000000);
      await slow.write(SyncKind.position, 'k', 5);
      await sync(slow, fast);
      final later = await slow.write(SyncKind.position, 'k', 6);
      expect(later.hlc.wallMillis, 10000000,
          reason: 'clock moved past what it received');
      await sync(slow, fast);
      expect((await fast.slot(SyncKind.position, 'k', 'slow'))!.hlc, later.hlc);
    });
  });

  test('a record kind from a newer version is skipped, not fatal', () {
    final m = SyncMessage.fromJson({
      'records': [
        {
          'kind': 'position',
          'key': 'lv:emma',
          'hlc': const Hlc(1, 0, 'a').encode()
        },
        {
          'kind': 'somethingNew',
          'key': 'x',
          'hlc': const Hlc(2, 0, 'a').encode()
        },
      ],
    });
    expect(m.records.map((r) => r.kind), [SyncKind.position]);
  });
}

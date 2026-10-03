import 'dart:io';

import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/lan_sync.dart';
import 'package:diegema/sync/secure/auth_session.dart';
import 'package:diegema/sync/sync_exchange.dart';
import 'package:diegema/sync/sync_group.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_discovery.dart';

class Device {
  final String id;
  final store = InMemorySyncStore();
  final secrets = InMemorySecretStore();
  late SyncGroup group;
  late LanSync lan;
  final changed = <SyncRecord>[];

  Device(this.id);

  Future<Device> start(FakeNetwork net,
      {required bool listens,
      List<int>? groupKey,
      PeerDiscovery? discovery}) async {
    group = await SyncGroup.load(secrets);
    if (groupKey != null) await group.join(groupKey);
    lan = LanSync(
      group: group,
      discovery: discovery ?? FakeDiscovery(net),
      peer: () async => SyncPeer(store, onChanged: changed.addAll),
      listens: listens,
      bindAddress: InternetAddress.loopbackIPv4,
      browseWindow: Duration.zero,
      timeout: const Duration(seconds: 5),
      instance: 'dg-$id',
    );
    return this;
  }

  Future<void> position(String book, int wall, int seconds) => store.putAll([
        SyncRecord(
            kind: SyncKind.position,
            key: book,
            hlc: Hlc(wall, 0, id),
            payload: {'chapter': 1, 'seconds': seconds}),
      ]);

  Future<Set<String>> slots() async =>
      {for (final r in await store.all()) r.slot};
}

final groupKey = List<int>.generate(32, (i) => i * 3);

void main() {
  test('a Mac (connects only) syncs both ways with a listening phone',
      () async {
    final net = FakeNetwork();
    final phone =
        await Device('phone').start(net, listens: true, groupKey: groupKey);
    final mac =
        await Device('mac').start(net, listens: false, groupKey: groupKey);
    await phone.position('lv:emma', 10, 100);
    await mac.position('lv:odyssey', 11, 200);

    await phone.lan.startListening();
    await mac.lan.startListening(); // no-op: a Mac never listens
    expect(phone.lan.listening, isTrue);
    expect(mac.lan.listening, isFalse);
    expect(net.services.keys, ['dg-phone']);

    final run = await mac.lan.syncNow();
    expect(run.results, hasLength(1));
    expect(run.results.single.ok, isTrue, reason: '${run.results.single}');
    expect(run.results.single.counts.toString(), 'sent=1 received=1');

    final both = {'position|lv:emma|phone', 'position|lv:odyssey|mac'};
    expect(await mac.slots(), both);
    expect(await phone.slots(), both);
    expect(phone.changed.single.key, 'lv:odyssey');
    expect(mac.changed.single.key, 'lv:emma');

    // Nothing new: an exchange that moves nothing.
    final again = await mac.lan.syncNow();
    expect(again.results.single.counts.toString(), 'sent=0 received=0');
    await phone.lan.stopListening();
    expect(net.services, isEmpty);
  });

  test('relay: a device that never meets the other still converges', () async {
    final net = FakeNetwork();
    final phone =
        await Device('phone').start(net, listens: true, groupKey: groupKey);
    final mac1 =
        await Device('mac1').start(net, listens: false, groupKey: groupKey);
    final mac2 =
        await Device('mac2').start(net, listens: false, groupKey: groupKey);
    await mac1.position('lv:emma', 10, 100);
    await phone.lan.startListening();
    await mac1.lan.syncNow();
    await mac2.lan.syncNow();
    expect(await mac2.slots(), contains('position|lv:emma|mac1'));
    await phone.lan.stopListening();
  });

  test('another group on the same network is never contacted', () async {
    final net = FakeNetwork();
    final phone =
        await Device('phone').start(net, listens: true, groupKey: groupKey);
    final neighbour = await Device('neighbour')
        .start(net, listens: false, groupKey: List<int>.filled(32, 7));
    await phone.lan.startListening();
    final run = await neighbour.lan.syncNow();
    expect(run.results, isEmpty);
    await phone.lan.stopListening();
  });

  test('a device with the tag but not the key gets nothing', () async {
    // The tag is public on the network; replaying it doesn't open a session.
    final net = FakeNetwork();
    final phone =
        await Device('phone').start(net, listens: true, groupKey: groupKey);
    await phone.position('lv:emma', 10, 100);
    await phone.lan.startListening();
    final intruder = await Device('intruder').start(net,
        listens: false,
        groupKey: List<int>.filled(32, 7),
        discovery: _AnyTag(net));
    await intruder.position('lv:forged', 12, 1);
    final run = await intruder.lan.syncNow();
    expect(run.results.single.ok, isFalse);
    expect(await intruder.slots(), {'position|lv:forged|intruder'});
    expect(await phone.slots(), {'position|lv:emma|phone'});
    await phone.lan.stopListening();
  });

  test('unlinked devices neither listen nor browse', () async {
    final net = FakeNetwork();
    final phone = await Device('phone').start(net, listens: true);
    await phone.lan.startListening();
    expect(phone.lan.listening, isFalse);
    expect((await phone.lan.syncNow()).results, isEmpty);
  });

  test('an unreachable advertised peer is reported, not thrown', () async {
    final net = FakeNetwork();
    final mac =
        await Device('mac').start(net, listens: false, groupKey: groupKey);
    final tag = (await mac.group.tag())!;
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    net.services['dg-gone'] = (port, tag);
    final run = await mac.lan.syncNow();
    expect(run.results.single.ok, isFalse);
  });

  group('SyncGroup', () {
    test('keeps its group key across loads; fresh only the first time',
        () async {
      final secrets = InMemorySecretStore();
      final first = await SyncGroup.load(secrets);
      expect(first.fresh, isTrue);
      expect(first.linked, isFalse);
      expect(await first.tag(), isNull);
      expect(() => first.sessionConfig(), throwsStateError);
      await first.create();
      final again = await SyncGroup.load(secrets);
      expect(again.fresh, isFalse);
      expect(again.key, first.key);
      expect(await again.tag(), matches(RegExp(r'^[0-9a-f]{16}$')));
      await again.leave();
      expect((await SyncGroup.load(secrets)).linked, isFalse);
    });

    test('the tag depends only on the group key', () async {
      final a = await SyncGroup.load(InMemorySecretStore());
      final b = await SyncGroup.load(InMemorySecretStore());
      await a.join(groupKey);
      await b.join(groupKey);
      expect(await a.tag(), await b.tag());
      await b.join(List<int>.filled(32, 1));
      expect(await a.tag(), isNot(await b.tag()));
      expect(secureRandomBytes(4), hasLength(4));
    });
  });

  test('two listening devices dialling each other at once both finish',
      () async {
    // The old network-wide lock deadlocked here until the 20 s timeout.
    final net = FakeNetwork();
    final a = await Device('a').start(net, listens: true, groupKey: groupKey);
    final b = await Device('b').start(net, listens: true, groupKey: groupKey);
    await a.position('lv:emma', 10, 1);
    await b.position('lv:odyssey', 11, 2);
    await a.lan.startListening();
    await b.lan.startListening();
    final runs = await Future.wait([a.lan.syncNow(), b.lan.syncNow()])
        .timeout(const Duration(seconds: 3));
    expect(runs.every((r) => r.results.single.ok), isTrue,
        reason: '${runs.map((r) => r.results)}');
    expect(await a.slots(), await b.slots());
    await a.lan.stopListening();
    await b.lan.stopListening();
  });

  test('a stranger holding a connection open doesn\'t block a sync', () async {
    final net = FakeNetwork();
    final phone =
        await Device('phone').start(net, listens: true, groupKey: groupKey);
    final mac =
        await Device('mac').start(net, listens: false, groupKey: groupKey);
    await phone.lan.startListening();
    final port = net.services['dg-phone']!.$1;
    final idle = await Socket.connect('127.0.0.1', port);
    final run = await mac.lan.syncNow().timeout(const Duration(seconds: 3));
    expect(run.results.single.ok, isTrue);
    idle.destroy();
    await phone.lan.stopListening();
  });

  test('concurrent startListening binds once', () async {
    final net = FakeNetwork();
    final phone =
        await Device('phone').start(net, listens: true, groupKey: groupKey);
    await Future.wait([
      phone.lan.startListening(),
      phone.lan.startListening(),
      phone.lan.startListening(),
    ]);
    expect(net.services, hasLength(1));
    await phone.lan.stopListening();
    expect(net.services, isEmpty);
  });
}

/// Sees every advertised device whatever its tag.
class _AnyTag extends FakeDiscovery {
  _AnyTag(super.net);
  @override
  Future<List<PeerAddress>> browse(
          {required String tag, required Duration window}) async =>
      [
        for (final e in net.services.entries)
          PeerAddress(e.key, '127.0.0.1', e.value.$1),
      ];
}

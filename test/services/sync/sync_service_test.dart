import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database_io.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/services/sync/sync_service_io.dart';
import 'package:diegema/sync/link_code.dart';
import 'package:diegema/sync/sync_group.dart';

import '../../helpers/fake_discovery.dart';

UnifiedAudiobook emma() => UnifiedAudiobook(
      id: 'emma_librivox',
      title: 'Emma',
      author: 'Jane Austen',
      description: '',
      origin: 'librivox',
      chapters: [
        for (var i = 0; i < 3; i++)
          AudiobookChapter(
              id: 'emma_$i',
              title: 'Ch $i',
              audioPathOrUrl: '/books/emma/$i.mp3',
              durationSeconds: 600,
              isStream: false),
      ],
    );

class Device {
  final db = AppDatabase(NativeDatabase.memory());
  late final SyncService sync;
  int clock;
  Device(String id, String name, this.clock) {
    sync = SyncService(db,
        identity: DeviceIdentityStore(overrides: {
          'sync.device_id.v1': id,
          'sync.device_name.v1': name,
        }),
        now: () => clock);
  }
}

Future<void> exchange(Device a, Device b) async {
  final pa = await a.sync.peer(), pb = await b.sync.peer();
  final m2 = await pb.answer(await pa.hello());
  await pb.finish(await pa.complete(m2));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Device mac, phone;
  setUp(() {
    mac = Device('mac', 'MacBook', 1000);
    phone = Device('phone', 'Pixel', 500);
  });
  tearDown(() async {
    await mac.db.close();
    await phone.db.close();
  });

  test('a Mac book shows on the phone as not on this device, named', () async {
    await mac.db.saveAudiobook(emma());
    await mac.db.saveProgress(
        audiobookId: 'emma_librivox', chapterIndex: 2, positionSeconds: 120);
    await mac.sync.refresh();
    await phone.sync.refresh();

    await exchange(phone, mac);

    final view = phone.sync.view.value!;
    final remote = view.remoteOnly({});
    expect(remote.single.title, 'Emma');
    expect(remote.single.archiveId, 'emma_librivox');
    expect(remote.single.chapterCount, 3);
    expect(view.deviceName('mac'), 'MacBook');
    expect(view.positions('lv:emma_librivox').single.chapter, 2);
  });

  test(
      'once the phone has the book too, the Mac is offered the phone\'s '
      'newer position', () async {
    await mac.db.saveAudiobook(emma());
    await mac.db.saveProgress(
        audiobookId: 'emma_librivox', chapterIndex: 0, positionSeconds: 30);
    await phone.db.saveAudiobook(emma());
    await phone.db.saveProgress(
        audiobookId: 'emma_librivox', chapterIndex: 1, positionSeconds: 400);
    await mac.sync.refresh();
    await phone.sync.refresh();
    await exchange(mac, phone);

    final view = mac.sync.view.value!;
    expect(view.remoteOnly({'lv:emma_librivox'}), isEmpty);
    final macProgress = await mac.db.getProgress('emma_librivox');
    final offer = view.resumeOffer('lv:emma_librivox',
        localAtMillis: macProgress!.updatedAt.millisecondsSinceEpoch - 60000);
    expect(offer!.deviceId, 'phone');
    expect(offer.chapter, 1);
  });

  test('removing the book on the Mac withdraws it from the phone\'s list',
      () async {
    await mac.db.saveAudiobook(emma());
    await mac.sync.refresh();
    await exchange(phone, mac);
    expect(phone.sync.view.value!.remoteOnly({}), hasLength(1));

    await mac.db.deleteAudiobook('emma_librivox');
    mac.clock = 2000;
    await mac.sync.refresh();
    await exchange(phone, mac);
    expect(phone.sync.view.value!.remoteOnly({}), isEmpty);
  });

  test('renaming a device reaches the others', () async {
    await mac.sync.refresh();
    await mac.sync.setDeviceName('Study Mac');
    await exchange(phone, mac);
    expect(phone.sync.view.value!.deviceName('mac'), 'Study Mac');
  });

  test('refresh with nothing changed writes nothing', () async {
    await mac.db.saveAudiobook(emma());
    await mac.sync.refresh();
    final before = (await mac.sync.store.all()).length;
    final vector = await mac.sync.store.vector();
    await mac.sync.refresh();
    expect((await mac.sync.store.all()).length, before);
    expect(await mac.sync.store.vector(), vector);
  });

  group('over the network', () {
    test('a device whose sync keys are new gets a new id, once', () async {
      final prefs = {'sync.device_id.v1': 'restored-from-old-phone'};
      final secrets = InMemorySecretStore();
      final db = AppDatabase(NativeDatabase.memory());
      final first = SyncService(db,
          identity: DeviceIdentityStore(overrides: prefs), secrets: secrets);
      final id = await first.deviceId();
      expect(id, isNot('restored-from-old-phone'));
      final again = SyncService(db,
          identity: DeviceIdentityStore(overrides: prefs), secrets: secrets);
      expect(await again.deviceId(), id);
      await db.close();
    });

    test('foreground on a Mac pulls a listening phone\'s books', () async {
      final net = FakeNetwork();
      final groupKey = List<int>.generate(32, (i) => i);
      Future<SyncService> linked(Device d, {required bool listens}) async {
        final secrets = InMemorySecretStore();
        await (await SyncGroup.load(secrets)).join(groupKey);
        return SyncService(d.db,
            identity: DeviceIdentityStore(overrides: {
              'sync.device_id.v1': d == mac ? 'mac' : 'phone',
              'sync.device_name.v1': d == mac ? 'MacBook' : 'Pixel',
            }),
            now: () => d.clock,
            secrets: secrets,
            discovery: FakeDiscovery(net),
            listens: listens);
      }

      await phone.db.saveAudiobook(emma());
      final phoneSync = await linked(phone, listens: true);
      final macSync = await linked(mac, listens: false);
      await phoneSync.foreground();
      expect(net.services, hasLength(1), reason: 'only the phone advertises');
      await macSync.foreground();
      final remote = macSync.view.value!.remoteOnly({});
      expect(remote.map((b) => b.title), ['Emma']);
      expect(phoneSync.view.value!.otherDeviceIds(), hasLength(1));
      await phoneSync.background();
    });
  });

  group('linking with a code', () {
    late FakeNetwork net;
    setUp(() => net = FakeNetwork());

    SyncService unlinked(Device d, {required bool listens}) => SyncService(d.db,
        identity: DeviceIdentityStore(overrides: {
          'sync.device_id.v1': d == mac ? 'mac' : 'phone',
          'sync.device_name.v1': d == mac ? 'MacBook' : 'Pixel',
        }),
        now: () => d.clock,
        secrets: InMemorySecretStore(),
        discovery: FakeDiscovery(net),
        listens: listens,
        localAddresses: () async => ['127.0.0.1'],
        callerWindow: const Duration(milliseconds: 300));

    test('phone shows, Mac scans: linked and synced at once', () async {
      await phone.db.saveAudiobook(emma());
      final p = unlinked(phone, listens: true);
      final m = unlinked(mac, listens: false);
      expect(await p.isLinked(), isFalse);
      final offer = await p.createLinkOffer();
      expect(await p.isLinked(), isTrue);
      expect(await m.joinWithCode(offer.code), JoinOutcome.linked);
      expect(m.view.value!.remoteOnly({}).map((b) => b.title), ['Emma']);
      expect(p.view.value!.deviceName(p.view.value!.otherDeviceIds().single),
          'MacBook');
    });

    test('Mac shows, phone scans: the Mac dials the phone', () async {
      await mac.db.saveAudiobook(emma());
      final m = unlinked(mac, listens: false);
      final p = unlinked(phone, listens: true);
      final offer = await m.createLinkOffer();
      expect(net.services, isEmpty, reason: 'a Mac never listens');
      expect(await p.joinWithCode(offer.code), JoinOutcome.linkedNotSynced);
      expect(net.services, hasLength(1), reason: 'the phone listens now');
      // What the Mac's link dialog does while it waits.
      expect(await m.syncNow(), 1);
      expect(p.view.value!.remoteOnly({}).map((b) => b.title), ['Emma']);
    });

    test('expired, invalid, and another group', () async {
      final p = unlinked(phone, listens: true);
      final m = unlinked(mac, listens: false);
      final offer = await p.createLinkOffer();
      expect(await m.joinWithCode('hello'), JoinOutcome.invalid);
      mac.clock += LinkCode.lifetime.inMilliseconds + 1000 * 1000;
      expect(await m.joinWithCode(offer.code), JoinOutcome.expired);
      mac.clock = 1000;

      // The Mac starts its own group first, then scans the phone's code.
      await m.createLinkOffer();
      expect(await m.joinWithCode(offer.code), JoinOutcome.otherGroup);
      expect(await m.joinWithCode(offer.code, replaceGroup: true),
          JoinOutcome.linked);
      // Scanning a code of the group it's already in is fine.
      expect(await m.joinWithCode(offer.code), JoinOutcome.linked);
    });
  });

  group('Linked devices actions', () {
    late FakeNetwork net;
    setUp(() => net = FakeNetwork());

    SyncService linked(Device d, SecretStore secrets,
            {required bool listens}) =>
        SyncService(d.db,
            identity: DeviceIdentityStore(overrides: {
              'sync.device_id.v1': d == mac ? 'mac' : 'phone',
              'sync.device_name.v1': d == mac ? 'MacBook' : 'Pixel',
            }),
            now: () => d.clock,
            secrets: secrets,
            discovery: FakeDiscovery(net),
            listens: listens,
            localAddresses: () async => ['127.0.0.1'],
            callerWindow: const Duration(milliseconds: 300));

    Future<(SyncService, SyncService)> pair() async {
      await phone.db.saveAudiobook(emma());
      final p = linked(phone, InMemorySecretStore(), listens: true);
      final m = linked(mac, InMemorySecretStore(), listens: false);
      final offer = await p.createLinkOffer();
      expect(await m.joinWithCode(offer.code), JoinOutcome.linked);
      return (p, m);
    }

    test('status and last sync', () async {
      final p = linked(phone, InMemorySecretStore(), listens: true);
      expect(await p.status(), SyncStatus.unlinked);
      expect(p.lastSync.value, isNull);
      final (p2, m) = await pair();
      expect(await p2.status(), SyncStatus.linked);
      expect(await m.syncNow(), 1);
      expect(m.lastSync.value!.reached, 1);
    });

    test('forgetting a device hides it on every linked device', () async {
      final (p, m) = await pair();
      final macId = m.view.value!.deviceId;
      final phoneId = p.view.value!.deviceId;
      expect(p.view.value!.otherDeviceIds(), [macId]);
      // The Mac removes the phone (as it would a retired phone or a ghost).
      await m.forgetDevice(phoneId);
      expect(m.view.value!.otherDeviceIds(), isEmpty);
      expect(m.view.value!.remoteOnly({}), isEmpty);
      // Forgetting yourself does nothing.
      await m.forgetDevice(macId);
      expect(m.view.value!.otherDeviceIds(), isEmpty);
      // The phone is still linked: its next change brings it back.
      phone.clock += 100000;
      await phone.db.saveProgress(
          audiobookId: 'emma_librivox', chapterIndex: 4, positionSeconds: 9);
      await p.syncNow();
      await m.syncNow();
      expect(m.view.value!.otherDeviceIds(), [phoneId]);
    });

    test('unlink stops syncing and drops other devices\' records', () async {
      final (p, m) = await pair();
      expect(m.view.value!.remoteOnly({}), isNotEmpty);
      await m.unlink();
      expect(await m.status(), SyncStatus.unlinked);
      expect(m.view.value!.otherDeviceIds(), isEmpty);
      expect(m.view.value!.remoteOnly({}), isEmpty);
      expect(await m.syncNow(), 0);
      expect(await p.syncNow(), 0, reason: 'the Mac stopped watching');
    });

    test('unreadable keys: status says so, reset gives a new unlinked device',
        () async {
      final broken = _Broken();
      final s = linked(phone, broken, listens: true);
      expect(await s.status(), SyncStatus.keysUnreadable);
      final oldId = await s.deviceId();
      broken.broken = false;
      await s.resetKeys();
      expect(await s.status(), SyncStatus.unlinked);
      expect(await s.deviceId(), isNot(oldId));
    });
  });

  test('Sync now on the phone reaches a Mac that only watches', () async {
    final net = FakeNetwork();
    final groupKey = List<int>.generate(32, (i) => i + 1);
    Future<SyncService> make(Device d, {required bool listens}) async {
      final secrets = InMemorySecretStore();
      await (await SyncGroup.load(secrets)).join(groupKey);
      return SyncService(d.db,
          identity: DeviceIdentityStore(overrides: {
            'sync.device_id.v1': d == mac ? 'mac' : 'phone',
            'sync.device_name.v1': d == mac ? 'MacBook' : 'Pixel',
          }),
          now: () => d.clock,
          secrets: secrets,
          discovery: FakeDiscovery(net),
          listens: listens,
          callerWindow: const Duration(milliseconds: 300));
    }

    final m = await make(mac, listens: false);
    await m.foreground(); // watching from now on
    final p = await make(phone, listens: true);
    await phone.db.saveAudiobook(emma());
    // Opening the phone app: the Mac sees it appear and dials it.
    await p.foreground();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(m.view.value!.remoteOnly({}).map((b) => b.title), ['Emma']);
    expect(m.lastSync.value?.reached, 1);
    expect(p.lastSync.value?.reached, 1, reason: 'an inbound sync counts');

    // The phone's own Sync now: it announces itself again and the Mac,
    // which can't be dialled, dials in.
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(await p.syncNow(), 1);
  });
}

/// A keystore whose reads throw until [broken] is cleared.
class _Broken extends InMemorySecretStore {
  bool broken = true;
  @override
  Future<String?> read(String key) async {
    if (broken) throw StateError('keystore unreadable');
    return super.read(key);
  }
}

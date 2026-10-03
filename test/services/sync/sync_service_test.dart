import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database_io.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/sync/sync_service_io.dart';
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
}

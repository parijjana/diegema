import 'dart:convert';
import 'dart:io';

import 'package:diegema/database/app_database_io.dart';
import 'package:diegema/database/drift_sync_store.dart';
import 'package:diegema/sync/file_secret_store.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/lan_sync.dart';
import 'package:diegema/sync/sync_exchange.dart';
import 'package:diegema/sync/sync_group.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_store.dart';
import 'package:diegema/sync_cli/sync_tool.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/fake_discovery.dart';

final groupKey = List<int>.generate(32, (i) => i * 5);
const mac = 'aaaa1111';
const phone = 'bbbb2222';

SyncRecord rec(SyncKind kind, String key, String device, int wall,
        [Map<String, Object?> payload = const {}]) =>
    SyncRecord(kind: kind, key: key, hlc: Hlc(wall, 0, device), payload: payload);

void main() {
  late Directory dir;
  late File dbFile;
  late File secretsFile;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diegema_cli');
    dbFile = File('${dir.path}/diegema.sqlite');
    secretsFile = File('${dir.path}/$syncSecretsFileName');
    final db = AppDatabase(NativeDatabase(dbFile));
    await DriftSyncStore(db).putAll([
      rec(SyncKind.device, mac, mac, 100,
          {'name': 'MacBook', 'platform': 'macos'}),
      rec(SyncKind.position, 'lv:emma', mac, 200, {'seconds': 5}),
      rec(SyncKind.device, phone, phone, 150,
          {'name': 'Pixel', 'platform': 'android'}),
      rec(SyncKind.position, 'lv:emma', phone, 300, {'seconds': 9}),
    ]);
    await db.close();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> link() async =>
      (await SyncGroup.load(FileSecretStore(() async => secretsFile)))
          .join(groupKey);

  SyncTool tool(
          {String? deviceId = mac,
          bool appRunning = false,
          FakeNetwork? net}) =>
      SyncTool(
        AppData(database: dbFile, secrets: secretsFile, deviceId: deviceId),
        discovery: () => FakeDiscovery(net ?? FakeNetwork()),
        appRunning: () async => appRunning,
      );

  group('reads', () {
    test('status, devices and log leave the database untouched', () async {
      await link();
      final before = await dbFile.readAsBytes();
      final status = await tool().status();
      expect(status.linked, isTrue);
      expect(status.tag, isNotNull);
      expect(status.records, 4);
      expect(status.devices, 2);
      final devices = await tool().devices();
      expect(devices.map((d) => (d.name, d.self)),
          [('MacBook', true), ('Pixel', false)]);
      expect(devices.last.records, 2);
      final log = await tool().log();
      expect(log.map((r) => r.hlc.wallMillis), [300, 200, 150, 100]);
      expect(await dbFile.readAsBytes(), before);
      expect(File('${dbFile.path}-wal').existsSync(), isFalse);
    });

    test('log filters by device prefix and kind, and limits', () async {
      final t = tool();
      expect((await t.log(device: 'bbbb')).every((r) => r.deviceId == phone),
          isTrue);
      expect((await t.log(kind: SyncKind.position)).map((r) => r.deviceId),
          [phone, mac]);
      expect(await t.log(limit: 1), hasLength(1));
    });

    test('unlinked: status says so; group peers refuse', () async {
      expect((await tool().status()).linked, isFalse);
      await expectLater(tool().peers(), throwsA(isA<ToolError>()));
    });

    test('a missing database is a plain error', () async {
      await dbFile.delete();
      await expectLater(
          tool().status(),
          throwsA(isA<ToolError>().having(
              (e) => e.message, 'message', contains('no Diegema database'))));
    });

    test('another schema version is refused and left alone', () async {
      final raw = sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 3');
      raw.close();
      final before = await dbFile.readAsBytes();
      await expectLater(tool().devices(), throwsA(isA<ToolError>()));
      await link();
      await expectLater(tool().sync(), throwsA(isA<ToolError>()));
      expect(await dbFile.readAsBytes(), before);
    });

    test('secrets are never written, even by an unmarked install', () async {
      // A key but no install marker: loading would normally mark it.
      await secretsFile.writeAsString(
          jsonEncode({'sync.group_key.v1': base64.encode(groupKey)}));
      final before = await secretsFile.readAsString();
      await expectLater(tool().status(), throwsA(isA<ToolError>()));
      expect(await secretsFile.readAsString(), before);
    });
  });

  group('peers', () {
    test('lists the group\'s devices only', () async {
      await link();
      final net = FakeNetwork();
      final tag = (await tool().status()).tag!;
      net.services['dg-phone'] = (4000, tag);
      net.services['dg-stranger'] = (4001, 'someoneelse');
      final rows = await tool(net: net).peers(window: Duration.zero);
      expect(rows.map((r) => r.address.instance), ['dg-phone']);
    });
  });

  group('sync', () {
    test('refuses while the app runs, unless forced', () async {
      await link();
      await expectLater(tool(appRunning: true).sync(),
          throwsA(isA<ToolError>().having((e) => e.message, 'message',
              contains('running'))));
      expect(await tool(appRunning: true).sync(force: true), isEmpty);
    });

    test('refuses when unlinked or without a device id', () async {
      await expectLater(tool().sync(), throwsA(isA<ToolError>()));
      await link();
      await expectLater(
          tool(deviceId: null).sync(), throwsA(isA<ToolError>()));
    });

    test('refuses when the key lives in a keystore it can\'t read', () async {
      final t = SyncTool(AppData(database: dbFile, deviceId: mac),
          appRunning: () async => false);
      await expectLater(t.sync(), throwsA(isA<ToolError>()));
    });

    Future<(LanSync, InMemorySyncStore)> listeningPhone(FakeNetwork net) async {
      final secrets = InMemorySecretStore();
      final group = await SyncGroup.load(secrets);
      await group.join(groupKey);
      final store = InMemorySyncStore();
      await store.putAll([
        rec(SyncKind.position, 'lv:odyssey', 'cccc3333', 500, {'seconds': 1}),
      ]);
      final lan = LanSync(
        group: group,
        discovery: FakeDiscovery(net),
        peer: () async => SyncPeer(store),
        listens: true,
        bindAddress: InternetAddress.loopbackIPv4,
        instance: 'dg-phone',
      );
      await lan.startListening();
      return (lan, store);
    }

    test('exchanges records with a listening device, both ways', () async {
      await link();
      final net = FakeNetwork();
      final (phoneLan, phoneStore) = await listeningPhone(net);
      final results = await tool(net: net).sync();
      expect(results.single.ok, isTrue);
      expect(results.single.counts!.received, 1);
      expect(results.single.counts!.sent, 4);
      expect(await phoneStore.all(), hasLength(5));
      final log = await tool().log(device: 'cccc');
      expect(log.single.key, 'lv:odyssey');
      await phoneLan.dispose();
    });

    test('--watch syncs with a device that appears later', () async {
      await link();
      final net = FakeNetwork();
      final running = tool(net: net)
          .sync(watch: const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final (phoneLan, _) = await listeningPhone(net);
      final results = await running;
      expect(results.single.ok, isTrue);
      expect(await tool().log(device: 'cccc'), hasLength(1));
      await phoneLan.dispose();
    });
  });
}

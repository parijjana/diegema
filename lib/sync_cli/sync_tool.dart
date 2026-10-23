import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database_io.dart';
import '../database/drift_sync_store.dart';
import '../sync/file_secret_store.dart';
import '../sync/lan_sync.dart';
import '../sync/sync_exchange.dart';
import '../sync/sync_file.dart';
import '../sync/sync_group.dart';
import '../sync/sync_record.dart';
import '../sync/sync_store.dart';
import '../sync/sync_view.dart';
import 'mdns_discovery.dart';

/// What the `diegema-sync` CLI does, as one module (SYNC_DESIGN S10).
/// It acts as this computer's Diegema app: the app's database, sync key
/// and device id. Owner decision 2026-10-03. Reads never write anything;
/// [sync] writes only what the exchange brings in, and only while the app
/// is closed.
class ToolError implements Exception {
  final String message;
  const ToolError(this.message);
  @override
  String toString() => message;
}

const _bundle = 'com.overengineeredhobbies.diegema';
const _deviceIdKey = 'sync.device_id.v1';

/// Where this computer's app keeps its data. Each part can be overridden
/// (flags, or `DIEGEMA_DB`, `DIEGEMA_SECRETS`, `DIEGEMA_DEVICE_ID`).
class AppData {
  final File database;

  /// Null where the app keeps its secrets in the OS keystore (Windows),
  /// which the CLI doesn't read yet.
  final File? secrets;
  final String? deviceId;

  const AppData({required this.database, this.secrets, this.deviceId});

  static Future<AppData> resolve({
    String? database,
    String? secrets,
    String? deviceId,
    Map<String, String>? environment,
  }) async {
    final env = environment ?? Platform.environment;
    database ??= env['DIEGEMA_DB'];
    secrets ??= env['DIEGEMA_SECRETS'];
    deviceId ??= env['DIEGEMA_DEVICE_ID'];
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    if (Platform.isMacOS) {
      final data = p.join(home, 'Library', 'Containers', _bundle, 'Data');
      return AppData(
        database: File(database ?? p.join(data, 'Documents', 'diegema.sqlite')),
        secrets: File(secrets ??
            p.join(data, 'Library', 'Application Support', _bundle,
                syncSecretsFileName)),
        deviceId: deviceId ??
            await _macPreference(
                p.join(data, 'Library', 'Preferences', '$_bundle.plist'),
                'flutter.$_deviceIdKey'),
      );
    }
    if (Platform.isWindows) {
      // Unverified until the Windows build exists (SYNC_DESIGN S10).
      final appData = env['APPDATA'] ?? '';
      return AppData(
        database: File(database ?? p.join(home, 'Documents', 'diegema.sqlite')),
        secrets: secrets == null ? null : File(secrets),
        deviceId: deviceId ??
            await _jsonPreference(
                p.join(appData, 'com.overengineeredhobbies', 'diegema',
                    'shared_preferences.json'),
                'flutter.$_deviceIdKey'),
      );
    }
    if (database == null) {
      throw const ToolError(
          'no default app data on this platform: pass --db (and --secrets, --device-id)');
    }
    return AppData(
        database: File(database),
        secrets: secrets == null ? null : File(secrets),
        deviceId: deviceId);
  }

  static Future<String?> _macPreference(String plist, String key) async {
    if (!File(plist).existsSync()) return null;
    try {
      // Not plutil -extract: it reads the dots in the key as a path.
      final r = await Process.run('/usr/bin/defaults', ['read', plist, key]);
      final v = (r.stdout as String).trim();
      return r.exitCode == 0 && v.isNotEmpty ? v : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _jsonPreference(String path, String key) async {
    try {
      final json = jsonDecode(await File(path).readAsString());
      return (json as Map)[key] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Whether the Diegema app is running on this computer.
Future<bool> diegemaAppRunning() async {
  try {
    if (Platform.isMacOS) {
      final r = await Process.run(
          '/usr/bin/pgrep', ['-f', '/Diegema.app/Contents/MacOS/Diegema']);
      return r.exitCode == 0;
    }
    if (Platform.isWindows) {
      final r = await Process.run(
          'tasklist', ['/FI', 'IMAGENAME eq diegema.exe', '/NH']);
      return (r.stdout as String).toLowerCase().contains('diegema.exe');
    }
  } catch (_) {}
  return false;
}

class DeviceRow {
  final String id;
  final String name;
  final String? platform;
  final bool self;
  final int records;

  /// Wall time of the device's newest record.
  final DateTime? latest;
  const DeviceRow(this.id, this.name, this.platform, this.self, this.records,
      this.latest);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'self': self,
        'records': records,
        'latest': latest?.toIso8601String(),
      };
}

class StatusReport {
  final AppData data;
  final bool linked;
  final String? tag;
  final int records;
  final int devices;
  final bool appRunning;
  const StatusReport(this.data, this.linked, this.tag,
      this.records, this.devices, this.appRunning);

  Map<String, Object?> toJson() => {
        'database': data.database.path,
        'secrets': data.secrets?.path,
        'deviceId': data.deviceId,
        'linked': linked,
        'tag': tag,
        'records': records,
        'devices': devices,
        'appRunning': appRunning,
      };
}

class PeerRow {
  final PeerAddress address;

  /// Whether it advertises this computer's group. Null when this computer
  /// isn't linked, so there's nothing to compare with.
  final bool? inGroup;
  const PeerRow(this.address, this.inGroup);

  Map<String, Object?> toJson() => {
        'instance': address.instance,
        'host': address.host,
        'port': address.port,
        'inGroup': inGroup,
      };
}

Map<String, Object?> recordJson(SyncRecord r) => {
      'kind': r.kind.name,
      'key': r.key,
      'device': r.deviceId,
      'hlc': r.hlc.encode(),
      'at': DateTime.fromMillisecondsSinceEpoch(r.hlc.wallMillis)
          .toIso8601String(),
      'deleted': r.deleted,
      'payload': r.payload,
    };

Map<String, Object?> resultJson(PeerResult r) => {
      'instance': r.peer.instance,
      'host': r.peer.host,
      'port': r.peer.port,
      'ok': r.ok,
      if (r.counts != null) 'sent': r.counts!.sent,
      if (r.counts != null) 'received': r.counts!.received,
      if (r.error != null) 'error': '${r.error}',
    };

/// The secrets, never written: the CLI must not mark an install or change
/// a key behind the app's back.
class _ReadOnlySecrets implements SecretStore {
  final SecretStore _inner;
  _ReadOnlySecrets(this._inner);
  @override
  Future<String?> read(String key) => _inner.read(key);
  @override
  Future<void> write(String key, String value) =>
      throw const ToolError('the CLI never writes sync secrets');
  @override
  Future<void> delete(String key) =>
      throw const ToolError('the CLI never writes sync secrets');
}

class SyncTool {
  final AppData data;
  final PeerDiscovery Function() _discovery;
  final Future<bool> Function() _appRunning;
  final void Function(String)? trace;

  SyncTool(this.data,
      {PeerDiscovery Function()? discovery,
      Future<bool> Function()? appRunning,
      this.trace})
      : _discovery = discovery ?? MdnsPeerDiscovery.new,
        _appRunning = appRunning ?? diegemaAppRunning;

  Future<AppDatabase> _open({required bool write}) async {
    final file = data.database;
    if (!await file.exists()) {
      throw ToolError('no Diegema database at ${file.path}');
    }
    final version = await AppDatabase.storedSchemaVersion(file);
    if (version != AppDatabase.currentSchemaVersion) {
      // Opening it would migrate the app's library: leave that to the app.
      throw ToolError('database schema is $version, this CLI reads '
          '${AppDatabase.currentSchemaVersion}: update the CLI or open the app first');
    }
    return AppDatabase(write
        ? NativeDatabase(file)
        : NativeDatabase.opened(
            sqlite3.open(file.path, mode: OpenMode.readOnly)));
  }

  Future<T> _reading<T>(Future<T> Function(DriftSyncStore store) f) async {
    final db = await _open(write: false);
    try {
      return await f(DriftSyncStore(db));
    } finally {
      await db.close();
    }
  }

  /// Null when this computer has no secrets file (the app never set sync
  /// up here) or keeps them in a keystore the CLI can't read.
  Future<SyncGroup?> _group() async {
    final f = data.secrets;
    if (f == null || !await f.exists()) return null;
    return SyncGroup.load(_ReadOnlySecrets(FileSecretStore(() async => f)));
  }

  Future<StatusReport> status() async {
    final group = await _group();
    final (records, devices) = await _reading((store) async {
      final all = await store.all();
      return (all.length, {for (final r in all) r.deviceId}.length);
    });
    return StatusReport(data, group?.linked ?? false, await group?.tag(), records, devices, await _appRunning());
  }

  Future<List<DeviceRow>> devices() => _reading((store) async {
        final all = await store.all();
        final self = data.deviceId ?? '';
        final view = SyncView(self, all);
        final ids = [
          if (all.any((r) => r.deviceId == self) || self.isNotEmpty) self,
          ...view.otherDeviceIds(),
        ].where((id) => id.isNotEmpty);
        return [
          for (final id in ids)
            () {
              final mine = all.where((r) => r.deviceId == id).toList();
              final latest = mine.isEmpty
                  ? null
                  : mine
                      .map((r) => r.hlc.wallMillis)
                      .reduce((a, b) => a > b ? a : b);
              return DeviceRow(
                id,
                view.deviceName(id),
                view.devicePlatform(id),
                id == self,
                mine.length,
                latest == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(latest),
              );
            }(),
        ];
      });

  /// Newest first. [device] matches an id prefix.
  Future<List<SyncRecord>> log(
          {String? device, SyncKind? kind, int limit = 50}) =>
      _reading((store) async {
        final all = (await store.all())
            .where((r) =>
                (device == null || r.deviceId.startsWith(device)) &&
                (kind == null || r.kind == kind))
            .toList()
          ..sort((a, b) => b.hlc.compareTo(a.hlc));
        return all.take(limit).toList();
      });

  /// Devices advertising Diegema on this network. Without [all], only this
  /// computer's group (which needs it linked).
  Future<List<PeerRow>> peers(
      {Duration window = const Duration(seconds: 4), bool all = false}) async {
    final tag = await (await _group())?.tag();
    if (!all && tag == null) {
      throw const ToolError(
          'this computer isn\'t linked: use --all to list every Diegema device');
    }
    final d = _discovery();
    if (d is MdnsPeerDiscovery) {
      return [
        for (final s in await d.browseAll(window))
          if (all || s.tag == tag)
            PeerRow(s.address, tag == null ? null : s.tag == tag),
      ];
    }
    return [
      for (final a in await d.browse(tag: tag ?? '', window: window))
        PeerRow(a, true),
    ];
  }

  /// Syncs this computer's app data with the linked devices on the network,
  /// as the app would. With [watch], keeps looking that long and syncs with
  /// each device as it appears (a phone listens only while its app is
  /// open). Refuses while the app runs: two writers to one database.
  Future<List<PeerResult>> sync(
      {Duration watch = Duration.zero, bool force = false}) async {
    if (data.secrets == null) {
      throw const ToolError(
          'this computer keeps its sync key in the OS keystore, which the CLI can\'t read yet: pass --secrets');
    }
    final group = await _group();
    if (group == null || !group.linked) {
      throw const ToolError(
          'this computer isn\'t linked: link it in the app first');
    }
    if (data.deviceId == null) {
      throw const ToolError(
          'can\'t find this computer\'s device id: pass --device-id');
    }
    if (!force && await _appRunning()) {
      throw const ToolError(
          'Diegema is running: use Sync now in the app, or quit it first');
    }
    final db = await _open(write: true);
    final lan = LanSync(
      group: group,
      discovery: _discovery(),
      peer: () async => SyncPeer(DriftSyncStore(db)),
      listens: false,
      log: trace,
    );
    final results = <PeerResult>[];
    final sub = lan.exchanges.listen(results.add);
    try {
      if (watch > Duration.zero) {
        // The first look finds the devices already there, too.
        await lan.startWatching();
        await Future<void>.delayed(watch);
      } else {
        results.addAll((await lan.syncNow()).results);
      }
    } finally {
      await lan.dispose();
      await sub.cancel();
      await db.close();
    }
    return results;
  }

  /// The group key, or a [ToolError] saying why there isn't one.
  Future<List<int>> _linkedKey() async {
    if (data.secrets == null) {
      throw const ToolError(
          'this computer keeps its sync key in the OS keystore, which the CLI can\'t read yet: pass --secrets');
    }
    final key = (await _group())?.key;
    if (key == null) {
      throw const ToolError(
          'this computer isn\'t linked: link it in the app first');
    }
    return key;
  }

  /// Writes a sync file of every record this computer's app holds (S12), to
  /// [out], or into it under the app's file name when it is a directory.
  /// Reads the database only. Refuses to overwrite a file.
  Future<File> exportFile(String out) async {
    final key = await _linkedKey();
    final self = data.deviceId;
    if (self == null) {
      throw const ToolError(
          'can\'t find this computer\'s device id: pass --device-id');
    }
    final records = await _reading((store) => store.all());
    final now = DateTime.now();
    var file = File(out);
    if (await FileSystemEntity.isDirectory(out)) {
      file = File(p.join(out,
          SyncFile.fileName(SyncView(self, records).deviceName(self), now)));
    }
    if (await file.exists()) throw ToolError('${file.path} already exists');
    await file.writeAsBytes(await SyncFile.encode(
        groupKey: key,
        deviceId: self,
        createdAtMillis: now.millisecondsSinceEpoch,
        records: records));
    return file;
  }

  /// Merges the sync file at [path] into this computer's app, as an import
  /// in the app would. Refuses while the app runs: two writers to one
  /// database.
  Future<ImportReport> importFile(String path, {bool force = false}) async {
    final key = await _linkedKey();
    final file = File(path);
    if (!await file.exists()) throw ToolError('no file at $path');
    if (await file.length() > SyncFile.maxBytes) {
      throw const ToolError('not a Diegema sync file');
    }
    final SyncFileContents contents;
    try {
      contents =
          await SyncFile.decode(await file.readAsBytes(), groupKey: key);
    } on SyncFileError catch (e) {
      throw ToolError(switch (e.problem) {
        SyncFileProblem.notSyncFile => 'not a Diegema sync file',
        SyncFileProblem.otherGroup =>
          'this file is from a device of another sync group',
        SyncFileProblem.damaged =>
          'this file was changed or damaged after it was written',
      });
    }
    if (!force && await _appRunning()) {
      throw const ToolError(
          'Diegema is running: import the file in the app, or quit it first');
    }
    final db = await _open(write: true);
    try {
      final changed = await mergeInto(DriftSyncStore(db), contents.records);
      return ImportReport(contents.deviceId, contents.createdAtMillis,
          contents.records.length, changed.length);
    } finally {
      await db.close();
    }
  }
}

class ImportReport {
  final String from;
  final int createdAtMillis;
  final int records;
  final int changed;
  const ImportReport(
      this.from, this.createdAtMillis, this.records, this.changed);

  Map<String, Object?> toJson() => {
        'from': from,
        'created': DateTime.fromMillisecondsSinceEpoch(createdAtMillis)
            .toUtc()
            .toIso8601String(),
        'records': records,
        'changed': changed,
      };
}

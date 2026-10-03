import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database_io.dart';
import '../../database/drift_sync_store.dart';
import '../../sync/hlc.dart';
import '../../sync/lan_sync.dart';
import '../../sync/local_publisher.dart';
import '../../sync/sync_exchange.dart';
import '../../sync/sync_group.dart';
import '../../sync/sync_record.dart';
import '../../sync/sync_store.dart';
import '../../sync/sync_view.dart';
import 'portable_keys_io.dart';
import 'sync_controller.dart';

/// This device's sync id and name, kept in shared_preferences. The id is
/// random, made once, and never shown.
class DeviceIdentityStore {
  static const String _idKey = 'sync.device_id.v1';
  static const String _nameKey = 'sync.device_name.v1';

  final Map<String, String>? _overrides;
  const DeviceIdentityStore({Map<String, String>? overrides})
      : _overrides = overrides;

  Future<String?> _get(String key) async {
    final o = _overrides;
    if (o != null) return o[key];
    return (await SharedPreferences.getInstance()).getString(key);
  }

  Future<void> _set(String key, String value) async {
    final o = _overrides;
    if (o != null) {
      o[key] = value;
      return;
    }
    await (await SharedPreferences.getInstance()).setString(key, value);
  }

  Future<String> deviceId() async =>
      await _get(_idKey) ?? await resetDeviceId();

  /// A new random id, for a device whose sync keys are new (see
  /// [SyncGroup.fresh]).
  Future<String> resetDeviceId() async {
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _set(_idKey, id);
    return id;
  }

  Future<String> deviceName() async =>
      await _get(_nameKey) ?? defaultDeviceName();

  Future<void> setDeviceName(String name) => _set(_nameKey, name.trim());
}

/// "Animesh's MacBook Pro" from the host name on desktops; the platform
/// on phones, whose host names are meaningless.
String defaultDeviceName() {
  if (Platform.isAndroid) return 'Android phone';
  if (Platform.isIOS) return 'iPhone';
  var host = Platform.localHostname;
  if (host.endsWith('.local')) host = host.substring(0, host.length - 6);
  host = host.replaceAll('-', ' ').trim();
  if (host.isNotEmpty) return host;
  return Platform.isMacOS
      ? 'Mac'
      : (Platform.isWindows ? 'Windows PC' : 'Computer');
}

/// The app's side of linked-device sync: keeps this device's records in
/// step with its library, and holds the [view] the UI reads. The network
/// transport drives [peer].
class SyncService implements SyncController {
  final AppDatabase db;
  final SyncStore store;
  final DeviceIdentityStore identity;
  final int Function() _now;

  final ValueNotifier<SyncView?> _view = ValueNotifier(null);

  @override
  ValueListenable<SyncView?> get view => _view;

  /// Sync keys and the network; without them (tests, the CLI) the service
  /// keeps its records but never talks to another device.
  final SecretStore? secrets;
  final PeerDiscovery? discovery;
  final bool listens;

  Hlc? _clock;
  String? _deviceId;
  SyncGroup? _group;
  LanSync? _lan;

  SyncService(
    this.db, {
    SyncStore? store,
    this.identity = const DeviceIdentityStore(),
    int Function()? now,
    this.secrets,
    this.discovery,
    this.listens = false,
  })  : store = store ?? DriftSyncStore(db),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// This device's sync keys. Loaded before the device id is first used: a
  /// device whose keys are new gets a new id too.
  Future<SyncGroup?> group() async {
    final s = secrets;
    if (s == null) return null;
    if (_group != null) return _group;
    final g = await SyncGroup.load(s);
    if (g.fresh) {
      _deviceId = await identity.resetDeviceId();
      _clock = null;
    }
    return _group = g;
  }

  Future<String> deviceId() async {
    await group();
    return _deviceId ??= await identity.deviceId();
  }

  Future<LanSync?> _lanSync() async {
    final g = await group();
    final d = discovery;
    if (g == null || d == null) return null;
    return _lan ??= LanSync(
      group: g,
      discovery: d,
      peer: peer,
      listens: listens,
      log: (m) => debugPrint('sync: $m'),
    );
  }

  /// Finds this group's devices on the network and syncs with each.
  Future<SyncRun> syncNow() async {
    final lan = await _lanSync();
    if (lan == null) return SyncRun.none;
    await refresh();
    return lan.syncNow();
  }

  /// App opened or brought forward: publish, listen (not on a Mac), sync.
  @override
  Future<void> foreground() async {
    await refresh();
    final lan = await _lanSync();
    if (lan == null) return;
    await lan.startListening();
    await lan.syncNow();
  }

  /// App going to the background: publish and push it to whoever is near.
  /// Keeps listening while the process lives (playback keeps it alive on
  /// Android); background scheduling is S7.
  @override
  Future<void> background() async {
    await refresh();
    await (await _lanSync())?.syncNow();
  }

  Future<Hlc> _clockNow() async =>
      _clock ??= await resumeClock(store, await deviceId());

  /// Fills missing portable keys, publishes what changed in the library
  /// (books, positions, finished, this device's name) and rebuilds [view].
  /// Call on launch, on pause, and before every sync.
  @override
  Future<void> refresh() async {
    await fillPortableKeys(db);
    final keys = await db.portableKeys();
    final books = <LocalBook>[];
    for (final book in await db.getAllAudiobooks()) {
      final key = keys[book.id];
      if (key == null) continue;
      final progress = await db.getProgress(book.id);
      final finished =
          progress?.positionSeconds == AppDatabase.finishedPositionSeconds;
      books.add(LocalBook(
        key: key,
        title: book.title,
        author: book.author,
        origin: book.origin,
        archiveId: key.startsWith('lv:') ? book.id : null,
        chapterCount: book.chapters.length,
        durationSeconds:
            book.chapters.fold(0, (sum, ch) => sum + ch.durationSeconds),
        chapter: finished ? null : progress?.chapterIndex,
        positionSeconds: finished ? null : progress?.positionSeconds,
        positionAtMillis: progress?.updatedAt.millisecondsSinceEpoch,
        finished: finished,
      ));
    }
    final now = _now();
    final published = await publishLocalState(
        store: store, clock: await _clockNow(), books: books, nowMillis: now);
    _clock = published.clock;
    await _publishDevice(now);
    await _rebuildView();
  }

  Future<void> _publishDevice(int now) async {
    final me = await deviceId();
    final payload = {
      'name': await identity.deviceName(),
      'platform': Platform.operatingSystem,
    };
    final current = await store.get('${SyncKind.device.name}|$me|$me');
    if (current != null &&
        current.payload['name'] == payload['name'] &&
        current.payload['platform'] == payload['platform']) {
      return;
    }
    _clock = (await _clockNow()).tick(now);
    await store.putAll([
      SyncRecord(kind: SyncKind.device, key: me, hlc: _clock!, payload: payload)
    ]);
  }

  @override
  Future<Map<String, String>> portableKeys() => db.portableKeys();

  @override
  Future<void> linkBook(String bookId, String key) async {
    await db.setPortableKey(bookId, key);
    await refresh();
  }

  @override
  Future<String> deviceName() => identity.deviceName();

  @override
  Future<void> setDeviceName(String name) async {
    await identity.setDeviceName(name);
    await _publishDevice(_now());
    await _rebuildView();
  }

  Future<void> _rebuildView() async =>
      _view.value = SyncView(await deviceId(), await store.all());

  /// One side of an exchange with a linked device.
  Future<SyncPeer> peer() async {
    final clock = await _clockNow();
    _clock = clock;
    return SyncPeer(store, onChanged: (changed) async {
      var c = _clock!;
      for (final r in changed) {
        c = c.receive(r.hlc, _now());
      }
      _clock = c;
      await _rebuildView();
    });
  }
}

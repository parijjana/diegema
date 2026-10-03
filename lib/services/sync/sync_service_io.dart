import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database_io.dart';
import '../../database/drift_sync_store.dart';
import '../../sync/hlc.dart';
import '../../sync/lan_sync.dart';
import '../../sync/link_code.dart';
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

  /// How long "Sync now" on a listening device waits for a Mac to dial in.
  final Duration callerWindow;

  /// This device's LAN IPv4 addresses, for link codes; injected by tests.
  final Future<List<String>> Function() localAddresses;

  Hlc? _clock;
  String? _deviceId;
  Future<SyncGroup?>? _group;
  bool _keysUnreadable = false;
  LanSync? _lan;
  StreamSubscription<PeerResult>? _lanExchanges;
  final ValueNotifier<LastSync?> _lastSync = ValueNotifier(null);
  int? _lastInbound;

  @override
  ValueListenable<LastSync?> get lastSync => _lastSync;

  /// Store writes that move the clock (publishing, and each step of an
  /// exchange) run one at a time, so a refresh can't overwrite a clock an
  /// incoming sync just advanced. Never held across the network.
  Future<void> _lock = Future.value();
  Future<T> _serial<T>(Future<T> Function() f) {
    final run = _lock.then((_) => f());
    _lock = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  SyncService(
    this.db, {
    SyncStore? store,
    this.identity = const DeviceIdentityStore(),
    int Function()? now,
    this.secrets,
    this.discovery,
    this.listens = false,
    Future<List<String>> Function()? localAddresses,
    this.callerWindow = const Duration(seconds: 6),
  })  : localAddresses = localAddresses ?? _lanIPv4Addresses,
        store = store ?? DriftSyncStore(db),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// This device's sync keys. Loaded before the device id is first used: a
  /// device whose keys are new gets a new id too.
  /// A keystore that fails to read turns sync off for this run (and is
  /// retried next time) rather than unlinking the device.
  Future<SyncGroup?> group() {
    final s = secrets;
    if (s == null) return Future.value();
    return _group ??= () async {
      try {
        final g = await SyncGroup.load(s);
        if (g.fresh) {
          _deviceId = await identity.resetDeviceId();
          _clock = null;
        }
        _keysUnreadable = false;
        return g;
      } catch (e) {
        debugPrint('sync: keys unavailable, sync off for now: $e');
        _keysUnreadable = true;
        _group = null;
        return null;
      }
    }();
  }

  Future<String> deviceId() async {
    await group();
    return _deviceId ??= await identity.deviceId();
  }

  Future<LanSync?> _lanSync() async {
    final g = await group();
    final d = discovery;
    if (g == null || d == null) return null;
    final existing = _lan;
    if (existing != null) return existing;
    final lan = _lan = LanSync(
      group: g,
      discovery: d,
      peer: peer,
      listens: listens,
      callerWindow: callerWindow,
      log: (m) => debugPrint('sync: $m'),
    );
    // Devices that dialled in, and devices a Mac dialled on seeing them,
    // count as syncs too.
    _lanExchanges = lan.exchanges.where((r) => r.ok).listen((_) {
      _lastInbound = _now();
      _lastSync.value =
          LastSync(DateTime.fromMillisecondsSinceEpoch(_now()), 1);
    });
    return lan;
  }

  /// App opened or brought forward: publish, listen (not on a Mac), sync.
  /// Never throws: called unawaited from app lifecycle callbacks.
  @override
  Future<void> foreground() => _logged('foreground', () async {
        await refresh();
        final lan = await _lanSync();
        if (lan == null) return;
        await _online(lan);
        await _run(lan);
      });

  /// App going to the background: publish and push it to whoever is near.
  /// Keeps listening while the process lives (playback keeps it alive on
  /// Android); background scheduling is S7.
  @override
  Future<void> background() => _logged('background', () async {
        await refresh();
        final lan = await _lanSync();
        if (lan != null) await _run(lan);
      });

  @override
  Future<bool> isLinked() async => (await group())?.linked ?? false;

  @override
  Future<int> syncNow() async {
    final lan = await _lanSync();
    if (lan == null) return 0;
    await refresh();
    return _run(lan, waitForCallers: true);
  }

  @override
  bool get canScan => Platform.isAndroid || Platform.isIOS;

  @override
  Future<LinkOffer> createLinkOffer() async {
    final g = await group();
    final lan = await _lanSync();
    if (g == null || lan == null) throw StateError('sync is unavailable');
    if (!g.linked) await g.create();
    await refresh();
    await _online(lan);
    final expires =
        DateTime.fromMillisecondsSinceEpoch(_now()).add(LinkCode.lifetime);
    final code = LinkCode(
      groupKey: g.key!,
      addresses: lan.port == null ? const [] : await localAddresses(),
      port: lan.port,
      name: await identity.deviceName(),
      expiresAtMillis: expires.millisecondsSinceEpoch,
    );
    return LinkOffer(code.encode(), expires);
  }

  @override
  Future<JoinOutcome> joinWithCode(String text,
      {bool replaceGroup = false}) async {
    final code = LinkCode.decode(text);
    if (code == null) return JoinOutcome.invalid;
    if (code.expiredAt(_now())) return JoinOutcome.expired;
    final g = await group();
    final lan = await _lanSync();
    if (g == null || lan == null) throw StateError('sync is unavailable');
    final current = g.key;
    final same = current != null &&
        base64.encode(current) == base64.encode(code.groupKey);
    if (current != null && !same && !replaceGroup) {
      return JoinOutcome.otherGroup;
    }
    if (!same) {
      // A listener advertises the old group's tag; start again on the new.
      await _offline(lan);
      await g.join(code.groupKey);
    }
    await refresh();
    await _online(lan);
    final port = code.port;
    if (port != null) {
      for (final a in code.addresses) {
        if ((await lan.syncWith(PeerAddress('link', a, port))).ok) {
          return JoinOutcome.linked;
        }
      }
    }
    final reached = await _run(lan);
    return reached > 0 ? JoinOutcome.linked : JoinOutcome.linkedNotSynced;
  }

  /// Listening (phones, PCs) or watching (a Mac) for the group's devices.
  Future<void> _online(LanSync lan) async {
    await lan.startListening();
    await lan.startWatching();
  }

  Future<void> _offline(LanSync? lan) async {
    await lan?.stopListening();
    await lan?.stopWatching();
  }

  /// Syncs with whoever is near and records it as [lastSync]. Devices are
  /// counted once however many ways they were reached.
  Future<int> _run(LanSync lan, {bool waitForCallers = false}) async {
    final run = await lan.syncNow(waitForCallers: waitForCallers);
    final reached = {
      for (final r in run.results)
        if (r.ok) r.peer.host,
    }.length;
    // A run that reached nobody doesn't hide a sync a device dialled in for
    // moments ago (a Mac reaching this phone as its app opened).
    final inbound = _lastInbound;
    if (reached == 0 && inbound != null && _now() - inbound < 30000) {
      return reached;
    }
    _lastSync.value =
        LastSync(DateTime.fromMillisecondsSinceEpoch(_now()), reached);
    return reached;
  }

  @override
  Future<SyncStatus> status() async {
    final g = await group();
    if (g == null) {
      return _keysUnreadable ? SyncStatus.keysUnreadable : SyncStatus.unlinked;
    }
    return g.linked ? SyncStatus.linked : SyncStatus.unlinked;
  }

  @override
  Future<void> forgetDevice(String id) async {
    if (id == await deviceId()) return;
    await _serial(() async {
      _clock = (await _clockNow()).tick(_now());
      await store
          .putAll([SyncRecord(kind: SyncKind.forget, key: id, hlc: _clock!)]);
      await _rebuildView();
    });
    // Announce again so a watching Mac picks the removal up at once.
    final lan = await _lanSync();
    if (lan != null) {
      unawaited(_logged('announce after remove',
          () => _run(lan, waitForCallers: true)));
    }
  }

  @override
  Future<void> unlink() async {
    final g = await group();
    if (g == null || !g.linked) return;
    await _offline(_lan);
    await g.leave();
    // Other devices' books and positions go too; this device's own records
    // stay, so linking again later picks up where it was.
    await _serial(() async {
      await store.keepOnly(await deviceId());
      await _rebuildView();
    });
  }

  @override
  Future<void> resetKeys() async {
    final s = secrets;
    if (s == null) return;
    await _offline(_lan);
    await _lanExchanges?.cancel();
    _lanExchanges = null;
    await _lan?.dispose();
    _lan = null;
    await SyncGroup.wipe(s);
    _group = null;
    _keysUnreadable = false;
    await group();
    await refresh();
  }

  Future<void> _logged(String what, Future<void> Function() f) async {
    try {
      await f();
    } catch (e, st) {
      debugPrint('sync: $what failed: $e\n$st');
    }
  }

  Future<Hlc> _clockNow() async =>
      _clock ??= await resumeClock(store, await deviceId());

  /// Fills missing portable keys, publishes what changed in the library
  /// (books, positions, finished, this device's name) and rebuilds [view].
  /// Call on launch, on pause, and before every sync.
  @override
  Future<void> refresh() async {
    // Outside the lock: working out a local book's key reads its files.
    await fillPortableKeys(db);
    await _serial(_publish);
  }

  Future<void> _publish() async {
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
    await _serial(() async {
      await _publishDevice(_now());
      await _rebuildView();
    });
  }

  Future<void> _rebuildView() async =>
      _view.value = SyncView(await deviceId(), await store.all());

  /// One side of an exchange with a linked device.
  Future<SyncPeer> peer() async {
    final clock = await _clockNow();
    _clock = clock;
    return _SerialPeer(store, _serial, onChanged: (changed) async {
      var c = _clock!;
      for (final r in changed) {
        c = c.receive(r.hlc, _now());
      }
      _clock = c;
      await _rebuildView();
    });
  }
}

/// A [SyncPeer] whose steps take the service's store lock.
class _SerialPeer extends SyncPeer {
  final Future<T> Function<T>(Future<T> Function()) _serial;
  _SerialPeer(super.store, this._serial, {super.onChanged});

  @override
  Future<SyncMessage> hello() => _serial(super.hello);

  @override
  Future<SyncMessage> answer(SyncMessage hello) =>
      _serial(() => super.answer(hello));

  @override
  Future<SyncMessage> complete(SyncMessage answer) =>
      _serial(() => super.complete(answer));

  @override
  Future<void> finish(SyncMessage last) => _serial(() => super.finish(last));
}

/// Private-network IPv4 addresses (no loopback, no link-local).
Future<List<String>> _lanIPv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    return [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLinkLocal) a.address,
    ];
  } catch (_) {
    return const [];
  }
}

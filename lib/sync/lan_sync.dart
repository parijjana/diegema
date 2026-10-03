import 'dart:async';
import 'dart:io';

import 'secure/frame_channel.dart';
import 'secure/auth_session.dart';
import 'sync_exchange.dart';
import 'sync_group.dart';
import 'sync_over_session.dart';

/// A device found on the network advertising this group's tag.
class PeerAddress {
  /// The mDNS instance name, random per app run.
  final String instance;
  final String host;
  final int port;
  const PeerAddress(this.instance, this.host, this.port);
  @override
  String toString() => '$instance@$host:$port';
}

/// mDNS/DNS-SD (`_diegema._tcp`) behind an interface, so tests and the CLI
/// can stand in for bonsoir.
abstract class PeerDiscovery {
  Future<void> advertise(
      {required String instance, required int port, required String tag});
  Future<void> stopAdvertising();

  /// Devices advertising [tag] seen within [window], IPv4 preferred.
  Future<List<PeerAddress>> browse(
      {required String tag, required Duration window});

  /// Every time a device advertising [tag] appears (or announces itself
  /// again), until the subscription is cancelled. How a Mac, which can't
  /// listen, notices a phone the moment its app opens.
  Stream<PeerAddress> watch({required String tag});
}

class PeerResult {
  final PeerAddress peer;
  final ExchangeCounts? counts;
  final Object? error;
  const PeerResult(this.peer, {this.counts, this.error});
  bool get ok => error == null;
  @override
  String toString() => ok ? '$peer $counts' : '$peer FAILED $error';
}

class SyncRun {
  final List<PeerResult> results;
  const SyncRun(this.results);
  static const none = SyncRun([]);
}

/// Same-Wi-Fi sync with the group's other devices (SYNC_DESIGN §3).
/// Phones and Windows PCs listen and advertise; a Mac never listens (no
/// `network.server` entitlement) and only connects out.
class LanSync {
  final SyncGroup group;
  final PeerDiscovery discovery;
  final Future<SyncPeer> Function() peer;
  final bool listens;
  final InternetAddress bindAddress;
  final Duration browseWindow;

  /// For the handshake alone: short, so idle sockets free their slot fast.
  final Duration handshakeTimeout;

  /// For the exchange after it.
  final Duration timeout;
  final void Function(String)? log;

  /// The name this device advertises under: random, and new on every
  /// re-announcement (macOS doesn't report a service that stops and starts
  /// again under the same name, so a watching Mac would miss it).
  String get instance => _instance;
  String _instance;

  /// Every name this device has advertised under, to skip its own.
  final Set<String> _mine = {};

  static String _newInstance() =>
      'dg-${secureRandomBytes(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  /// Connections being served at once; more are dropped, so a stranger
  /// opening sockets can't pile up work.
  static const maxServing = 4;

  ServerSocket? _server;
  Future<void>? _starting;
  StreamSubscription<PeerAddress>? _watch;
  final Map<String, DateTime> _dialledAt = {};
  final _exchanges = StreamController<PeerResult>.broadcast();

  /// Every exchange this device didn't start from [syncNow]: devices that
  /// dialled in, and devices dialled because [startWatching] saw them.
  Stream<PeerResult> get exchanges => _exchanges.stream;

  /// How long an explicit [syncNow] on a listening device waits, after
  /// announcing itself again, for a watching Mac to dial in.
  final Duration callerWindow;
  int _serving = 0;
  Future<SyncRun>? _running;

  LanSync({
    required this.group,
    required this.discovery,
    required this.peer,
    required this.listens,
    InternetAddress? bindAddress,
    this.browseWindow = const Duration(seconds: 4),
    this.handshakeTimeout = const Duration(seconds: 5),
    this.timeout = const Duration(seconds: 20),
    this.callerWindow = const Duration(seconds: 6),
    this.log,
    String? instance,
  })  : bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        _instance = instance ?? _newInstance() {
    _mine.add(_instance);
  }

  bool get listening => _server != null;

  /// The port this device listens on, while it does.
  int? get port => _server?.port;

  /// Concurrent calls share one start.
  Future<void> startListening() {
    if (!listens || _server != null) return Future.value();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final tag = await group.tag();
    if (tag == null) return;
    final server = _server = await ServerSocket.bind(bindAddress, 0);
    server.listen(_serve);
    await discovery.advertise(instance: instance, port: server.port, tag: tag);
    log?.call('listening ${server.port} as $instance');
  }

  Future<void> stopListening() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    await discovery.stopAdvertising();
    await server.close();
  }

  /// A device that doesn't listen (a Mac) watches for its group's devices
  /// and dials each one as it appears.
  Future<void> startWatching() async {
    if (listens || _watch != null) return;
    final tag = await group.tag();
    if (tag == null) return;
    _watch = discovery.watch(tag: tag).listen((p) {
      if (!_mine.contains(p.instance)) unawaited(_dialSeen(p));
    });
  }

  Future<void> stopWatching() async {
    await _watch?.cancel();
    _watch = null;
  }

  /// One device is seen several times in a burst (one sighting per address);
  /// dial it once per burst. Short, so a "Sync now" re-announcement soon
  /// after is still answered.
  Future<void> _dialSeen(PeerAddress p) async {
    final now = DateTime.now();
    final last = _dialledAt[p.instance];
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _dialledAt[p.instance] = now;
    final result = await syncWith(p);
    log?.call('saw ${p.instance}: $result');
    _exchanges.add(result);
  }

  /// Stops and starts the advertisement, so devices watching (a Mac) see
  /// this one appear again and dial it.
  Future<void> _reannounce() async {
    final server = _server;
    final tag = await group.tag();
    if (server == null || tag == null) return;
    await discovery.stopAdvertising();
    _instance = _newInstance();
    _mine.add(_instance);
    await discovery.advertise(instance: instance, port: server.port, tag: tag);
    log?.call('announced again as $instance');
  }

  /// Exchanges are not serialised here: the [SyncPeer] steps are short
  /// store operations, merging is idempotent, and holding a lock across a
  /// network round trip deadlocks two devices that dial each other at once.
  void _serve(Socket socket) {
    if (_serving >= maxServing) {
      socket.destroy();
      return;
    }
    _serving++;
    unawaited(() async {
      final channel = LengthPrefixedChannel(socket, socket);
      try {
        final session =
            await AuthSession.respond(channel, group.sessionConfig())
                .timeout(handshakeTimeout);
        final counts =
            await syncAsResponder(session, await peer()).timeout(timeout);
        log?.call('served ${socket.remoteAddress.address} $counts');
        _exchanges.add(PeerResult(
            PeerAddress('inbound', socket.remoteAddress.address, 0),
            counts: counts));
      } catch (e) {
        log?.call('serve failed ${socket.remoteAddress.address}: $e');
      } finally {
        _serving--;
        await channel.close();
      }
    }());
  }

  /// Finds the group's devices on this network and syncs with each. A call
  /// while one is running joins it. With [waitForCallers], a listening
  /// device also announces itself again and counts the devices that dial
  /// in within [callerWindow] (a Mac can't be dialled, only dial).
  Future<SyncRun> syncNow({bool waitForCallers = false}) =>
      _running ??= _syncNow(waitForCallers).whenComplete(() {
        _running = null;
      });

  Future<SyncRun> _syncNow(bool waitForCallers) async {
    if (waitForCallers && listens && _server != null) {
      final inbound = <PeerResult>[];
      final sub = exchanges.where((r) => r.ok).listen(inbound.add);
      try {
        await _reannounce();
        final out = await _dialAll();
        await Future<void>.delayed(callerWindow);
        return SyncRun([...out.results, ...inbound]);
      } finally {
        await sub.cancel();
      }
    }
    return _dialAll();
  }

  Future<SyncRun> _dialAll() async {
    final tag = await group.tag();
    if (tag == null) return SyncRun.none;
    final found = await discovery.browse(tag: tag, window: browseWindow);
    final peers = {
      for (final p in found)
        if (!_mine.contains(p.instance)) p.instance: p,
    }.values;
    final results = <PeerResult>[];
    for (final p in peers) {
      results.add(await syncWith(p));
    }
    log?.call('sync run: ${results.join('; ')}');
    return SyncRun(results);
  }

  /// One exchange with [p], dialled directly (a link code's address, or a
  /// device found by [syncNow]).
  Future<PeerResult> syncWith(PeerAddress p) async {
    FrameChannel? channel;
    try {
      // Closed through the channel.
      // ignore: close_sinks
      final socket = await Socket.connect(p.host, p.port,
          timeout: const Duration(seconds: 5));
      channel = LengthPrefixedChannel(socket, socket);
      final session = await AuthSession.initiate(channel, group.sessionConfig())
          .timeout(handshakeTimeout);
      final counts =
          await syncAsInitiator(session, await peer()).timeout(timeout);
      return PeerResult(p, counts: counts);
    } catch (e) {
      return PeerResult(p, error: e);
    } finally {
      await channel?.close();
    }
  }
}

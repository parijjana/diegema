import 'dart:async';
import 'dart:io';

import 'secure/frame_channel.dart';
import 'secure/secure_session.dart';
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
  final Duration timeout;
  final void Function(String)? log;

  /// Random per run, so a device skips its own advertisement.
  final String instance;

  ServerSocket? _server;
  Future<void> _lock = Future.value();
  Future<SyncRun>? _running;

  LanSync({
    required this.group,
    required this.discovery,
    required this.peer,
    required this.listens,
    InternetAddress? bindAddress,
    this.browseWindow = const Duration(seconds: 4),
    this.timeout = const Duration(seconds: 20),
    this.log,
    String? instance,
  })  : bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        instance = instance ??
            'dg-${secureRandomBytes(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  bool get listening => _server != null;

  /// One exchange at a time, whichever side started it, so two merges never
  /// interleave on the store.
  Future<T> _exclusive<T>(Future<T> Function() f) {
    final run = _lock.then((_) => f());
    _lock = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> startListening() async {
    if (!listens || _server != null) return;
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

  void _serve(Socket socket) {
    unawaited(_exclusive(() async {
      final channel = LengthPrefixedChannel(socket, socket);
      try {
        final session =
            await SecureSession.respond(channel, group.sessionConfig())
                .timeout(timeout);
        final counts =
            await syncAsResponder(session, await peer()).timeout(timeout);
        log?.call('served ${socket.remoteAddress.address} $counts');
      } catch (e) {
        log?.call('serve failed ${socket.remoteAddress.address}: $e');
      } finally {
        await channel.close();
      }
    }));
  }

  /// Finds the group's devices on this network and syncs with each. A call
  /// while one is running joins it.
  Future<SyncRun> syncNow() => _running ??= _syncNow().whenComplete(() {
        _running = null;
      });

  Future<SyncRun> _syncNow() async {
    final tag = await group.tag();
    if (tag == null) return SyncRun.none;
    final found = await discovery.browse(tag: tag, window: browseWindow);
    final peers = {
      for (final p in found)
        if (p.instance != instance) p.instance: p,
    }.values;
    final results = <PeerResult>[];
    for (final p in peers) {
      results.add(await _exclusive(() => _syncWith(p)));
    }
    log?.call('sync run: ${results.join('; ')}');
    return SyncRun(results);
  }

  Future<PeerResult> _syncWith(PeerAddress p) async {
    FrameChannel? channel;
    try {
      // Closed through the channel.
      // ignore: close_sinks
      final socket = await Socket.connect(p.host, p.port,
          timeout: const Duration(seconds: 5));
      channel = LengthPrefixedChannel(socket, socket);
      final session =
          await SecureSession.initiate(channel, group.sessionConfig())
              .timeout(timeout);
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

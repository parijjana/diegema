import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import '../sync/lan_sync.dart';

const _service = '_diegema._tcp.local';

/// A device found on the network, whatever group it is in.
class SeenService {
  final PeerAddress address;

  /// The group tag it advertises (the TXT record's `g`).
  final String? tag;
  const SeenService(this.address, this.tag);
}

/// Pure-Dart mDNS for the CLI (the app uses bonsoir, which needs Flutter).
/// Browse only: like the Mac app, the CLI never listens or advertises.
class MdnsPeerDiscovery implements PeerDiscovery {
  /// How often [watch] browses again.
  final Duration pollEvery;
  MdnsPeerDiscovery({this.pollEvery = const Duration(seconds: 2)});

  /// Every `_diegema._tcp` service answering within [window].
  Future<List<SeenService>> browseAll(Duration window) async {
    final client = MDnsClient();
    final found = <String, SeenService>{};
    await client.start();
    try {
      await for (final ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_service),
          timeout: window)) {
        final name = ptr.domainName;
        final instance = name.endsWith('.$_service')
            ? name.substring(0, name.length - _service.length - 1)
            : name;
        if (found.containsKey(instance)) continue;
        final srv = await client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(name),
                timeout: const Duration(seconds: 2))
            .firstOrNullAsync;
        if (srv == null) continue;
        final txt = await client
            .lookup<TxtResourceRecord>(ResourceRecordQuery.text(name),
                timeout: const Duration(seconds: 2))
            .firstOrNullAsync;
        final ip = await client
            .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
                timeout: const Duration(seconds: 2))
            .firstOrNullAsync;
        if (ip == null) continue;
        found[instance] = SeenService(
            PeerAddress(instance, ip.address.address, srv.port),
            _tag(txt?.text));
      }
    } finally {
      client.stop();
    }
    return found.values.toList();
  }

  static String? _tag(String? text) {
    if (text == null) return null;
    for (final entry in text.split('\n')) {
      if (entry.startsWith('g=')) return entry.substring(2);
    }
    return null;
  }

  @override
  Future<List<PeerAddress>> browse(
          {required String tag, required Duration window}) async =>
      [
        for (final s in await browseAll(window))
          if (s.tag == tag) s.address,
      ];

  /// Browses over and over, reporting each instance once. A device that
  /// announces itself again does so under a new name, so it is reported
  /// again.
  @override
  Stream<PeerAddress> watch({required String tag}) {
    final seen = <String>{};
    var running = true;
    // Closed by its listener cancelling.
    // ignore: close_sinks
    late final StreamController<PeerAddress> out;
    out = StreamController<PeerAddress>(
      onListen: () async {
        while (running) {
          try {
            for (final p in await browse(tag: tag, window: pollEvery)) {
              if (seen.add(p.instance) && !out.isClosed) out.add(p);
            }
          } catch (e) {
            if (!out.isClosed) out.addError(e);
            return;
          }
        }
      },
      onCancel: () {
        running = false;
      },
    );
    return out.stream;
  }

  @override
  Future<void> advertise(
          {required String instance,
          required int port,
          required String tag}) =>
      throw UnsupportedError('the CLI never advertises');

  @override
  Future<void> stopAdvertising() async {}
}

extension<T> on Stream<T> {
  Future<T?> get firstOrNullAsync async {
    await for (final v in this) {
      return v;
    }
    return null;
  }
}

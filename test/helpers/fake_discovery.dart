import 'dart:async';

import 'package:diegema/sync/lan_sync.dart';

/// mDNS stand-in: one shared registry, everything on loopback.
class FakeNetwork {
  final Map<String, (int, String)> services = {};
  // Lives as long as the test's network.
  // ignore: close_sinks
  final _appeared = StreamController<(String, int, String)>.broadcast();
}

class FakeDiscovery implements PeerDiscovery {
  final FakeNetwork net;
  String? _mine;
  FakeDiscovery(this.net);

  @override
  Future<void> advertise(
      {required String instance,
      required int port,
      required String tag}) async {
    _mine = instance;
    net.services[instance] = (port, tag);
    net._appeared.add((instance, port, tag));
  }

  @override
  Stream<PeerAddress> watch({required String tag}) => net._appeared.stream
      .where((s) => s.$3 == tag)
      .map((s) => PeerAddress(s.$1, '127.0.0.1', s.$2));

  @override
  Future<void> stopAdvertising() async => net.services.remove(_mine);

  @override
  Future<List<PeerAddress>> browse(
          {required String tag, required Duration window}) async =>
      [
        for (final e in net.services.entries)
          if (e.value.$2 == tag) PeerAddress(e.key, '127.0.0.1', e.value.$1),
      ];
}

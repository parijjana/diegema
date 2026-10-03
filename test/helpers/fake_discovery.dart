import 'package:diegema/sync/lan_sync.dart';

/// mDNS stand-in: one shared registry, everything on loopback.
class FakeNetwork {
  final Map<String, (int, String)> services = {};
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
  }

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

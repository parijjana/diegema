import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../sync/lan_sync.dart';
import '../../sync/sync_group.dart';

const diegemaServiceType = '_diegema._tcp';

/// The platform keystore (Android Keystore, iOS Keychain, Windows DPAPI).
/// A value that can no longer be decrypted (keystore reset) reads as
/// missing, which leaves the device unlinked rather than stuck.
class KeystoreSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;
  KeystoreSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('sync: keystore read $key failed, treating as missing: $e');
      try {
        await _storage.delete(key: key);
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// macOS: a JSON file in the app's sandbox container, which only this app
/// can read. The Keychain needs a properly signed build (lessons_learnt
/// flutter-secure-storage-macos-sandbox.md); owner decision 2026-10-03.
class FileSecretStore implements SecretStore {
  final Future<File> Function() _file;
  FileSecretStore([Future<File> Function()? file])
      : _file = file ??
            (() async => File(p.join(
                (await getApplicationSupportDirectory()).path,
                'sync_secrets.json')));

  Future<Map<String, String>> _load() async {
    final f = await _file();
    if (!await f.exists()) return {};
    try {
      return (jsonDecode(await f.readAsString()) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, String> values) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(values), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) async =>
      _save({...await _load(), key: value});

  @override
  Future<void> delete(String key) async => _save(await _load()
    ..remove(key));
}

SecretStore platformSecretStore() =>
    Platform.isMacOS ? FileSecretStore() : KeystoreSecretStore();

/// Phones and Windows listen; a Mac only connects out (SYNC_DESIGN §3).
bool get platformListens => !Platform.isMacOS;

class BonsoirPeerDiscovery implements PeerDiscovery {
  BonsoirBroadcast? _broadcast;

  @override
  Future<void> advertise(
      {required String instance,
      required int port,
      required String tag}) async {
    await stopAdvertising();
    final b = _broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: instance,
        type: diegemaServiceType,
        port: port,
        attributes: {'g': tag},
      ),
    );
    await b.initialize();
    await b.start();
  }

  @override
  Future<void> stopAdvertising() async {
    final b = _broadcast;
    _broadcast = null;
    try {
      await b?.stop();
    } catch (_) {}
  }

  @override
  Future<List<PeerAddress>> browse(
      {required String tag, required Duration window}) async {
    final d = BonsoirDiscovery(type: diegemaServiceType);
    final found = <String, PeerAddress>{};
    StreamSubscription<BonsoirDiscoveryEvent>? sub;
    try {
      await d.initialize();
      sub = d.eventStream?.listen((e) {
        switch (e) {
          case BonsoirDiscoveryServiceFoundEvent():
            if (e.service.attributes['g'] == tag) {
              e.service.resolve(d.serviceResolver);
            }
          case BonsoirDiscoveryServiceResolvedEvent():
            final s = e.service;
            if (s.attributes['g'] != tag || s.port <= 0) return;
            // Resolution also returns IPv6 (link-local and global); IPv4 is
            // what every platform here connects over reliably.
            final v4 = s.hostAddresses.where((a) => !a.contains(':'));
            final host = v4.isNotEmpty ? v4.first : s.hostname;
            if (host == null) return;
            found[s.name] = PeerAddress(s.name, host, s.port);
          default:
        }
      });
      await d.start();
      await Future<void>.delayed(window);
    } catch (e) {
      debugPrint('sync: discovery failed: $e');
    } finally {
      await sub?.cancel();
      try {
        await d.stop();
      } catch (_) {}
    }
    return found.values.toList();
  }
}

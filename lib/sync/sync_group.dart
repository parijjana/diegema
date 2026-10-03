import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure/secure_session.dart';

/// Where this device keeps its sync secrets: the platform keystore on
/// phones and Windows, a file in the sandbox container on macOS (the
/// Keychain needs a properly signed build; see lessons_learnt
/// flutter-secure-storage-macos-sandbox.md).
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// This device's identity key and, once linked, the group key it shares
/// with its other devices. The group key is what proves membership in a
/// session (it salts the session keys); removing a device means rotating
/// it. Losing the store (a reinstall restored from backup) leaves the
/// device unlinked, to be linked again.
class SyncGroup {
  static const _seedKey = 'sync.device_seed.v1';
  static const _groupKey = 'sync.group_key.v1';

  final SecretStore _store;
  final DeviceIdentity identity;
  Uint8List? _key;

  SyncGroup._(this._store, this.identity, this._key);

  static Future<SyncGroup> load(SecretStore store,
      {List<int> Function(int)? randomBytes}) async {
    final random = randomBytes ?? secureRandomBytes;
    final seed = await store.read(_seedKey);
    DeviceIdentity identity;
    if (seed == null) {
      final (id, newSeed) = await DeviceIdentity.generate(randomBytes: random);
      await store.write(_seedKey, base64.encode(newSeed));
      identity = id;
    } else {
      identity = await DeviceIdentity.fromSeed(base64.decode(seed));
    }
    final key = await store.read(_groupKey);
    return SyncGroup._(
        store, identity, key == null ? null : base64.decode(key));
  }

  bool get linked => _key != null;

  /// The group key, for sessions and for handing to a device being linked.
  Uint8List? get key => _key;

  /// Starts a group with this device alone in it (the first link does this).
  Future<void> create({List<int> Function(int)? randomBytes}) =>
      join((randomBytes ?? secureRandomBytes)(32));

  /// Takes the group key a linking device sent.
  Future<void> join(List<int> groupKey) async {
    if (groupKey.length != 32) {
      throw ArgumentError('group key must be 32 bytes');
    }
    _key = Uint8List.fromList(groupKey);
    await _store.write(_groupKey, base64.encode(_key!));
  }

  Future<void> leave() async {
    _key = null;
    await _store.delete(_groupKey);
  }

  /// What devices advertise over mDNS so they find their own group without
  /// saying anything about themselves: 8 bytes of HMAC of the group key.
  /// Null while unlinked.
  Future<String?> tag() async {
    final k = _key;
    if (k == null) return null;
    final mac = await Hmac.sha256()
        .calculateMac(utf8.encode('diegema-tag/1'), secretKey: SecretKey(k));
    return mac.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Session settings for a sync with another member.
  SessionConfig sessionConfig() {
    final k = _key;
    if (k == null) throw StateError('not linked');
    return SessionConfig(
      mode: SessionMode.group,
      identity: identity,
      preSharedKey: k,
      // The group key already proved membership.
      acceptPeer: (_) async => true,
    );
  }
}

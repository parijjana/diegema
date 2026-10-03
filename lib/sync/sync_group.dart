import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure/auth_session.dart';

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

/// The group key this device shares with its other devices, once linked.
/// It is what proves membership in a session; removing a device means
/// rotating it. Losing the store (a reinstall restored from backup) leaves
/// the device unlinked, to be linked again.
class SyncGroup {
  static const _installKey = 'sync.install.v1';
  static const _groupKey = 'sync.group_key.v1';

  final SecretStore _store;
  Uint8List? _key;

  /// The store was empty, so this is a new install as far as sync goes: a
  /// fresh install, or a backup restored onto this or another phone
  /// (backups carry preferences, never the keystore). The caller gives the
  /// device a new sync id too, so two phones never write under one id.
  final bool fresh;

  SyncGroup._(this._store, this._key, {this.fresh = false});

  static Future<SyncGroup> load(SecretStore store,
      {List<int> Function(int)? randomBytes}) async {
    final install = await store.read(_installKey);
    final key = await store.read(_groupKey);
    // Marked only after every read succeeded: a read that throws must not
    // leave a marker that hides a restored install next time.
    if (install == null) {
      await store.write(
          _installKey, base64.encode((randomBytes ?? secureRandomBytes)(16)));
    }
    return SyncGroup._(store, key == null ? null : base64.decode(key),
        fresh: install == null);
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

  /// Deletes every sync secret, for a store that can't be read any more.
  /// The next [load] is fresh: a new device id, unlinked. Best effort: a
  /// key that won't delete is overwritten by that load's writes.
  static Future<void> wipe(SecretStore store) async {
    for (final k in const [_installKey, _groupKey, 'sync.device_seed.v1']) {
      try {
        await store.delete(k);
      } catch (_) {}
    }
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
    return SessionConfig(groupKey: k);
  }
}

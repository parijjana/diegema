import 'dart:convert';
import 'dart:io';

import 'sync_group.dart';

/// The file the macOS app keeps its sync secrets in, inside its
/// Application Support folder.
const syncSecretsFileName = 'sync_secrets.json';

/// Secrets as a JSON file. On macOS the app's sandbox container keeps it
/// readable only by the app (and by its owner's `diegema-sync` CLI).
class FileSecretStore implements SecretStore {
  final Future<File> Function() _file;
  FileSecretStore(this._file);

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

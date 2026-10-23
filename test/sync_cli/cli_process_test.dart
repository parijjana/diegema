@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:diegema/database/app_database_io.dart';
import 'package:diegema/database/drift_sync_store.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real front door: the CLI run as a process, as from a terminal.
Future<ProcessResult> cli(List<String> args) =>
    Process.run('dart', ['run', 'bin/diegema_sync.dart', ...args],
        environment: {'DIEGEMA_DEVICE_ID': 'aaaa1111'});

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('dg_cli'));
  tearDown(() => dir.delete(recursive: true));

  test('--json devices, and a failure is one line with exit 1', () async {
    final file = File('${dir.path}/diegema.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    await DriftSyncStore(db).putAll([
      SyncRecord(
          kind: SyncKind.device,
          key: 'aaaa1111',
          hlc: const Hlc(100, 0, 'aaaa1111'),
          payload: {'name': 'MacBook', 'platform': 'macos'}),
    ]);
    await db.close();

    final ok = await cli(['--db', file.path, '--json', 'devices']);
    expect(ok.exitCode, 0, reason: '${ok.stderr}');
    final json = jsonDecode((ok.stdout as String).split('\n').lastWhere(
        (l) => l.startsWith('['))) as List;
    expect(json.single['name'], 'MacBook');
    expect(json.single['self'], isTrue);

    final missing = await cli(['--db', '${dir.path}/nope.sqlite', 'status']);
    expect(missing.exitCode, 1);
    // `dart run` prefixes its own build progress; the CLI's is one line.
    final err = (missing.stderr as String)
        .replaceAll('Running build hooks...', '')
        .trim();
    expect(err.split('\n'),
        [startsWith('diegema-sync: no Diegema database')]);

    final usage = await cli(['frobnicate']);
    expect(usage.exitCode, 64);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

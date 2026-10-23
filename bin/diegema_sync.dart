import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync_cli/sync_tool.dart';

/// `diegema-sync`: inspect and run linked-device sync from a terminal
/// (SYNC_DESIGN S10). A thin front door onto lib/sync_cli/sync_tool.dart.
///
///     dart run bin/diegema_sync.dart COMMAND [options]
Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addFlag('json', negatable: false, help: 'Machine-readable output.')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Log sync steps.')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('db', help: 'The app database (default: this computer\'s app).')
    ..addOption('secrets', help: 'The sync secrets file.')
    ..addOption('device-id', help: 'This computer\'s device id.');
  parser.addCommand('status');
  parser.addCommand('devices');
  parser.addCommand('log')
    ..addOption('device', help: 'Only this device (id prefix).')
    ..addOption('kind',
        allowed: [for (final k in SyncKind.values) k.name],
        help: 'Only this kind of record.')
    ..addOption('limit', defaultsTo: '50');
  parser.addCommand('peers')
    ..addFlag('all',
        negatable: false, help: 'Every Diegema device, not just this group.')
    ..addOption('window', defaultsTo: '4', help: 'Seconds to listen.');
  parser.addCommand('sync')
    ..addOption('watch',
        defaultsTo: '0',
        help: 'Keep looking this many seconds, syncing with each device '
            'as it appears.')
    ..addFlag('force',
        negatable: false, help: 'Sync even though the app is running.');
  parser.addCommand('export').addOption('out',
      defaultsTo: '.',
      help: 'File to write, or a folder for the default file name.');
  parser.addCommand('import').addFlag('force',
      negatable: false, help: 'Import even though the app is running.');

  String usage() => 'usage: diegema-sync <status|devices|log|peers|sync|export|import> '
      '[options]\n\n${parser.usage}\n\n'
      'log:   --device <id> --kind <kind> --limit <n>\n'
      'peers: --all --window <s>\n'
      'sync:  --watch <s> --force\n'
      'export: --out <file or folder>\n'
      'import: <file> --force';

  ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln('diegema-sync: ${e.message}\n\n${usage()}');
    exit(64);
  }
  final cmd = args.command;
  if (args.flag('help') || cmd == null) {
    (cmd == null && !args.flag('help') ? stderr : stdout).writeln(usage());
    exit(cmd == null && !args.flag('help') ? 64 : 0);
  }
  final json = args.flag('json');
  void out(Object? data, String Function() human) =>
      stdout.writeln(json ? jsonEncode(data) : human());

  int seconds(String name) {
    final v = int.tryParse(cmd.option(name)!);
    if (v == null || v < 0) throw ToolError('--$name must be a whole number');
    return v;
  }

  try {
    final tool = SyncTool(
      await AppData.resolve(
        database: args.option('db'),
        secrets: args.option('secrets'),
        deviceId: args.option('device-id'),
      ),
      trace: args.flag('verbose') ? (m) => stderr.writeln('sync: $m') : null,
    );
    switch (cmd.name) {
      case 'status':
        final s = await tool.status();
        out(s.toJson(), () => [
              'database  ${s.data.database.path}',
              'secrets   ${s.data.secrets?.path ?? '(OS keystore)'}',
              'device    ${s.data.deviceId ?? '(unknown)'}',
              'linked    ${s.linked ? 'yes (group ${s.tag})' : 'no'}',
              'records   ${s.records} from ${s.devices} device(s)',
              'app       ${s.appRunning ? 'running' : 'not running'}',
            ].join('\n'));
      case 'devices':
        final rows = await tool.devices();
        out([for (final d in rows) d.toJson()], () {
          if (rows.isEmpty) return 'no devices';
          return [
            for (final d in rows)
              '${d.self ? '*' : ' '} ${d.id.substring(0, d.id.length.clamp(0, 8))}  '
                  '${d.name.padRight(28)} ${(d.platform ?? '?').padRight(8)} '
                  '${d.records.toString().padLeft(4)} records  '
                  'latest ${d.latest?.toLocal().toString().substring(0, 19) ?? '-'}',
          ].join('\n');
        });
      case 'log':
        final limit = int.tryParse(cmd.option('limit')!);
        if (limit == null || limit < 1) {
          throw const ToolError('--limit must be a positive number');
        }
        final kind = cmd.option('kind');
        final rows = await tool.log(
            device: cmd.option('device'),
            kind: kind == null ? null : SyncKind.values.byName(kind),
            limit: limit);
        out([for (final r in rows) recordJson(r)], () {
          if (rows.isEmpty) return 'no records';
          return [
            for (final r in rows)
              '${DateTime.fromMillisecondsSinceEpoch(r.hlc.wallMillis).toLocal().toString().substring(0, 19)}  '
                  '${r.deviceId.substring(0, r.deviceId.length.clamp(0, 8))}  '
                  '${r.kind.name.padRight(9)} ${r.deleted ? '(removed) ' : ''}'
                  '${r.key}  ${jsonEncode(r.payload)}',
          ].join('\n');
        });
      case 'peers':
        final rows = await tool.peers(
            window: Duration(seconds: seconds('window')),
            all: cmd.flag('all'));
        out([for (final p in rows) p.toJson()], () {
          if (rows.isEmpty) return 'no devices found';
          return [
            for (final p in rows)
              '${p.address.instance.padRight(14)} ${p.address.host}:${p.address.port}'
                  '${p.inGroup == null ? '' : p.inGroup! ? '  this group' : '  other group'}',
          ].join('\n');
        });
      case 'sync':
        final results = await tool.sync(
            watch: Duration(seconds: seconds('watch')),
            force: cmd.flag('force'));
        out([for (final r in results) resultJson(r)], () {
          if (results.isEmpty) return 'no linked devices found';
          return [
            for (final r in results)
              r.ok
                  ? '${r.peer.host}  sent ${r.counts!.sent}, received ${r.counts!.received}'
                  : '${r.peer.host}  failed: ${r.error}',
          ].join('\n');
        });
        if (results.isNotEmpty && results.every((r) => !r.ok)) exit(1);
      case 'export':
        final file = await tool.exportFile(cmd.option('out')!);
        out({'file': file.path}, () => 'wrote ${file.path}');
      case 'import':
        if (cmd.rest.length != 1) {
          stderr.writeln('diegema-sync: import takes one file\n\n${usage()}');
          exit(64);
        }
        final r =
            await tool.importFile(cmd.rest.single, force: cmd.flag('force'));
        out(
            r.toJson(),
            () => '${r.records} records from '
                '${r.from.substring(0, r.from.length.clamp(0, 8))}, '
                '${r.changed} new or newer here');
    }
  } on ToolError catch (e) {
    stderr.writeln('diegema-sync: ${e.message}');
    exit(1);
  } catch (e) {
    stderr.writeln('diegema-sync: ${'$e'.split('\n').first}');
    exit(1);
  }
  exit(0);
}

import 'dart:convert';

import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/sync_file.dart';
import 'package:diegema/sync/sync_group.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:flutter_test/flutter_test.dart';

final key = List<int>.generate(32, (i) => i);
final otherKey = List<int>.generate(32, (i) => 255 - i);

final records = [
  SyncRecord(
      kind: SyncKind.position,
      key: 'lv:emma',
      hlc: const Hlc(200, 1, 'mac'),
      payload: const {'chapter': 2, 'seconds': 90}),
  SyncRecord(
      kind: SyncKind.catalogue,
      key: 'lv:emma',
      hlc: const Hlc(150, 0, 'phone'),
      payload: const {'title': 'Emma'},
      deleted: true),
];

Future<List<int>> written([List<int>? k]) => SyncFile.encode(
    groupKey: k ?? key,
    deviceId: 'mac',
    createdAtMillis: 1234,
    records: records);

Matcher refused(SyncFileProblem p) =>
    throwsA(isA<SyncFileError>().having((e) => e.problem, 'problem', p));

/// The file with its JSON fields changed by [change].
List<int> altered(List<int> bytes, void Function(Map<String, Object?>) change) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  change(json);
  return utf8.encode(jsonEncode(json));
}

void main() {
  test('round trip keeps every record, its stamp and its tombstone', () async {
    final file = await SyncFile.decode(await written(), groupKey: key);
    expect(file.deviceId, 'mac');
    expect(file.createdAtMillis, 1234);
    expect(file.records.map((r) => r.encode()), records.map((r) => r.encode()));
  });

  test('is signed, not encrypted: records are readable in the file', () async {
    expect(utf8.decode(await written()), contains('lv:emma'));
  });

  test('a file from another group is told apart from a damaged one', () async {
    expect(SyncFile.decode(await written(otherKey), groupKey: key),
        refused(SyncFileProblem.otherGroup));
  });

  test('a changed body is refused as damaged', () async {
    final bytes = altered(await written(), (j) {
      j['body'] =
          (j['body'] as String).replaceFirst('"seconds":90', '"seconds":91');
    });
    expect(SyncFile.decode(bytes, groupKey: key),
        refused(SyncFileProblem.damaged));
  });

  test('a forged group tag still fails the signature', () async {
    final tag = await groupTagOf(key);
    final bytes = altered(await written(otherKey), (j) => j['group'] = tag);
    expect(SyncFile.decode(bytes, groupKey: key),
        refused(SyncFileProblem.damaged));
  });

  test('a mangled signature is damaged, not a crash', () async {
    final bytes = altered(await written(), (j) => j['mac'] = '!!not base64');
    expect(SyncFile.decode(bytes, groupKey: key),
        refused(SyncFileProblem.damaged));
  });

  test('anything else is not a sync file', () async {
    expect(SyncFile.decode(utf8.encode('hello'), groupKey: key),
        refused(SyncFileProblem.notSyncFile));
    expect(SyncFile.decode(utf8.encode('[1,2]'), groupKey: key),
        refused(SyncFileProblem.notSyncFile));
    expect(SyncFile.decode([0xff, 0xfe, 0x00], groupKey: key),
        refused(SyncFileProblem.notSyncFile));
    final future =
        altered(await written(), (j) => j['format'] = 'diegema-sync-file/2');
    expect(SyncFile.decode(future, groupKey: key),
        refused(SyncFileProblem.notSyncFile));
  });

  test('the group tag is the one the group advertises', () async {
    final secrets = InMemorySecretStore();
    final group = await SyncGroup.load(secrets);
    await group.join(key);
    expect(await group.tag(), await groupTagOf(key));
  });

  test('file name: device name made safe, then the date', () {
    final when = DateTime(2026, 10, 4);
    expect(SyncFile.fileName('Animesh’s MacBook Pro', when),
        'diegema-animesh-s-macbook-pro-2026-10-04.diegemasync');
    expect(
        SyncFile.fileName('  ', when), 'diegema-device-2026-10-04.diegemasync');
  });
}

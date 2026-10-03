import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_view.dart';

SyncRecord r(SyncKind kind, String key, String device, int wall,
        [Map<String, Object?> payload = const {}, bool deleted = false]) =>
    SyncRecord(
        kind: kind,
        key: key,
        hlc: Hlc(wall, 0, device),
        payload: payload,
        deleted: deleted);

void main() {
  final records = [
    r(SyncKind.catalogue, 'lv:emma', 'mac', 1,
        {'title': 'Emma', 'origin': 'librivox', 'archiveId': 'emma_lv'}),
    r(SyncKind.catalogue, 'lv:emma', 'pc', 2,
        {'title': 'Emma', 'origin': 'librivox', 'archiveId': 'emma_lv'}),
    r(SyncKind.catalogue, 'ck:dune', 'mac', 3,
        {'title': 'Dune', 'origin': 'local'}),
    r(SyncKind.catalogue, 'ck:gone', 'mac', 4, {}, true),
    r(SyncKind.catalogue, 'lv:mine', 'phone', 5, {'title': 'Mine'}),
    r(SyncKind.position, 'lv:emma', 'mac', 6,
        {'chapter': 3, 'seconds': 100, 'at': 6000}),
    r(SyncKind.position, 'lv:emma', 'pc', 7,
        {'chapter': 1, 'seconds': 50, 'at': 7000}),
    r(SyncKind.furthest, 'lv:emma', 'mac', 6, {'chapter': 9, 'seconds': 1}),
    r(SyncKind.finished, 'ck:dune', 'mac', 8, {'finished': true}),
  ];
  final view = SyncView('phone', records);

  test('remote-only books: other devices\' listings minus local and removed',
      () {
    final books = view.remoteOnly({'ck:dune'});
    expect(books.map((b) => b.key), ['lv:emma']);
    expect(books.single.deviceIds, {'mac', 'pc'});
    expect(books.single.isLibrivox, isTrue);
    expect(view.remoteOnly({}).map((b) => b.title), ['Dune', 'Emma'],
        reason: 'own listings never count as remote; tombstones are skipped');
  });

  test('positions are newest first and exclude this device', () {
    expect(view.positions('lv:emma').map((p) => p.deviceId), ['pc', 'mac']);
  });

  test('resume offer: newest elsewhere, only if newer and somewhere else', () {
    expect(view.resumeOffer('lv:emma')!.deviceId, 'pc');
    expect(view.resumeOffer('lv:emma', localAtMillis: 8000), isNull);
    expect(
        view.resumeOffer('lv:emma',
            local: const DevicePosition('phone', 1, 60, 0), localAtMillis: 1),
        isNull,
        reason: 'within 15 s of where we already are');
    expect(view.resumeOffer('ck:none'), isNull);
  });

  test('furthest and finished', () {
    expect(view.furthestElsewhere('lv:emma')!.chapter, 9);
    expect(view.finishedOn('ck:dune'), {'mac'});
  });
}

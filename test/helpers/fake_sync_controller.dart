import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/hlc.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/sync/sync_view.dart';

/// A hand-made record, as `test/sync/sync_view_test.dart` makes them.
SyncRecord rec(SyncKind kind, String key, String device, int wall,
        [Map<String, Object?> payload = const {}, bool deleted = false]) =>
    SyncRecord(
        kind: kind,
        key: key,
        hlc: Hlc(wall, 0, device),
        payload: payload,
        deleted: deleted);

/// A [SyncController] with no database or network: the view is built from
/// the records a test hands it.
class FakeSyncController implements SyncController {
  final String deviceId;
  final ValueNotifier<SyncView?> _view = ValueNotifier(null);
  Map<String, String> keys;
  String name;

  int refreshCalls = 0;
  final List<(String, String)> links = [];

  /// Runs on every [refresh], before the view is rebuilt (a test can fill
  /// [keys] here the way the real service fills portable keys).
  Future<void> Function()? onRefresh;

  FakeSyncController({
    this.deviceId = 'me',
    List<SyncRecord> records = const [],
    Map<String, String> keys = const {},
    this.name = 'This phone',
  }) : keys = Map.of(keys) {
    setRecords(records);
  }

  List<SyncRecord> _records = const [];

  void setRecords(List<SyncRecord> records) {
    _records = records;
    _view.value = SyncView(deviceId, records);
  }

  @override
  ValueListenable<SyncView?> get view => _view;

  void clearView() => _view.value = null;

  @override
  Future<void> refresh() async {
    refreshCalls++;
    await onRefresh?.call();
    _view.value = SyncView(deviceId, _records);
  }

  bool linked = false;
  String? lastJoinCode;
  JoinOutcome joinOutcome = JoinOutcome.linked;

  /// Every `joinWithCode` call: the code and whether it replaced the group.
  final List<(String, bool)> joins = [];

  /// What a join with `replaceGroup: true` returns.
  JoinOutcome replaceOutcome = JoinOutcome.linked;

  /// Makes `createLinkOffer` throw.
  bool offerFails = false;

  @override
  Future<bool> isLinked() async => linked;

  int syncNowCalls = 0;

  /// Devices a [syncNow] reaches; it also records a [lastSync].
  int syncReached = 0;

  /// The time [syncNow] stamps its result with (null: now).
  DateTime Function()? syncClock;

  /// When set, [syncNow] waits for it (a test holds the spinner up).
  Completer<void>? syncGate;

  @override
  Future<int> syncNow() async {
    syncNowCalls++;
    await syncGate?.future;
    lastSyncNotifier.value =
        LastSync((syncClock ?? DateTime.now)(), syncReached);
    return syncReached;
  }

  @override
  bool canScan = false;

  @override
  Future<LinkOffer> createLinkOffer() async {
    if (offerFails) throw StateError('no network');
    linked = true;
    return LinkOffer(
        'DIEGEMALINK1.fake', DateTime.now().add(const Duration(minutes: 5)));
  }

  @override
  Future<JoinOutcome> joinWithCode(String code,
      {bool replaceGroup = false}) async {
    lastJoinCode = code;
    joins.add((code, replaceGroup));
    final outcome = replaceGroup ? replaceOutcome : joinOutcome;
    if (outcome == JoinOutcome.linked ||
        outcome == JoinOutcome.linkedNotSynced) {
      linked = true;
    }
    return outcome;
  }

  SyncStatus syncStatus = SyncStatus.unlinked;
  final ValueNotifier<LastSync?> lastSyncNotifier = ValueNotifier(null);
  final forgotten = <String>[];
  int unlinkCalls = 0;
  int resetCalls = 0;

  @override
  Future<SyncStatus> status() async =>
      linked && syncStatus == SyncStatus.unlinked
          ? SyncStatus.linked
          : syncStatus;

  @override
  ValueListenable<LastSync?> get lastSync => lastSyncNotifier;

  @override
  Future<void> forgetDevice(String deviceId) async => forgotten.add(deviceId);

  @override
  Future<void> unlink() async {
    unlinkCalls++;
    linked = false;
    syncStatus = SyncStatus.unlinked;
  }

  @override
  Future<void> resetKeys() async {
    resetCalls++;
    syncStatus = SyncStatus.unlinked;
  }

  @override
  Future<void> foreground() => refresh();

  @override
  Future<void> background() => refresh();

  @override
  Future<Map<String, String>> portableKeys() async => Map.of(keys);

  @override
  Future<void> linkBook(String bookId, String key) async {
    links.add((bookId, key));
    keys[bookId] = key;
    await refresh();
  }

  @override
  Future<String> deviceName() async => name;

  @override
  Future<void> setDeviceName(String value) async => name = value.trim();

  /// What [exportSyncFile] returns; null makes it throw (not linked).
  SyncFileExport? exportResult = const SyncFileExport(
      [1, 2, 3], 'diegema-this-phone-2026-10-04.diegemasync');
  int exportCalls = 0;

  @override
  Future<SyncFileExport> exportSyncFile() async {
    exportCalls++;
    return exportResult ?? (throw StateError('not linked'));
  }

  /// Every file [importSyncFile] was handed.
  final imports = <List<int>>[];

  /// What [importSyncFile] returns, or throws when it is an exception.
  Object importResult = 0;

  @override
  Future<int> importSyncFile(List<int> bytes) async {
    imports.add(bytes);
    final r = importResult;
    if (r is int) return r;
    throw r;
  }
}

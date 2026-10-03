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

  @override
  Future<bool> isLinked() async => linked;

  @override
  Future<int> syncNow() async => 0;

  @override
  bool canScan = false;

  @override
  Future<LinkOffer> createLinkOffer() async {
    linked = true;
    return LinkOffer(
        'DIEGEMALINK1.fake', DateTime.now().add(const Duration(minutes: 5)));
  }

  @override
  Future<JoinOutcome> joinWithCode(String code,
      {bool replaceGroup = false}) async {
    lastJoinCode = code;
    if (joinOutcome == JoinOutcome.linked ||
        joinOutcome == JoinOutcome.linkedNotSynced) {
      linked = true;
    }
    return joinOutcome;
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
}

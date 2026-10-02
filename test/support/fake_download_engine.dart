import 'dart:async';

import 'package:diegema/services/download_manager.dart';

/// In-memory [DownloadEngine]: records what the manager asked for and lets
/// a test play the plugin's part by [emit]-ting updates. Holds one task
/// "running" at a time, like the real holding queue configured to 1.
class FakeDownloadEngine implements DownloadEngine {
  final _updates = StreamController<EngineUpdate>.broadcast(sync: true);

  /// Jobs in the order they were enqueued, with the Wi-Fi flag each got.
  final List<DownloadJob> enqueued = [];
  final List<bool> wifiFlags = [];
  final List<String> cancelled = [];
  final List<String> forgotten = [];
  final List<bool> wifiSettings = [];

  /// What [records] returns: the persisted task database.
  final Map<String, EngineUpdate> persisted = {};

  bool started = false;
  int permissionAsks = 0;
  bool resumeWorks = true;

  /// Where [zipPath] says ZIPs land.
  String zipRoot = '/zips';

  @override
  Stream<EngineUpdate> get updates => _updates.stream;

  void emit(DownloadJob job,
      {EngineStatus? status, double? progress, String? error}) {
    final update =
        EngineUpdate(job, status: status, progress: progress, error: error);
    if (status != null) persisted[job.id] = update;
    _updates.add(update);
  }

  @override
  Future<void> start() async => started = true;

  @override
  Future<List<EngineUpdate>> records() async => persisted.values.toList();

  @override
  Future<bool> enqueue(DownloadJob job, {required bool wifiOnly}) async {
    enqueued.add(job);
    wifiFlags.add(wifiOnly);
    persisted[job.id] = EngineUpdate(job, status: EngineStatus.enqueued);
    return true;
  }

  @override
  Future<void> cancel(String id) async => cancelled.add(id);

  @override
  Future<bool> pause(String id) async => true;

  @override
  Future<bool> resume(String id) async => resumeWorks;

  @override
  Future<void> setWifiOnly(bool wifiOnly) async => wifiSettings.add(wifiOnly);

  @override
  Future<String> zipPath(String id) async => '$zipRoot/$id.zip';

  @override
  Future<void> forget(String id) async {
    forgotten.add(id);
    persisted.remove(id);
  }

  @override
  Future<void> askNotificationPermission() async => permissionAsks++;
}

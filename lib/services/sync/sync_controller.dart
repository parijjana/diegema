import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../database/app_database.dart';
import '../../sync/sync_view.dart';
import 'sync_controller_web.dart'
    if (dart.library.io) 'sync_controller_io.dart' as platform;

/// What the UI uses of linked-device sync. Implemented by `SyncService` on
/// native platforms; absent (null) on the web and in widget tests that
/// don't supply one, and the sync UI then doesn't appear.
abstract class SyncController {
  /// Rebuilt after every refresh and every sync that changed something.
  ValueListenable<SyncView?> get view;

  /// Publishes what changed in the library and rebuilds [view].
  Future<void> refresh();

  /// Book id → portable key, for this device's books.
  Future<Map<String, String>> portableKeys();

  Future<String> deviceName();
  Future<void> setDeviceName(String name);
}

SyncController? createSyncController(AppDatabase db) =>
    platform.createSyncController(db);

/// Puts the [SyncController]'s view in scope; dependents rebuild when it
/// changes.
class SyncScope extends InheritedNotifier<ValueListenable<SyncView?>> {
  final SyncController controller;

  SyncScope({super.key, required this.controller, required super.child})
      : super(notifier: controller.view);

  static SyncController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.controller;

  static SyncView? viewOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier?.value;
}

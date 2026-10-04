import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../database/app_database.dart';
import '../../sync/sync_file.dart';
import '../../sync/sync_view.dart';
import 'sync_controller_web.dart' if (dart.library.io) 'sync_controller_io.dart'
    as platform;

export '../../sync/sync_file.dart' show SyncFileError, SyncFileProblem;

/// What the UI uses of linked-device sync. Implemented by `SyncService` on
/// native platforms; absent (null) on the web and in widget tests that
/// don't supply one, and the sync UI then doesn't appear.
abstract class SyncController {
  /// Rebuilt after every refresh and every sync that changed something.
  ValueListenable<SyncView?> get view;

  /// Publishes what changed in the library and rebuilds [view].
  Future<void> refresh();

  /// App opened or resumed: publish, start listening, sync with devices on
  /// this network.
  Future<void> foreground();

  /// App paused: publish and sync once more.
  Future<void> background();

  /// Whether this device is in a sync group.
  Future<bool> isLinked();

  /// Syncs with this group's devices on the network now; how many it
  /// reached. Also what a Mac showing a link code calls while it waits: it
  /// never listens, so it dials whoever has just scanned.
  Future<int> syncNow();

  /// A code for "Link a device", creating the group if there is none.
  /// Starts listening (not on a Mac).
  Future<LinkOffer> createLinkOffer();

  /// Joins the group in a scanned or pasted code and syncs with the device
  /// that showed it.
  Future<JoinOutcome> joinWithCode(String code, {bool replaceGroup = false});

  /// Whether this device can scan a code with its camera (phones).
  bool get canScan;

  /// Where sync stands on this device, for Settings → Linked devices.
  Future<SyncStatus> status();

  /// The last sync this session (any trigger), or null before the first.
  ValueListenable<LastSync?> get lastSync;

  /// Removes a device from every linked device's lists. It comes back if it
  /// is still linked and syncs again (see SYNC_DESIGN, S8).
  Future<void> forgetDevice(String deviceId);

  /// Leaves the group: this device stops syncing and keeps its library.
  Future<void> unlink();

  /// For [SyncStatus.keysUnreadable]: deletes the unreadable keys so this
  /// device can be linked again (as a new device).
  Future<void> resetKeys();

  /// Book id → portable key, for this device's books.
  Future<Map<String, String>> portableKeys();

  /// Gives the book [bookId] the portable [key] (links it to the same book
  /// on another device), then refreshes.
  Future<void> linkBook(String bookId, String key);

  Future<String> deviceName();
  Future<void> setDeviceName(String name);

  /// A sync file holding every record this device has, to carry by hand to
  /// a device it can't reach over the network (SYNC_DESIGN S12). Publishes
  /// first. Throws [StateError] when not linked.
  Future<SyncFileExport> exportSyncFile();

  /// Merges a sync file written by a device of this group; how many
  /// records it changed (0 for an old or repeated file). Throws
  /// [SyncFileError] for a file it refuses, [StateError] when not linked.
  Future<int> importSyncFile(List<int> bytes);
}

class SyncFileExport {
  final List<int> bytes;

  /// Suggested name, e.g. `diegema-animeshs-mac-2026-10-04.diegemasync`.
  final String fileName;
  const SyncFileExport(this.bytes, this.fileName);
}

enum SyncStatus {
  /// Not linked to any device.
  unlinked,
  linked,

  /// The keystore holding this device's sync keys can't be read.
  keysUnreadable,
}

class LastSync {
  final DateTime at;

  /// Linked devices reached.
  final int reached;
  const LastSync(this.at, this.reached);
}

class LinkOffer {
  /// The text the QR encodes; also shown for copying and pasting.
  final String code;
  final DateTime expiresAt;
  const LinkOffer(this.code, this.expiresAt);
}

enum JoinOutcome {
  /// Joined, and the first sync with the showing device worked.
  linked,

  /// Joined, but the showing device wasn't reached yet (it's a Mac that
  /// will dial this one, or not on this Wi-Fi); syncs when they meet.
  linkedNotSynced,

  /// Not a Diegema link code.
  invalid,

  /// The code's five minutes are up; show a new one.
  expired,

  /// This device is already in another group; ask, then call again with
  /// replaceGroup.
  otherGroup,
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

import 'package:flutter/foundation.dart';

/// Device sync (LAN sync, linked devices, link codes, the sync file) is OFF in
/// v1 (owner decision, 2026-10-25). The code stays for v1.1; build with
/// `--dart-define=DIEGEMA_SYNC=true` to switch it all back on.
///
/// With this false no sync controller is built, nothing listens or advertises
/// on the network, and no sync UI is shown.
const bool kSyncEnabled = bool.fromEnvironment('DIEGEMA_SYNC');

bool? _testOverride;

/// Whether sync is on. [kSyncEnabled], unless a test overrode it.
bool get syncEnabled => _testOverride ?? kSyncEnabled;

/// Tests only: force sync on or off; null restores [kSyncEnabled].
@visibleForTesting
set syncEnabledForTesting(bool? value) => _testOverride = value;

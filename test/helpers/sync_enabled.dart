import 'package:diegema/core/sync_flag.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sync is off by default in v1 (`DIEGEMA_SYNC`). Call this at the top of
/// `main()` in a test file that exercises the sync UI: it switches sync on
/// for each test and restores the default afterwards.
void enableSyncForTests() {
  setUp(() => syncEnabledForTesting = true);
  tearDown(() => syncEnabledForTesting = null);
}

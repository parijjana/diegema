import '../../database/app_database.dart';
import 'sync_controller.dart';

/// v1 ships without device sync, and without the plugins it needs (mDNS
/// discovery, keystore, QR). This is the seam: v1.1 puts the real factory
/// back from `parked/sync-v1.1/` (see its README).
SyncController? createSyncController(AppDatabase db) => null;

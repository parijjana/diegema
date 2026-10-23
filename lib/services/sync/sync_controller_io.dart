import '../../database/app_database.dart';
import 'lan_platform_io.dart';
import 'sync_controller.dart';
import 'sync_service_io.dart';

SyncController? createSyncController(AppDatabase db) => SyncService(
      db,
      secrets: platformSecretStore(),
      discovery: BonsoirPeerDiscovery(),
      listens: platformListens,
    );

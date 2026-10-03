import '../../database/app_database.dart';
import 'sync_controller.dart';
import 'sync_service_io.dart';

SyncController? createSyncController(AppDatabase db) => SyncService(db);

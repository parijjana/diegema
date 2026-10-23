import '../../database/app_database.dart';
import 'sync_controller.dart';

/// No linked-device sync on the web demo.
SyncController? createSyncController(AppDatabase db) => null;

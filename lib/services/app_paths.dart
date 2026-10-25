import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_data_directory.dart';
import '../database/app_database.dart';

const String _documentsRootKey = 'app_paths.documents_root.v1';

/// Notices that the app's documents folder has moved since the last launch
/// and rewrites the database's paths to match. On iOS the folder's absolute
/// path changes with every app update or reinstall; without this,
/// downloaded and imported books would stop playing after an update.
///
/// Call once at startup, before anything reads a chapter path. The first
/// launch only records where the folder is.
Future<void> rebaseAppPathsIfMoved(
  AppDatabase db, {
  Future<String> Function()? documentsRoot,
  Future<SharedPreferences> Function()? prefs,
}) async {
  try {
    final root =
        await (documentsRoot ?? () async => (await appDataDirectory()).path)();
    final store = await (prefs ?? SharedPreferences.getInstance)();
    final previous = store.getString(_documentsRootKey);
    if (previous != null && previous != root) {
      final touched = await db.rebaseAppPaths(previous, root);
      debugPrint('App folder moved; rebased $touched books.');
    }
    if (previous != root) await store.setString(_documentsRootKey, root);
  } catch (e) {
    // Never block startup; the next launch tries again (the old root is
    // only replaced after a successful rebase).
    debugPrint('rebaseAppPathsIfMoved failed: $e');
  }
}

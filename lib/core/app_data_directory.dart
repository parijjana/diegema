import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The folder the app keeps its own data in: the database, covers, imported
/// books and the private downloads root. Every service resolves it through
/// here, never through `getApplicationDocumentsDirectory()` directly.
///
/// Android, iOS and macOS: the app's documents folder, as since 1.0. Moving
/// it there would orphan existing libraries.
///
/// Windows: the support folder, `%APPDATA%\Overengineered Hobbies\Diegema`
/// (named by `windows/runner/Runner.rc`). Windows' documents folder is the
/// user's own Documents, often synced to OneDrive, which would then upload
/// the database and every book. Under MSIX, AppData writes are redirected
/// into the package and removed on uninstall.
///
/// [platform] overrides the platform (tests).
Future<Directory> appDataDirectory({TargetPlatform? platform}) {
  final windows = platform != null
      ? platform == TargetPlatform.windows
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  return windows
      ? getApplicationSupportDirectory()
      : getApplicationDocumentsDirectory();
}

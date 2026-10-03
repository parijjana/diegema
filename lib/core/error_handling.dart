import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Catches the errors nothing else does, so they are logged instead of
/// lost, and a widget that fails to build shows a quiet note in release
/// builds rather than a grey box.
///
/// Uses [PlatformDispatcher.onError] rather than `runZonedGuarded`: it sees
/// the same uncaught async errors without the zone-mismatch trap of calling
/// `ensureInitialized` and `runApp` in different zones.
void installErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    (previous ?? FlutterError.presentError)(details);
    debugPrint('Unhandled Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const _BuildErrorNote();
  }
}

class _BuildErrorNote extends StatelessWidget {
  const _BuildErrorNote();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Something here couldn't be shown.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

/// Shown instead of the app when the library on disk is from a newer
/// Diegema (see `AppDatabase.isLibraryFromNewerVersion`). Nothing is opened
/// or changed, so updating the app picks up exactly where it was.
class NewerLibraryApp extends StatelessWidget {
  const NewerLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Your library was saved by a newer version of Diegema. '
                'Update Diegema to open it. Nothing has been changed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

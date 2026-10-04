import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../../sync/sync_file.dart';

/// A sync file the user chose to import.
class PickedSyncFile {
  final String name;
  final int size;

  /// Null when the platform didn't hand the contents over.
  final List<int>? bytes;
  const PickedSyncFile(this.name, this.size, this.bytes);
}

/// The two platform dialogs the sync-file area needs. The screen takes one
/// as a constructor argument so tests never open a real dialog.
abstract class SyncFilePicker {
  const SyncFilePicker();

  /// Asks where to save [bytes]; true when saved, false when cancelled.
  Future<bool> save(String fileName, List<int> bytes);

  /// Asks for a file; null when cancelled.
  Future<PickedSyncFile?> pick();
}

class PlatformSyncFilePicker extends SyncFilePicker {
  const PlatformSyncFilePicker();

  @override
  Future<bool> save(String fileName, List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save sync file',
      fileName: fileName,
      bytes: data,
    );
    if (kIsWeb) return true; // The browser handles the download.
    if (path == null) return false;
    // The plugin has written [bytes] itself on every platform (desktop to the
    // returned path, Android through the chosen content URI).
    return true;
  }

  @override
  Future<PickedSyncFile?> pick() async {
    // Android's picker can't filter on an unknown extension, so it takes any
    // file; a wrong one is refused as "not a sync file" on import.
    final custom = defaultTargetPlatform != TargetPlatform.android;
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose a sync file',
      type: custom ? FileType.custom : FileType.any,
      allowedExtensions: custom ? [SyncFile.extension] : null,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    return PickedSyncFile(f.name, f.size, f.bytes);
  }
}

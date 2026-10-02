import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'folder_access.dart';

/// Resolves a directory, or `null` when there is none on this platform.
typedef DirectoryResolver = Future<String?> Function();

Future<String?> _platformDocumentsRoot() async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    // No plugin or no binding (plain unit tests): there is no folder.
    return null;
  }
}

const MethodChannel _channel = MethodChannel('diegema/downloads_location');

const String _macFolderKey = 'downloads_location.folder.v1';
const String _macBookmarkKey = 'downloads_location.bookmark.v1';

/// The macOS downloads folder, once chosen and opened this run.
String? _macRoot;

bool get _underTest => Platform.environment.containsKey('FLUTTER_TEST');

/// `Audiobooks/Diegema` in shared storage on Android 11+ and in the user's
/// folder on Windows; on macOS, `<chosen>/Diegema` once the user has picked
/// where (the sandbox can't write to ~/Audiobooks unasked). `null`
/// (downloads stay app-private) on iOS (owner decision), Android 10 and
/// older (no file-API writes to shared storage), macOS before a folder is
/// chosen, and under `flutter test`, which must never touch real folders.
Future<String?> _platformVisibleRoot() async {
  if (_underTest) return null;
  try {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<String>('audiobooksDirectory');
    }
    if (Platform.isMacOS) return _macRoot;
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile == null) return null;
      return p.join(profile, 'Audiobooks', 'Diegema');
    }
  } on MissingPluginException {
    return null;
  } catch (e) {
    debugPrint('DownloadsLocation: no visible folder: $e');
  }
  return null;
}

/// macOS: re-opens the chosen downloads folder from its bookmark. Call at
/// startup, before anything scans or plays downloads.
Future<void> openDownloadsFolder() async {
  if (_underTest || !Platform.isMacOS) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final bookmark = prefs.getString(_macBookmarkKey);
    if (bookmark == null) return;
    final opened = await FolderAccess().open(bookmark);
    if (opened == null) {
      debugPrint('Downloads folder could not be opened; asking again.');
      await prefs.remove(_macBookmarkKey);
      await prefs.remove(_macFolderKey);
      return;
    }
    _macRoot = opened.path;
  } catch (e) {
    debugPrint('openDownloadsFolder failed: $e');
  }
}

/// Where Discover downloads live (DOWNLOADS_LOCATION.md).
///
/// New downloads go to [current]: a folder people can see in their file
/// manager where the platform allows it, else the app-private
/// `<documents>/diegema/downloads`. Scans and removal cover [all] roots, so
/// a download is found and removable whichever one it is in.
class DownloadsLocation {
  /// Overrides the app documents directory (tests).
  final DirectoryResolver? documentsRoot;

  /// Overrides the user-visible folder; a resolver returning `null` means
  /// "this platform keeps downloads private" (tests).
  final DirectoryResolver? visibleRoot;

  const DownloadsLocation({this.documentsRoot, this.visibleRoot});

  Future<String?> privateRoot() async {
    final docs = await (documentsRoot ?? _platformDocumentsRoot)();
    return docs == null ? null : p.join(docs, 'diegema', 'downloads');
  }

  Future<String?> userVisibleRoot() =>
      (visibleRoot ?? _platformVisibleRoot)();

  /// macOS before a folder is chosen: [chooseFolder] must ask first.
  bool get needsFolderChoice =>
      visibleRoot == null && !_underTest && Platform.isMacOS && _macRoot == null;

  /// Asks where downloads go (macOS) and remembers it. Returns the new
  /// root, or null when the user cancelled (that download stays private,
  /// and the next one asks again).
  Future<String?> chooseFolder() async {
    final picked = await FolderAccess(enabled: true).pickDownloadsFolder();
    if (picked == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macFolderKey, picked.path);
    await prefs.setString(_macBookmarkKey, picked.bookmark);
    _macRoot = picked.path;
    return picked.path;
  }

  /// The folder a new download is saved into.
  Future<String?> current() async =>
      await userVisibleRoot() ?? await privateRoot();

  /// Every downloads root that may hold books, without duplicates.
  Future<List<String>> all() async {
    final roots = <String>[];
    for (final root in [await userVisibleRoot(), await privateRoot()]) {
      if (root == null) continue;
      final normal = p.normalize(root);
      if (!roots.contains(normal)) roots.add(normal);
    }
    return roots;
  }

  /// Android only: asks the user to let Diegema delete [files] it no longer
  /// owns (written by an earlier install). Shared storage refuses a plain
  /// delete of those. Returns true when the user agreed.
  Future<bool> requestMediaDelete(List<String> files) async {
    if (files.isEmpty || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('deleteMedia', files) ?? false;
    } catch (e) {
      debugPrint('DownloadsLocation: media delete failed: $e');
      return false;
    }
  }
}

/// One-time move of downloads made before the visible folder existed
/// (owner: existing downloads move on update). Per book folder: copy the
/// audio across, point the database at the copies, then delete the
/// original — so an interruption at any point leaves a playable book, and
/// the next launch finishes the job. A folder that fails stays where it is.
///
/// Call at startup, before playback restores the last book.
Future<int> moveDownloadsToVisibleFolder(AppDatabase db,
    {DownloadsLocation location = const DownloadsLocation()}) async {
  var moved = 0;
  try {
    final to = await location.userVisibleRoot();
    final from = await location.privateRoot();
    if (to == null || from == null || p.equals(to, from)) return 0;
    final source = Directory(from);
    if (!await source.exists()) return 0;

    for (final dir in (await source.list().toList()).whereType<Directory>()) {
      final dest = p.join(to, p.basename(dir.path));
      try {
        final audio = (await dir.list(recursive: true).toList())
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.mp3'));
        for (final file in audio) {
          final target = p.join(dest, p.relative(file.path, from: dir.path));
          await Directory(p.dirname(target)).create(recursive: true);
          final copy = await file.copy(target);
          if (await copy.length() != await file.length()) {
            throw FileSystemException('Incomplete copy', target);
          }
        }
        await db.rebaseAppPaths(dir.path, dest);
        await dir.delete(recursive: true);
        moved++;
      } catch (e) {
        debugPrint('Downloads move: kept ${dir.path} in place: $e');
      }
    }
    if (await source.list().isEmpty) await source.delete();
  } catch (e) {
    // Never block startup; the next launch tries again.
    debugPrint('moveDownloadsToVisibleFolder failed: $e');
  }
  if (moved > 0) debugPrint('Moved $moved downloads to the visible folder.');
  return moved;
}

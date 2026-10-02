import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// Resolves a directory, or `null` when there is none on this platform.
typedef DirectoryResolver = Future<String?> Function();

Future<String?> _platformDocumentsRoot() async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } on MissingPluginException {
    return null;
  }
}

const MethodChannel _channel = MethodChannel('diegema/downloads_location');

/// `<Music>/Diegema` on macOS and Windows, `Audiobooks/Diegema` in shared
/// storage on Android 11+. `null` (downloads stay app-private) on iOS (owner
/// decision), Android 10 and older (no file-API writes to shared storage),
/// and under `flutter test`, which must never touch the real Music folder.
Future<String?> _platformVisibleRoot() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  try {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<String>('audiobooksDirectory');
    }
    if (Platform.isMacOS) {
      // Sandboxed, HOME is the app container; its Music entry is the
      // system's link to the real ~/Music (needs the assets.music
      // entitlement). Resolve it so stored paths don't depend on the link.
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final music = Directory(p.join(home, 'Music'));
      if (!await music.exists()) return null;
      return p.join(await music.resolveSymbolicLinks(), 'Diegema');
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile == null) return null;
      return p.join(profile, 'Music', 'Diegema');
    }
  } on MissingPluginException {
    return null;
  } catch (e) {
    debugPrint('DownloadsLocation: no visible folder: $e');
  }
  return null;
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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'library_locations_store.dart';

/// Keeps a picked folder readable across launches on Apple platforms.
///
/// The macOS and iOS sandboxes grant access to a folder the user picks for
/// that run only. A **security-scoped bookmark**, made while that access is
/// still live, is what lets a later launch open the folder again without
/// asking. Android and Windows need none of this (Android uses the
/// READ_MEDIA_AUDIO permission), so there every call is a no-op.
///
/// The native half is `FolderAccessChannel` in the macOS/iOS runners.
class FolderAccess {
  static const MethodChannel _channel = MethodChannel('diegema/folder_access');

  /// Whether this platform needs bookmarks. Overridable for tests.
  final bool enabled;

  final MethodChannel channel;

  FolderAccess({bool? enabled, MethodChannel? channel})
      : enabled = enabled ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.iOS)),
        channel = channel ?? _channel;

  /// Whether the folder picker must be [pickFolder] rather than
  /// file_picker's: on iOS file_picker returns a path without opening the
  /// folder's security scope, so the folder can't be read or bookmarked.
  bool get picksNatively =>
      enabled &&
      channel == _channel &&
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Shows the system folder picker and returns the chosen folder, already
  /// open for this run, with a bookmark when one could be made. Null when
  /// cancelled. iOS only (see [picksNatively]).
  Future<({String path, String? bookmark})?> pickFolder() async {
    try {
      final result =
          await channel.invokeMapMethod<String, Object?>('pickFolder');
      final path = result?['path'];
      if (path is! String) return null;
      return (path: path, bookmark: result!['bookmark'] as String?);
    } on PlatformException catch (e) {
      debugPrint('FolderAccess.pickFolder failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// A bookmark for [path], base64-encoded, or null when the platform needs
  /// none or the folder can't be bookmarked. Call it right after the picker
  /// returns, while the picker's own access is still live.
  Future<String?> bookmark(String path) async {
    if (!enabled) return null;
    try {
      return await channel.invokeMethod<String>('bookmark', {'path': path});
    } on PlatformException catch (e) {
      debugPrint('FolderAccess.bookmark($path) failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Resolves [bookmark] and starts access to the folder for the rest of
  /// this run. Returns null when the folder is gone or can't be opened.
  Future<OpenedFolder?> open(String bookmark) async {
    if (!enabled) return null;
    try {
      final result = await channel
          .invokeMapMethod<String, Object?>('open', {'bookmark': bookmark});
      final path = result?['path'];
      if (path is! String) return null;
      return OpenedFolder(
        path: path,
        stale: result!['stale'] == true,
      );
    } on PlatformException catch (e) {
      debugPrint('FolderAccess.open failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Ends access started by [open] (when the folder is removed).
  Future<void> close(String path) async {
    if (!enabled) return;
    try {
      await channel.invokeMethod<void>('close', {'path': path});
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}

class OpenedFolder {
  /// Where the folder is now. Differs from the stored path if it was moved.
  final String path;

  /// The bookmark still worked but should be made again and re-saved.
  final bool stale;

  const OpenedFolder({required this.path, required this.stale});
}

/// Re-opens every library location that has a bookmark, so its books can be
/// scanned and played this run. Call once at startup, before anything reads
/// a location. A stale bookmark is made again and re-saved; a folder that
/// can't be opened (deleted, moved, or on an unplugged drive) is skipped,
/// and its books stay in the library until it comes back or is removed.
Future<void> openLibraryLocations({
  LibraryLocationsStore store = const LibraryLocationsStore(),
  FolderAccess? access,
}) async {
  final folders = access ?? FolderAccess();
  if (!folders.enabled) return;
  for (final MapEntry(key: path, value: bookmark)
      in (await store.readBookmarks()).entries) {
    final opened = await folders.open(bookmark);
    if (opened == null) continue;
    if (p.normalize(opened.path) != p.normalize(path)) {
      // Moved. Books and chapters are keyed by the old path, so following
      // the move would re-import everything; leave it for the user to
      // remove and re-add.
      debugPrint('Library folder moved: $path -> ${opened.path}');
      continue;
    }
    if (opened.stale) {
      final fresh = await folders.bookmark(path);
      if (fresh != null) await store.setBookmark(path, fresh);
    }
  }
}

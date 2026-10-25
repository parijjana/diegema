import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_data_directory.dart';

/// Result of [copyIntoLibrary]: the original-path -> durable-path mapping
/// for every audio file copied, plus the durable cover path if a cover was
/// copied too.
class LibraryCopyResult {
  /// Maps each original audio path (as passed in [copyIntoLibrary]'s
  /// `audioPaths`) to its new, durable path under
  /// `<application documents>/diegema/library/<bookId>/`.
  final Map<String, String> audioPaths;

  /// The durable path a folder-cover image was copied to, or `null` when
  /// no `coverPath` was passed in.
  final String? coverPath;

  const LibraryCopyResult({required this.audioPaths, this.coverPath});
}

/// Copies [audioPaths] (and, optionally, [coverPath] — a loose folder-cover
/// image file) into
/// `<application documents>/diegema/library/<bookId>/`, so the book keeps
/// working after Android reclaims `file_picker`'s cache directory (see
/// `local_audiobook_import_io.dart`'s doc comment for the full problem).
///
/// Every copy is streamed (`File.openRead` -> `IOSink.addStream`) so large
/// audio files never sit fully in memory. A filename collision within the
/// same book gets a numeric suffix (`name_2.ext`, `name_3.ext`, ...) rather
/// than overwriting.
///
/// After a file is copied, its *source* is deleted if — and only if — that
/// source lives under [getTemporaryDirectory] (where `file_picker` stages
/// picked files on Android). A source anywhere else (an SD card, an
/// external folder the user picked directly) is left untouched.
///
/// On any failure partway through, the partial
/// `diegema/library/<bookId>` directory is removed before the error is
/// rethrown — callers never end up with a half-copied book directory.
Future<LibraryCopyResult> copyIntoLibrary({
  required String bookId,
  required List<String> audioPaths,
  String? coverPath,
}) async {
  final appDocs = await appDataDirectory();
  final libraryDir =
      Directory(p.join(appDocs.path, 'diegema', 'library', bookId));
  await libraryDir.create(recursive: true);

  String? cacheRoot;
  try {
    cacheRoot = await getTemporaryDirectory().then((d) => d.path);
  } catch (_) {
    // No temp dir available (unlikely outside tests that don't stub it) —
    // just means "never treat anything as a cache original".
    cacheRoot = null;
  }

  final usedNames = <String>{};

  try {
    final audioResult = <String, String>{};
    for (final srcPath in audioPaths) {
      final destPath =
          await copyFileIntoDirectory(srcPath, libraryDir, usedNames);
      audioResult[srcPath] = destPath;
      await _deleteIfCached(srcPath, cacheRoot);
    }

    String? newCoverPath;
    if (coverPath != null) {
      newCoverPath =
          await copyFileIntoDirectory(coverPath, libraryDir, usedNames);
      await _deleteIfCached(coverPath, cacheRoot);
    }

    return LibraryCopyResult(audioPaths: audioResult, coverPath: newCoverPath);
  } catch (_) {
    if (await libraryDir.exists()) {
      await libraryDir.delete(recursive: true);
    }
    rethrow;
  }
}

/// Streams [srcPath] into [destDir], picking a collision-free filename:
/// [srcPath]'s own basename if [usedNames] doesn't already contain it
/// (case-insensitively), otherwise `name_2.ext`, `name_3.ext`, etc. Adds
/// the chosen name to [usedNames] before returning. Shared by
/// [copyIntoLibrary] (whole-book copy, cleans up on failure) and
/// `local_import_migration_service_io.dart` (one file at a time, a single
/// failure is logged and skipped rather than aborting the whole book).
Future<String> copyFileIntoDirectory(
    String srcPath, Directory destDir, Set<String> usedNames) async {
  final ext = p.extension(srcPath);
  final base = p.basenameWithoutExtension(srcPath);
  var name = p.basename(srcPath);
  var suffix = 2;
  while (usedNames.contains(name.toLowerCase())) {
    name = '${base}_$suffix$ext';
    suffix++;
  }
  usedNames.add(name.toLowerCase());

  final destPath = p.join(destDir.path, name);
  final sink = File(destPath).openWrite();
  try {
    await sink.addStream(File(srcPath).openRead());
  } finally {
    await sink.close();
  }
  return destPath;
}

/// Deletes [path] if it lives under [cacheRoot] — best-effort; a failed
/// delete never fails the import, since the durable copy already exists.
Future<void> _deleteIfCached(String path, String? cacheRoot) async {
  if (cacheRoot == null) return;
  if (!isUnderDirectory(path, cacheRoot)) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best-effort cleanup only.
  }
}

/// Whether [path] is [root] itself or lives somewhere underneath it, after
/// normalising both. Shared by the copy-on-import cache cleanup above and
/// the once-per-launch migration in `local_import_migration_service_io.dart`
/// (which needs the inverse question: "is this path already durable?").
bool isUnderDirectory(String path, String root) {
  final normalisedRoot = p.normalize(root);
  final normalisedPath = p.normalize(path);
  if (p.equals(normalisedPath, normalisedRoot)) return true;
  return p.isWithin(normalisedRoot, normalisedPath);
}

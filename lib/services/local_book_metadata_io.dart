import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils/id3_metadata.dart';
import '../core/utils/local_media_metadata.dart';
import '../core/utils/mp4_metadata.dart';

/// Reads embedded metadata (title/author/description/cover) from the first
/// of [paths] that carries any, trying each file's format-appropriate
/// reader (`mp4_metadata.dart` for `.m4b`/`.m4a`/`.mp4`, `id3_metadata.dart`
/// for `.mp3`) in file order. Used by `local_audiobook_import_io.dart` so a
/// multi-file import (e.g. one file per chapter) still picks up the tags
/// off whichever file actually carries them.
///
/// Returns `null` if none of [paths] had usable embedded metadata.
Future<LocalMediaMetadata?> readEmbeddedMetadataForFiles(
    List<String> paths) async {
  for (final path in paths) {
    final ext = p.extension(path).toLowerCase();
    LocalMediaMetadata? metadata;
    if (ext == '.m4b' || ext == '.m4a' || ext == '.mp4') {
      metadata = await readMp4Metadata(path);
    } else if (ext == '.mp3') {
      metadata = await readId3Metadata(path);
    }
    if (metadata != null && !metadata.isEmpty) return metadata;
  }
  return null;
}

const _coverBasenames = {'cover', 'folder', 'front', 'albumart'};
const _coverExtensions = {'.jpg', '.jpeg', '.png'};

/// Step 2 of the local-import cover pipeline: when the embedded-metadata
/// lookup (step 1) found no art, look for a plain image file sitting next
/// to the audio. Preferring, in order:
/// - a file named `cover`/`folder`/`front`/`albumart` (case-insensitive,
///   `.jpg`/`.jpeg`/`.png`), the first match in directory-listing order;
/// - if none match by name but the folder holds exactly one image file,
///   that file.
///
/// Never throws; returns `null` on any failure or when nothing qualifies.
Future<String?> findFolderCoverImage(String folderPath) async {
  try {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    final images = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (_coverExtensions.contains(ext)) images.add(entity);
    }
    if (images.isEmpty) return null;

    for (final file in images) {
      final base = p.basenameWithoutExtension(file.path).toLowerCase();
      if (_coverBasenames.contains(base)) return file.path;
    }

    if (images.length == 1) return images.single.path;
    return null;
  } catch (_) {
    return null;
  }
}

/// Runs [findFolderCoverImage] across every distinct parent folder in
/// [paths] (a file import can span several folders; a folder import has
/// just the one), returning the first hit.
Future<String?> findFolderCoverImageForFiles(List<String> paths) async {
  final folders = <String>{};
  for (final path in paths) {
    folders.add(p.dirname(path));
  }
  for (final folder in folders) {
    final found = await findFolderCoverImage(folder);
    if (found != null) return found;
  }
  return null;
}

/// Saves [bytes] as [bookId]'s cover under
/// `<application documents>/diegema/covers/<bookId>.<jpg|png>`, returning
/// the saved absolute path, or `null` on any write failure (never throws).
Future<String?> saveCoverBytes(
    Uint8List bytes, String? mime, String bookId) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final ext = mime == 'image/png' ? 'png' : 'jpg';
    final dir = Directory(p.join(appDir.path, 'diegema', 'covers'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$bookId.$ext'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

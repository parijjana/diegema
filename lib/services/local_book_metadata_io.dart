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
